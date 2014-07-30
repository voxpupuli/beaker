require 'beaker/hypervisor/vagrant'

class Beaker::VagrantFusion < Beaker::Vagrant
  def provision(provider = 'vmware_fusion')
    # By default vmware_fusion creates a .vagrant directory relative to the
    # Vagrantfile path. That means beaker tries to scp the VM to itself unless
    # we move the VM files elsewhere.
    ENV['VAGRANT_VMWARE_CLONE_DIRECTORY'] = '~/.vagrant/vmware_fusion'
    super
  end

  def self.provider_vfile_section(host, options)
    "    v.vm.provider :vmware_fusion do |v|\n" +
    "      v.vmx['memsize'] = '#{options['vagrant_memsize'] ||= '1024'}'\n" +
    "    end\n"
  end
end
