require 'beaker/hypervisor/vagrant'

class Beaker::VagrantCustom < Beaker::Vagrant
  def provision(provider = nil)
    super
  end

  def make_vfile hosts, options = {}
    FileUtils.cp(@options[:vagrantfile_path], @vagrant_file)
  end
end
