require 'beaker/hypervisor/vagrant'

class Beaker::VagrantLibvirt < Beaker::Vagrant
  def provision(provider = 'libvirt')
    super
  end

  def self.provider_vfile_section(host, options)
    "    v.vm.provider :libvirt"
  end
end
