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
    @network_manager = Beaker::NetworkManager.new(@config, @options, @logger)
    @hosts = @network_manager.provision
  end

  def validate
    Beaker::Utils::Validator.validate(@hosts, @logger)
  end

  def setup(config_file = 'sample.cfg')
    @options ||=
    {
      :provision => true,
      :debug => true,
      :config => config_file,
      :preserve_hosts => false,
      :root_keys => false,
      :keyfile => "#{ENV['HOME']}/.ssh/id_rsa",
      :quiet => false,
      :xml => false,
      :color => true,
      :dry_run => false,
      :timesync => false,
      :repo_proxy => false,
      :add_el_extras => false,
      :type => 'pe',
      :pre_suite => [],
      :post_suite => [],
      :tests => [],
    }
    @logger ||= Beaker::Logger.new(options)
    @options[:logger] = @logger
    @config ||= Beaker::TestConfig.new(options[:config], options)
    @hosts = []
    provision
    validate
  end

  def hosts
    @hosts 
  end


  def cleanup
    @network_manager.cleanup
  end

end
