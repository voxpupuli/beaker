require 'beaker-hostgenerator'

namespace :beaker_quickstart do

  desc 'Generate Default Beaker Host Config File'
  task :gen_hosts do
    cli = BeakerHostGenerator::CLI.new(['redhat7-64default.mdcal-redhat7-64af'])
    FileUtils.mkdir_p('acceptance/config') # -p ignores when dir already exists
    File.open("acceptance/config/default_hosts.yaml", 'w') do |fh|
      fh.print(cli.execute)
    end
  end

  desc 'Generate Default Pre-Suite'
  task :gen_pre_suite do
    FileUtils.mkdir_p('acceptance/setup') # -p ignores when dir already exists
    File.open("acceptance/setup/default_pre_suite.rb", 'w') do |fh|
      fh.print('install_puppet')
    end
  end

  desc 'Generate Default Smoke Test'
  task :gen_smoke_test do
    FileUtils.mkdir_p('acceptance/tests') # -p ignores when dir already exists
    File.open("acceptance/tests/default_smoke_test.rb", 'w') do |fh|
      fh.print("test_name 'puppet install smoketest'
step 'puppet install smoketest: verify \\'puppet help\\' can be successfully called on
all hosts'
    hosts.each do |host|
      on host, puppet('help')
    end")
    end
  end

  desc 'Run Default Smoke Test'
  task :run => ['beaker_quickstart:gen_hosts', 'beaker_quickstart:gen_pre_suite', 'beaker_quickstart:gen_smoke_test'] do
    system(beaker_command)
  end

end

def beaker_command
  cmd_parts = []
  cmd_parts << "beaker"
  cmd_parts << "--hosts acceptance/config/default_hosts.yaml"
  cmd_parts << "--pre-suite acceptance/setup/default_pre_suite.rb"
  cmd_parts << "--tests acceptance/tests/default_smoke_test.rb"
  cmd_parts.flatten.join(" ")
end