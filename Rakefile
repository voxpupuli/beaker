require 'open3'
require 'securerandom'
require 'beaker-hostgenerator'
require 'beaker'
HOSTS_PRESERVED  = 'log/latest/hosts_preserved.yml'

task :default => [ 'test:spec' ]

task :test do
  Rake::Task['test:spec'].invoke
end

task :spec do
  Rake::Task['test:spec'].invoke
end


task :acceptance => ['test:base', 'test:puppetgit', 'test:hypervisor']


task :yard do
  Rake::Task['docs:gen'].invoke
end

task :history do
  Rake::Task['history:gen'].invoke
end

task :travis do
  Rake::Task['yard'].invoke if !Beaker::Shared::Semvar.version_is_less(RUBY_VERSION, '2.0.0')
  Rake::Task['spec'].invoke
end

module HarnessOptions
  defaults = {
      :tests  => ['tests'],
      :log_level => 'debug',
      :preserve_hosts => 'onfail',
  }

  DEFAULTS = defaults

  def self.get_options(file_path)
    puts "Attempting to merge config file: #{file_path}"
    if File.exists? file_path
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
  ENV['BEAKER_HOSTS']
end

def hosts_opt(use_preserved_hosts=false)
  if use_preserved_hosts
    "--hosts=#{HOSTS_PRESERVED}"
  else
    if hosts_file_env
      "--hosts=#{hosts_file_env}"
    else
      "--hosts=tmp/#{HOSTS_FILE}"
    end
  end
end

def agent_target
  ENV['TEST_TARGET'] || 'redhat7-64af'
end

def master_target
  ENV['MASTER_TEST_TARGET'] || 'redhat7-64default.mdcal'
end

def test_targets
  ENV['LAYOUT'] || "#{master_target}-#{agent_target}"
end

HOSTS_FILE = "#{test_targets}-#{SecureRandom.uuid}.yaml"

def beaker_test(mode = :base, options = {})

  preserved_hosts_mode = options[:hosts] == HOSTS_PRESERVED
  final_options = HarnessOptions.final_options(mode, options)

  options_opt  = ""
  # preserved hosts can not be used with an options file (BKR-670)
  #   one can still use OPTIONS

  if !preserved_hosts_mode
    options_file = 'merged_options.rb'
    options_opt  = "--options-file=#{options_file}"
    File.open(options_file, 'w') do |merged|
      merged.puts <<-EOS
# Copy this file to local_options.rb and adjust as needed if you wish to run
# with some local overrides.
      EOS
      merged.puts(final_options)
    end
  end

  tests = ENV['TESTS'] || ENV['TEST']
  tests_opt = ""
  tests_opt = "--tests=#{tests}" if tests

  overriding_options = ENV['OPTIONS'].to_s

  args = [options_opt, hosts_opt(preserved_hosts_mode), tests_opt,
          *overriding_options.split(' ')].compact

  sh("beaker", *args)
end


namespace :test do
  USAGE = <<-EOS
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
    original_dir = Dir.pwd
    Dir.chdir( File.expand_path(File.dirname(__FILE__)) )
    exit_status = 1
    output = ''
    Open3.popen3("bundle exec rspec") {|stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        puts line
      end
      output = stdout
      if not wait_thr.value.success?
        fail "Failed to 'bundle exec rspec' (exit status: #{wait_thr.value})"
      end
      exit_status = wait_thr.value
    }
    if exit_status != /0/
      #check for deprecation warnings
      if output =~ /Deprecation Warnings/
        fail "DEPRECATION WARNINGS in spec generation, please fix!"
      end
    end
    Dir.chdir( original_dir )
  end

  desc <<-EOS
Run the base beaker acceptance tests
#{USAGE}
  EOS
  task :base  => 'gen_hosts' do
    beaker_test(:base)
  end

  desc <<-EOS
Run the subcommand beaker acceptance tests
#{USAGE}
  EOS
  task :subcommands => 'gen_hosts' do
    beaker_test(:subcommands)
  end

  desc <<-EOS
Run the hypervisor beaker acceptance tests
#{USAGE}
  EOS
  task :hypervisor  => 'gen_hosts' do
    beaker_test(:hypervisor)
  end

  desc <<-EOS
