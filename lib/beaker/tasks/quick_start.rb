require 'beaker-hostgenerator'

CONFIG_DIR = 'acceptance/config'

VAGRANT  = ['ubuntu1404-64default.mdcal-ubuntu1404-64af', '--hypervisor=vagrant',
            '--global-config={box_url=https://vagrantcloud.com/puppetlabs/boxes/ubuntu-14.04-64-nocm,box=puppetlabs/ubuntu-14.04-64-nocm}']

VMPOOLER = ['redhat7-64default.mdcal-redhat7-64af']

namespace :beaker_quickstart do

  desc 'Generate Default Beaker Host Config File, valid options are: vmpooler or vagrant.'
  task :gen_hosts, [:hypervisor] do |t, args|
    hosts_file = "#{CONFIG_DIR}/default_#{args[:hypervisor]}_hosts.yaml"
    if args[:hypervisor] == 'vagrant'
      cli = VAGRANT
    elsif args[:hypervisor] == 'vmpooler'
      cli = VMPOOLER
    else
      puts "No hypervisor provided, defaulting to vagrant."
      hosts_file = "#{CONFIG_DIR}/default_vagrant_hosts.yaml"
      cli = VAGRANT
    end
    FileUtils.mkdir_p("#{CONFIG_DIR}") # -p creates intermediate directories as required
    puts "About to run - beaker-hostgenerator #{cli.to_s.delete!('[]"')}"
    if !File.exist?(hosts_file) then
      puts "Writing default host config to file - #{hosts_file}"
      File.open(hosts_file, 'w') do |fh|
        fh.print(BeakerHostGenerator::CLI.new(cli).execute)
      end
    else
      puts "Not overwriting Host Config File: #{hosts_file} - it already exists."
    end
  end


  desc 'Generate Default Pre-Suite'
  task :gen_pre_suite do
    pre_suite_file = "acceptance/setup/default_pre_suite.rb"
    FileUtils.mkdir_p('acceptance/setup') # -p ignores when dir already exists
    if !File.exist?(pre_suite_file) then
      puts "Writing default pre_suite to file - #{pre_suite_file}"
      File.open(pre_suite_file, 'w') do |fh|
        fh.print('install_puppet')
      end
    else
      puts "Not overwriting Pre Suite File: #{pre_suite_file} - it already exists."
    end
  end

  desc 'Generate Default Smoke Test'
  task :gen_smoke_test do
    smoke_test_file = "acceptance/setup/default_smoke_test.rb"
    FileUtils.mkdir_p('acceptance/tests') # -p ignores when dir already exists
    if !File.exist?(smoke_test_file) then
      puts "Writing default smoke test to file - #{smoke_test_file}"
      File.open("acceptance/tests/default_smoke_test.rb", 'w') do |fh|
        fh.print("test_name 'puppet install smoketest' do
  step 'puppet install smoketest: verify \\'puppet help\\' can be successfully called on
  all hosts' do
    hosts.each do |host|
      on host, puppet('help')
    end
  end
end")
      end
    else
      puts "Not overwriting Smoke Test File: #{smoke_test_file} - it already exists."
    end
  end

  desc 'Run Default Smoke Test, after generating default host config and test files, valid options are: vmpooler or vagrant.'
  task :run_test, [:hypervisor] => ["beaker_quickstart:gen_hosts", 'beaker_quickstart:gen_pre_suite',
                                     'beaker_quickstart:gen_smoke_test'] do
  |t, args|
    hypervisor             = args[:hypervisor] ||='vagrant'
    system_args             = Hash.new
    system_args[:hosts]     = "acceptance/config/default_#{hypervisor}_hosts.yaml"
    system_args[:pre_suite] = 'acceptance/setup/default_pre_suite.rb'
    system_args[:tests]     = 'acceptance/tests/default_smoke_test.rb'
    puts "About to run - #{beaker_command(system_args)}"
    system(beaker_command(system_args))
  end

end


def beaker_command(system_args)
  cmd_parts = []
  cmd_parts << "beaker"
  cmd_parts << "--hosts #{system_args[:hosts]}"
  cmd_parts << "--pre-suite #{system_args[:pre_suite]}"
  cmd_parts << "--tests #{system_args[:tests]}"
  cmd_parts.flatten.join(" ")
end
