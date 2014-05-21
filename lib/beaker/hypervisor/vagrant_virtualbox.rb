require 'beaker/hypervisor/vagrant'

class Beaker::VagrantVirtualbox < Beaker::Vagrant
  def provision(provider = 'virtualbox')
    super
  end
end
