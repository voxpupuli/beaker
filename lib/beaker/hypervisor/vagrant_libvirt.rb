require 'beaker/hypervisor/vagrant'

class Beaker::VagrantLibvirt < Beaker::Vagrant
  @memory = nil

  class << self
    attr_reader :memory
  end

  def provision(provider = 'libvirt')
    super
  end

  def self.provider_vfile_section(host, options)
    "    v.vm.provider :libvirt do |node|\n" +
      "      node.memory = #{memory(host, options)}\n" +
      "    end\n"
  end

  def self.memory(host, options)
    return @memory unless @memory.nil?
    @memory = case
    when host['vagrant_memsize']
      host['vagrant_memsize']
    when options['vagrant_memsize']
      options['vagrant_memsize']
    else
      '512'
    end
  end
end
