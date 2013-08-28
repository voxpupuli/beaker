module Beaker
  class Aixer < Beaker::Hypervisor

    def initialize(aix_hosts, options)
      @options = options
      @logger = options[:logger]
      @aix_hosts = aix_hosts
      #aix machines are reverted to known state, not a snapshot
      fog_file = nil
      if File.exists?( File.join(ENV['HOME'], '.fog') )
        fog_file = YAML.load_file( File.join(ENV['HOME'], '.fog') )
      end
      raise "Cant load ~/.fog config" unless fog_file

      # Running the rake task on rpm-builder
      hypername = fog_file[:default][:aix_hypervisor_server]
      hyperopts = @options.dup
      hyperopts['HOSTS'] = {
          hypername => { 'platform' => 'el-6-x86_64' }
      }

      @logger.notify "Connecting to hypervisor at #{hypername}"
      hypervisor = Beaker::Host.create( hypername, hyperopts )
      hypervisor[:user] = fog_file[:default][:aix_hypervisor_username] || ENV['USER']
      hypervisor[:ssh][:keys] = [fog_file[:default][:aix_hypervisor_keyfile]] || ["#{ENV['HOME']}/.ssh/id_rsa"]

      @aix_hosts.each do |host|
        vm_name = host['vmname'] || host.name

        @logger.notify "Reverting #{vm_name} to aix clean state"
        start = Time.now
        # Restore AIX image, ID'd by the hostname
        hypervisor.exec(Command.new("cd pe-aix && rake restore:#{host.name}"))
        time = Time.now - start
        @logger.notify "Spent %.2f seconds reverting" % time
      end
      hypervisor.close
    end

    def cleanup
      @logger.notify "No cleanup for aix boxes"
    end

  end
end
