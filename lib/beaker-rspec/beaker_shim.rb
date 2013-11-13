require 'beaker'

module BeakerRSpec
  module BeakerShim
    include Beaker::DSL

    def logger
      @logger
    end

    def options
      @options
    end

    def config
      @config
    end

    def provision
      @network_manager = Beaker::NetworkManager.new(@options, @logger)
      RSpec.configuration.hosts = @network_manager.provision
    end

    def validate
      Beaker::Utils::Validator.validate(RSpec.configuration.hosts, @logger)
    end

    def setup(args = [])
      @options_parser = Beaker::Options::Parser.new
      @options = @options_parser.parse_args(args)
      @options[:debug] = true
      @logger = Beaker::Logger.new(@options)
      @options[:logger] = @logger
      RSpec.configuration.hosts = []
    end

    def hosts
      RSpec.configuration.hosts
    end

    def cleanup
      @network_manager.cleanup
    end

  end
end
