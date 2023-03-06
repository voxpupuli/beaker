module Beaker
  class Noop < Beaker::Hypervisor
    def initialize(hosts, options)
      super

      @logger = options[:logger]
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
