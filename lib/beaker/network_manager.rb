[ 'hypervisor' ].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  #Object that holds all the provisioned and non-provisioned virtual machines.
  #Controls provisioning, configuration, validation and cleanup of those virtual machines.
  class NetworkManager

    #Determine if a given host should be provisioned.
    #Provision if:
    # - only if we are running with ---provision
    # - only if we have a hypervisor
    # - only if either the specific hosts has no specification or has 'provision' in its config
    # - always if it is a vagrant box (vagrant boxes are always provisioned as they always need ssh key hacking)
    def provision? options, host
      command_line_says = options[:provision]
      host_says = host['hypervisor'] && (host.has_key?('provision') ? host['provision'] : true)
      (command_line_says && host_says) or (host['hypervisor'] =~/vagrant/)
    end

    def initialize(options, logger)
      @logger = logger
      @options = options
      @hosts = []
      @machines = {}
      @hypervisors = nil

      @options[:timestamp]            = Time.now unless @options.has_key?(:timestamp)
      @options[:xml_dated_dir]        = Beaker::Logger.generate_dated_log_folder(@options[:xml_dir], @options[:timestamp])
      @options[:log_dated_dir]        = Beaker::Logger.generate_dated_log_folder(@options[:log_dir], @options[:timestamp])
      @options[:logger_sut]  = Beaker::Logger.new(File.join(@options[:log_dated_dir], @options[:log_sut_event]), { :quiet => true })
    end

    #Provision all virtual machines.  Provision machines according to their set hypervisor, if no hypervisor
    #is selected assume that the described hosts are already up and reachable and do no provisioning.
    def provision
      if @hypervisors
        cleanup
      end
      @hypervisors = {}
      #sort hosts by their hypervisor, use hypervisor 'none' if no hypervisor is specified
      @options['HOSTS'].each_key do |name|
        host = @options['HOSTS'][name]
        hypervisor = host['hypervisor']
        hypervisor = provision?(@options, host) ? host['hypervisor'] : 'none'
        @logger.debug "Hypervisor for #{name} is #{hypervisor}"
        @machines[hypervisor] = [] unless @machines[hypervisor]
        @machines[hypervisor] << Beaker::Host.create(name, @options)
      end

      @machines.each_key do |type|
        @hypervisors[type] = Beaker::Hypervisor.create(type, @machines[type], @options)
        @hosts << @machines[type]
        @machines[type].each do |host|
          log_sut_event host, true
        end
      end
      @hosts = @hosts.flatten
      @hosts
    end

    #Validate all provisioned machines, ensure that required packages are installed - if they are missing
    #attempt to add them.
    #@raise [Exception] Raise an exception if virtual machines fail to be validated
    def validate
      if @hypervisors
        @hypervisors.each_key do |type|
          @hypervisors[type].validate
        end
      end
    end

    #Configure all provisioned machines, adding any packages or settings required for SUTs
    #@raise [Exception] Raise an exception if virtual machines fail to be configured
    def configure
      if @hypervisors
        @hypervisors.each_key do |type|
          @hypervisors[type].configure
        end
      end
    end

    # configure proxy on all provioned machines
    #@raise [Exception] Raise an exception if virtual machines fail to be configured
    def proxy_package_manager
      if @hypervisors
        @hypervisors.each_key do |type|
          @hypervisors[type].proxy_package_manager
        end
      end
    end

    #Shut down network connections and revert all provisioned virtual machines
    def cleanup
      #shut down connections
      @hosts.each {|host| host.close }

      if @hypervisors
        @hypervisors.each_key do |type|
          @hypervisors[type].cleanup
          @hypervisors[type].instance_variable_get(:@hosts).each do |host|
            log_sut_event host, false
          end
        end
      end
      @hypervisors = nil
    end

    # logs provisioning events
    #
    # @param [Host] host The host that the event is happening to
    # @param [Boolean] create Whether the event is creation or cleaning up
    #
    # @return [String] the log line created for this event
    def log_sut_event host, create
      raise ArgumentError.new "log_sut_event called before sut logger created. skipping #{host}, #{create}" unless @options.has_key?(:logger_sut)
      sut_logger = @options[:logger_sut]
      time = Time.new
      stamp = time.strftime('%Y-%m-%d %H:%M:%S')
      verb = create ? '+' : '-'
      line = "#{stamp}\t[#{verb}]\t#{host['hypervisor']}\t#{host['platform']}\t#{host}"
      sut_logger.notify line
      line
    end

  end
end
