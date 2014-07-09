[ 'host_prebuilt_steps' ].each do |lib|
  require "beaker/#{lib}"
end

module Beaker
  #The Beaker class that interacts to all the supported hypervisors
  class Hypervisor
    include HostPrebuiltSteps

    #Generates an array with all letters a thru z and numbers 0 thru 9
    CHARMAP = ('a'..'z').to_a + ('0'..'9').to_a

    #Hypervisor creator method.  Creates the appropriate hypervisor class object based upon
    #the provided hypervisor type selected, then provisions hosts with hypervisor.
    #@param [String] type The type of hypervisor to create - one of aix, solaris, vsphere, fusion,
    #                     blimpy, vcloud or vagrant
    #@param [Array<Host>] hosts_to_provision The hosts to be provisioned with the selected hypervisor
    #@param [Hash] options options Options to alter execution
    def self.create(type, hosts_to_provision, options)
      @logger = options[:logger]
      @logger.notify("Beaker::Hypervisor, found some #{type} boxes to create")
      hyper_class = case type
        when /aix/
          Beaker::Aixer
        when /solaris/
          Beaker::Solaris
        when /vsphere/
          Beaker::Vsphere
        when /fusion/
          Beaker::Fusion
        when /blimpy/
          Beaker::Blimper
        when /ec2/
          Beaker::AwsSdk
        when /vcloud/
          if options['pooling_api']
            Beaker::VcloudPooled
          else
            Beaker::Vcloud
          end
        when /vagrant/
          Beaker::Vagrant
        when /google/
          Beaker::GoogleCompute
        when /docker/
          Beaker::Docker
        when /openstack/
          Beaker::OpenStack
        when /none/
          Beaker::Hypervisor
        else
          # Custom hypervisor
          begin
            require "beaker/hypervisor/#{type}"
          rescue LoadError
            raise "Invalid hypervisor: #{type}"
          end
          const_get("Beaker::#{type.capitalize}")
        end

      hypervisor = hyper_class.new(hosts_to_provision, options)
      hypervisor.provision

      hypervisor
    end

    def initialize(hosts, options)
      @hosts = hosts
      @options = options
    end

    #Provisioning steps for be run for a given hypervisor.  Default is nil.
    def provision
      nil
    end

    #Cleanup steps to be run for a given hypervisor.  Default is nil.
    def cleanup
      nil
    end

    #Default configuration steps to be run for a given hypervisor
    def configure
      if @options[:timesync]
        timesync(@hosts, @options)
      end
      if @options[:root_keys]
        sync_root_keys(@hosts, @options)
      end
      if @options[:add_el_extras]
        add_el_extras(@hosts, @options)
      end
      if @options[:package_proxy]
        package_proxy(@hosts, @options)
      end
    end

    #Default validation steps to be run for a given hypervisor
    def validate
      if @options[:validate]
        validate_host(@hosts, @options)
      end
    end

    #Generate a random string composted of letter and numbers
    def generate_host_name
      CHARMAP[rand(25)] + (0...14).map{CHARMAP[rand(CHARMAP.length)]}.join
    end

  end
end

[ 'vsphere_helper', 'vagrant', 'fusion', 'blimper', 'aws_sdk', 'vsphere', 'vcloud', 'vcloud_pooled', 'aixer', 'solaris', 'docker', 'google_compute', 'openstack' ].each do |lib|
    require "beaker/hypervisor/#{lib}"
end
