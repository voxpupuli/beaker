require 'beaker/hypervisor/vagrant'

class Beaker::VagrantOpenstack < Beaker::Vagrant
  def provision(provider = 'openstack')
    super
  end

  def self.provider_vfile_section(host, options)
    provider_section  = ""
    provider_section << "    v.ssh.username = '#{host['vagrant_user']}'\n"
    provider_section << ""
    provider_section << "    v.vm.provider :openstack do |os|\n"
    provider_section << "      os.openstack_auth_url = \"\#{ENV['OS_AUTH_URL']}/tokens\"\n"
    provider_section << "      os.username           = ENV['OS_USERNAME']\n"
    provider_section << "      os.password           = ENV['OS_PASSWORD']\n"
    provider_section << "      os.tenant_name        = ENV['OS_TENANT_NAME']\n"
    provider_section << "      os.flavor             = '#{host['flavor']}'\n"
    provider_section << "      os.image              = '#{host['image']}'\n"
    provider_section << "      os.floating_ip_pool   = '#{host['floating_ip_pool']}'\n"
    provider_section << "      os.sync_method        = 'none'\n"
    provider_section << "    end\n"

    provider_section
  end
end

