module Beaker
  class Hypervisor

    CHARMAP = [('a'..'z'),('0'..'9')].map{|r| r.to_a}.flatten

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
          if options['pooling_api']
            Beaker::VcloudPooled
          else
            Beaker::Vcloud
          end
        when /vagrant/
          Beaker::Vagrant
        when /google/
          Beaker::GoogleCompute
        end
      hypervisor = hyper_class.new(hosts_to_provision, options)
      hypervisor.provision

      hypervisor
    end

    def provision
      nil
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
