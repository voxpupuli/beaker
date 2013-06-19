module PuppetAcceptance
  class Hypervisor

    def configure(hosts)
      @logger.debug "No post-provisioning configuration necessary for #{self.class.name} boxes"
    end

    def self.create type, hosts_to_provision, options, config
      @logger = options[:logger]
      case type
        when /aix/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /solaris/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /vsphere/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /fusion/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
          PuppetAcceptance::Fusion.new hosts_to_provision, options, config
        when /blimpy/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
          PuppetAcceptance::Blimper.new hosts_to_provision, options, config
        when /vcloud/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /vagrant/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
          PuppetAcceptance::Vagrant.new hosts_to_provision, options, config
        end
    end
  end
end

%w(vagrant fusion blimper).each do |lib|
  begin
    require "hypervisor/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), "hypervisor", lib))
  end
end
