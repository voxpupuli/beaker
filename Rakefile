require 'open3'
require 'securerandom'
require 'beaker-hostgenerator'
require 'beaker'
HOSTS_PRESERVED  = 'log/latest/hosts_preserved.yml'

task :default => ['test:spec']

task :test do
  Rake::Task['test:spec'].invoke
end

task :spec do
  Rake::Task['test:spec'].invoke
end

task :acceptance => ['test:base', 'test:hypervisor']

module HarnessOptions
  defaults = {
    :tests => ['tests'],
    :log_level => 'debug',
    :preserve_hosts => 'onfail',
  }

  DEFAULTS = defaults

  def self.get_options(file_path)
    puts "Attempting to merge config file: #{file_path}"
    if File.exist? file_path
      options = eval(File.read(file_path), binding)
    else
      puts "No options file found at #{File.expand_path(file_path)}... skipping"
    end
    options || {}
  end

  def self.get_mode_options(mode)
    get_options("./acceptance/config/#{mode}/acceptance-options.rb")
  end

  def self.get_local_options
    get_options('./acceptance/local_options.rb')
  end

  def self.final_options(mode, intermediary_options = {})
    mode_options = get_mode_options(mode)
    local_overrides = get_local_options
    final_options = DEFAULTS.merge(mode_options)
    final_options.merge!(intermediary_options)
    final_options.merge!(local_overrides)
  end
end

def hosts_file_env
  ENV.fetch('BEAKER_HOSTS', nil)
end

def hosts_opt(use_preserved_hosts = false)
  if use_preserved_hosts
    "--hosts=#{HOSTS_PRESERVED}"
  elsif hosts_file_env
    "--hosts=#{hosts_file_env}"
  else
    "--hosts=tmp/#{HOSTS_FILE}"
  end
end

def agent_target
  ENV['TEST_TARGET'] || 'centos9-64af'
end

def master_target
  ENV['MASTER_TEST_TARGET'] || 'centos9-64default.mdcal'
end

def test_targets
  ENV['LAYOUT'] || "#{master_target}-#{agent_target}"
end

HOSTS_FILE = "#{test_targets}-#{SecureRandom.uuid}.yaml"

def beaker_test(mode = :base, options = {})
  preserved_hosts_mode = options[:hosts] == HOSTS_PRESERVED
  final_options = HarnessOptions.final_options(mode, options)

  options_opt = ""
  # preserved hosts can not be used with an options file (BKR-670)
  #   one can still use OPTIONS

  if !preserved_hosts_mode
    options_file = 'merged_options.rb'
    options_opt  = "--options-file=#{options_file}"
    File.open(options_file, 'w') do |merged|
      merged.puts <<~EOS
        # Copy this file to local_options.rb and adjust as needed if you wish to run
        # with some local overrides.
      EOS
      merged.puts(final_options)
    end
  end

  tests = ENV['TESTS'] || ENV.fetch('TEST', nil)
  tests_opt = ""
  tests_opt = "--tests=#{tests}" if tests

  overriding_options = ENV['OPTIONS'].to_s

  args = [options_opt, hosts_opt(preserved_hosts_mode), tests_opt, *overriding_options.split(' ')].compact

  sh("beaker", *args)
end

namespace :test do
  USAGE = <<~EOS
    You may set BEAKER_HOSTS=config/nodes/foo.yaml or include it in an acceptance-options.rb for Beaker,
    or specify TEST_TARGET in a form beaker-hostgenerator accepts, e.g. ubuntu1504-64a.
    You may override the default master test target by specifying MASTER_TEST_TARGET.
    You may set TESTS=path/to/test,and/more/tests.
    You may set additional Beaker OPTIONS='--more --options'
    If there is a Beaker options hash in a ./acceptance/local_options.rb, it will be included.
    Commandline options set through the above environment variables will override settings in this file.
  EOS

  desc 'Run specs and check for deprecation warnings'
  task :spec do
    Dir.chdir(__dir__) do
      exit_status = 1
      output = ''
      Open3.popen3("bundle exec rspec") do |_stdin, stdout, _stderr, wait_thr|
        while (line = stdout.gets)
          puts line
        end
        output = stdout.to_s
        fail "Failed to 'bundle exec rspec' (exit status: #{wait_thr.value})" if not wait_thr.value.success?

        exit_status = wait_thr.value
      end
      if exit_status != /0/
        # check for deprecation warnings
        fail "DEPRECATION WARNINGS in spec generation, please fix!" if output.include?('Deprecation Warnings')
      end
    end
  end

  desc <<~EOS
    Run the base beaker acceptance tests
    #{USAGE}
  EOS
  task :base => 'gen_hosts' do
    beaker_test(:base)
  end

  desc <<~EOS
    Run the subcommand beaker acceptance tests
    #{USAGE}
  EOS
  task :subcommands => 'gen_hosts' do
    beaker_test(:subcommands)
  end

  desc <<~EOS
    Run the hypervisor beaker acceptance tests
    #{USAGE}
  EOS
  task :hypervisor => 'gen_hosts' do
    beaker_test(:hypervisor)
  end

  desc 'Generate Beaker Host Config File'
  task :gen_hosts do
    next if hosts_file_env

    arguments = [test_targets]
    arguments += ['--hypervisor', ENV['BEAKER_HYPERVISOR']] if ENV['BEAKER_HYPERVISOR']
    cli = BeakerHostGenerator::CLI.new(arguments)
    FileUtils.mkdir_p('tmp') # -p ignores when dir already exists
    File.open("tmp/#{HOSTS_FILE}", 'w') do |fh|
      fh.print(cli.execute)
    end
  end
end

begin
  require 'rubygems'
  require 'github_changelog_generator/task'

  GitHubChangelogGenerator::RakeTask.new :changelog do |config|
    config.exclude_labels = %w{duplicate question invalid wontfix wont-fix skip-changelog}
    config.user = 'voxpupuli'
    config.project = 'beaker'
    gem_version = Gem::Specification.load("#{config.project}.gemspec").version
    config.future_release = gem_version
  end
rescue LoadError
  # Optional group in bundler
end

begin
  require 'voxpupuli/rubocop/rake'
rescue LoadError
  # the voxpupuli-rubocop gem is optional
end
