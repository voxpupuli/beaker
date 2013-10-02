module Beaker
  class Hypervisor

    def configure(hosts)
      @logger.debug "No post-provisioning configuration necessary for #{self.class.name} boxes"
    end

    def self.create type, hosts_to_provision, options
      @logger = options[:logger]
      @logger.notify("Beaker::Hypervisor, found some #{type} boxes to create") 
      case type
        when /aix/
          Beaker::Aixer.new(hosts_to_provision, options).provision
        when /solaris/
          Beaker::Solaris.new(hosts_to_provision, options).provision
        when /vsphere/
          Beaker::Vsphere.new hosts_to_provision, options
        when /fusion/
          Beaker::Fusion.new(hosts_to_provision, options).provision
        when /blimpy/
          Beaker::Blimper.new(hosts_to_provision, options).provision
        when /vcloud/
          Beaker::Vcloud.new hosts_to_provision, options
        when /vagrant/
          Beaker::Vagrant.new(hosts_to_provision, options).provision
        end
    end
  end
end

%w( vsphere_helper vagrant fusion blimper vsphere vcloud aixer solaris).each do |lib|
  begin
    require "hypervisor/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), "hypervisor", lib))
  end
end
