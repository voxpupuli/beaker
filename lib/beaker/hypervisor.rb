%w( host_prebuilt_steps ).each do |lib|
  begin
    require lib
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), lib))
  end
end

module Beaker
  #The Beaker class that interacts to all the supported hypervisors
  class Hypervisor
    include HostPrebuiltSteps

    #Generates an array with all letters a thru z and numbers 0 thru 9
    CHARMAP = [('a'..'z'),('0'..'9')].map{|r| r.to_a}.flatten

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
        when /none/
          Beaker::Hypervisor
        else
          raise "Invalid hypervisor: #{type}" 
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
      if @options[:add_master_entry]
        add_master_entry(@hosts, @options)
      end
   end

   #Default validation steps to be run for a given hypervisor
   def validate
     validate_host(@hosts, @options)
   end

    def generate_host_name
      CHARMAP[rand(25)] + (0...14).map{CHARMAP[rand(CHARMAP.length)]}.join
    end

    def copy_ssh_to_root host
      #make it possible to log in as root by copying the ssh dir to root's account
      @logger.debug "Give root a copy of current host's keys"
      if host['platform'] =~ /windows/
        host.exec(Command.new('sudo su -c "cp -r .ssh /home/Administrator/."'))
      else
        host.exec(Command.new('sudo su -c "cp -r .ssh /root/."'), {:pty => true})
      end
    end

    def hack_etc_hosts hosts
      etc_hosts = "127.0.0.1\tlocalhost localhost.localdomain\n"
      hosts.each do |host|
        etc_hosts += "#{host['ip'].to_s}\t#{host[:vmhostname] || host.name}\n"
      end
      hosts.each do |host|
        set_etc_hosts(host, etc_hosts)
      end
    end

  end
end

%w( vsphere_helper vagrant fusion blimper vsphere vcloud vcloud_pooled aixer solaris google_compute).each do |lib|
  begin
    require "hypervisor/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), "hypervisor", lib))
  end
end
