module PuppetAcceptance
  class Hypervisor

    def configure(hosts)
      @logger.debug "No post-provisioning configuration necessary for #{self.class.name} boxes"
    end

    def self.create type, hosts_to_provision, options, config
      @logger = options[:logger]
      @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
      case type
        when /aix/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /solaris/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /vsphere/
          PuppetAcceptance::Vsphere.new hosts_to_provision, options, config
        when /fusion/
          PuppetAcceptance::Fusion.new hosts_to_provision, options, config
        when /blimpy/
          PuppetAcceptance::Blimper.new hosts_to_provision, options, config
        when /vcloud/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /vagrant/
          PuppetAcceptance::Vagrant.new hosts_to_provision, options, config
        end
    end
  end
end

%w(vsphere_helper vagrant fusion blimper vsphere).each do |lib|
  begin
    require "hypervisor/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), "hypervisor", lib))
  end
end
