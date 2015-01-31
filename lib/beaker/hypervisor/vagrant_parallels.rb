require 'beaker/hypervisor/vagrant'

class Beaker::VagrantParallels < Beaker::Vagrant
    def provision(provider = 'parallels')
        super
    end

    def self.provider_vfile_section(host, options)
        provider_section  = ""
        provider_section << "    v.vm.provider :parallels do |prl|\n"
        provider_section << "      prl.optimize_power_consumption = false\n"
        provider_section << "      prl.memory = '#{options['vagrant_memsize'] ||= '1024'}'\n"
        provider_section << "      prl.update_guest_tools = false\n" if options[:prl_update_guest_tools] == 'disable'
        provider_section << "    end\n"

        provider_section
    end
end
