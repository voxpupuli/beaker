require 'beaker/hypervisor/vagrant'

class Beaker::VagrantWorkstation < Beaker::Vagrant
  def provision(provider = 'vmware_workstation')
    super
  end

  def self.provider_vfile_section(host, options)
    "    v.vm.provider :vmware_workstation do |v|\n" +
    "      v.vmx['memsize'] = '#{options['vagrant_memsize'] ||= '1024'}'\n" +
    "    end\n"
  end
end
