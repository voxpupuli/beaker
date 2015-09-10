module Beaker
  class Noop < Beaker::Hypervisor

    def initialize(new_hosts, options)
      @options = options
      @logger = options[:logger]
      @hosts = new_hosts
    end

    def validate
      # noop
    end

    def configure
      # noop
    end

    def proxy_package_manager
      # noop
    end

    def provision
      # noop
    end

    def cleanup
      # noop
    end

  end
end
