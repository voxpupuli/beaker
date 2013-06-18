module PuppetAcceptance
  class Hypervisor

    attr_accessor :ssh_confs, :user, :ips, :names

    def set_defaults(hosts_to_provision)
      @ssh_confs = @ips = {}
      @user = nil
      @names = hosts_to_provision
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
        when /blimpy/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /vcloud/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
        when /vagrant/
          @logger.debug("PuppetAcceptance::Hypervisor, found some #{type} boxes to create") 
          PuppetAcceptance::Vagrant.new hosts_to_provision, options, config
        end
    end
  end
end

%w(vagrant).each do |lib|
  begin
    require "hypervisor/#{lib}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), "hypervisor", lib))
  end
end
