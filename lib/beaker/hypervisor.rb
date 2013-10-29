module Beaker
  class Hypervisor

    def configure(hosts)
      @logger.debug "No post-provisioning configuration necessary for #{self.class.name} boxes"
    end

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
          Beaker::Vcloud
        when /vagrant/
          Beaker::Vagrant
        end
      hypervisor = hyper_class.new(hosts_to_provision, options)
      hypervisor.provision

      hypervisor
    end

    def provision
      nil
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
