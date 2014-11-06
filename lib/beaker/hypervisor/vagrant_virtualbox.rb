require 'beaker/hypervisor/vagrant'

class Beaker::VagrantVirtualbox < Beaker::Vagrant
  def provision(provider = 'virtualbox')
    super
  end

  def self.provider_vfile_section(host, options)
    provider_section  = ""
    provider_section << "    v.vm.provider :virtualbox do |vb|\n"
    provider_section << "      vb.customize ['modifyvm', :id, '--memory', '#{options['vagrant_memsize'] ||= '1024'}']\n"
    provider_section << "      vb.vbguest.auto_update = false" if options[:vbguest_plugin] == 'disable'
    if host['disk_path']
      unless File.exist?(host['disk_path'])
        host['disk_path'] = File.join(host['disk_path'], "#{host.name}.vmdk")
        provider_section << "      vb.customize ['createhd', '--filename', '#{host['disk_path']}', '--size', #{host['disk_size'] ||= 5 * 1024}, '--format', 'vmdk']\n"
      end
      provider_section << "      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium','#{host['disk_path']}']\n"
      provider_section << "      vb.customize [\"modifyvm\", :id, \"--natdnshostresolver1\", \"#{host['natdns']}\"]\n" unless host['natdns'].nil?
      provider_section << "      vb.customize [\"modifyvm\", :id, \"--natdnsproxy1\", \"#{host['natdns']}\"]\n" unless host['natdns'].nil?
    end
    provider_section << "    end\n"

    provider_section
  end
end
