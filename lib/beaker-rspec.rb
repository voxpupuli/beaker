require 'beaker'

module BeakerRSpec
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
    @hosts = @network_manager.provision
  end

  def validate
    Beaker::Utils::Validator.validate(@hosts, @logger)
  end

  def setup(args = [])
    @options_parser = Beaker::Options::Parser.new
    @options = @options_parser.parse_args(args)
    @options[:debug] = true
    @logger = Beaker::Logger.new(@options)
    @options[:logger] = @logger
    @hosts = []
  end

  def hosts
    @hosts 
  end


  def cleanup
    @network_manager.cleanup
  end

end