Run the puppet beaker acceptance tests on a pe install.
#{USAGE}
  EOS
  task :puppetpe  => 'gen_hosts' do
    beaker_test(:puppetpe)
  end


  desc 'Generate Beaker Host Config File'
  task :gen_hosts do
    if hosts_file_env
      next
    end
    cli = BeakerHostGenerator::CLI.new([test_targets])
    FileUtils.mkdir_p('tmp') # -p ignores when dir already exists
    File.open("tmp/#{HOSTS_FILE}", 'w') do |fh|
      fh.print(cli.execute)
    end
  end
end


###########################################################
#
#   History Tasks
#
###########################################################
namespace :history do
  desc 'Generate HISTORY.md'
  task :gen do
    original_dir = Dir.pwd
    Dir.chdir( File.expand_path(File.dirname(__FILE__)) )
    output = `bundle exec ruby history.rb .`
    puts output
    if output !~ /success/
      raise "History generation failed"
    end
    Dir.chdir( original_dir )
  end

end

###########################################################
#
#   Documentation Tasks
#
###########################################################
DOCS_DIR = 'yard_docs'
DOCS_DAEMON = "yard server --reload --daemon --docroot #{DOCS_DIR}"
FOREGROUND_SERVER = "bundle exec yard server --reload --verbose lib/beaker --docroot #{DOCS_DIR}"

def running?( cmdline )
  ps = `ps -ef`
  found = ps.lines.grep( /#{Regexp.quote( cmdline )}/ )
  if found.length > 1
    raise StandardError, "Found multiple YARD Servers. Don't know what to do."
  end

  yes = found.empty? ? false : true
  return yes, found.first
end

def pid_from( output )
  output.squeeze(' ').strip.split(' ')[1]
end

desc 'Start the documentation server in the foreground'
task :docs => 'docs:clear' do
  original_dir = Dir.pwd
  Dir.chdir( File.expand_path(File.dirname(__FILE__)) )
  sh FOREGROUND_SERVER
  Dir.chdir( original_dir )
end

namespace :docs do

  desc 'Clear the generated documentation cache'
  task :clear do
    original_dir = Dir.pwd
    Dir.chdir( File.expand_path(File.dirname(__FILE__)) )
    sh "rm -rf #{DOCS_DIR}"
    Dir.chdir( original_dir )
  end

  desc 'Generate static documentation'
  task :gen => 'docs:clear' do
    original_dir = Dir.pwd
    Dir.chdir( File.expand_path(File.dirname(__FILE__)) )
    output = `bundle exec yard doc -o #{DOCS_DIR}`
    puts output
    if output =~ /\[warn\]|\[error\]/
      fail "Errors/Warnings during yard documentation generation"
    end
    Dir.chdir( original_dir )
  end

  desc 'Run the documentation server in the background, alias `bg`'
  task :background => 'docs:clear' do
    yes, output = running?( DOCS_DAEMON )
    if yes
      puts "Not starting a new YARD Server..."
      puts "Found one running with pid #{pid_from( output )}."
    else
      original_dir = Dir.pwd
      Dir.chdir( File.expand_path(File.dirname(__FILE__)) )
      sh "bundle exec #{DOCS_DAEMON}"
      Dir.chdir( original_dir )
    end
  end

  task(:bg) { Rake::Task['docs:background'].invoke }

  desc 'Check the status of the documentation server'
  task :status do
    yes, output = running?( DOCS_DAEMON )
    if yes
      pid = pid_from( output )
      puts "Found a YARD Server running with pid #{pid}"
    else
      puts "Could not find a running YARD Server."
    end
  end

  desc "Stop a running YARD Server"
  task :stop do
    yes, output = running?( DOCS_DAEMON )
    if yes
      pid = pid_from( output )
      puts "Found a YARD Server running with pid #{pid}"
      `kill #{pid}`
      puts "Stopping..."
      yes, output = running?( DOCS_DAEMON )
      if yes
        `kill -9 #{pid}`
        yes, output = running?( DOCS_DAEMON )
        if yes
          puts "Could not Stop Server!"
        else
          puts "Server stopped."
        end
      else
        puts "Server stopped."
      end
    else
      puts "Could not find a running YARD Server"
    end
  end
end
