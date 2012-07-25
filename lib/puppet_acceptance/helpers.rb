require 'resolv'

module PuppetAcceptance
  # A generic place to provide helpers that are extra to the DSL.
  module Helpers
    # This method accepts a block and using the puppet resource 'host' will
    # setup host aliases before and after that block.
    #
    # A teardown step is also added to make sure unstubbing of the host is
    # removed always.
    #
    # @param machine [String] the host to execute this stub
    # @param hosts [Hash{String=>String}] a hash containing the host to ip
    #   mappings
    # @example Stub puppetlabs.com on the master to 127.0.0.1
    #   stub_hosts_on(master, 'puppetlabs.com' => '127.0.0.1')
    def stub_hosts_on(machine, hosts)
      hosts.each do |host, ip|
        @logger.notify("Stubbing host #{host} to IP #{ip} on machine #{machine}")
        on(machine, puppet_resource('host', host, 'ensure=present', "ip=#{ip}"))
      end

      teardown do
        hosts.each do |host, ip|
          @logger.notify("Unstubbing host #{host} to IP #{ip} on machine #{machine}")
          on(machine, puppet_resource('host', host, 'ensure=absent'))
        end
      end
    end

    # This wraps the method `stub_hosts_on` and makes the stub specific to
    # the forge alias.
    #
    # @param machine [String] the host to perform the stub on
    def stub_forge_on(machine)
      @forge_ip ||= Resolv.getaddress(forge)
      stub_hosts_on(machine, 'forge.puppetlabs.com' => @forge_ip)
    end
  end
end
