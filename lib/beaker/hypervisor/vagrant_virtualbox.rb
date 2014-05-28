require 'beaker/hypervisor/vagrant'

class Beaker::VagrantVirtualbox < Beaker::Vagrant
  def provision(provider = 'virtualbox')
    super
  end

  def self.provider_vfile_section(options)
    "  c.vm.provider :virtualbox do |vb|\n" +
    "    vb.customize [\"modifyvm\", :id, \"--memory\", \"#{options['vagrant_memsize'] ||= '1024'}\"]\n" +
    "  end\n"
  end
end
