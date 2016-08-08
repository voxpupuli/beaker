require 'beaker-hostgenerator'

VAGRANT  = BeakerHostGenerator::CLI.new(['ubuntu1404-64default.mdcal-ubuntu1404-64af', '--hypervisor=vagrant',
                                         '--global-config={box_url=https://vagrantcloud.com/puppetlabs/boxes/ubuntu-14.04-64-nocm,box=puppetlabs/ubuntu-14.04-64-nocm'])
VMPOOLER = BeakerHostGenerator::CLI.new(['redhat7-64default.mdcal-redhat7-64af'])

namespace :beaker_quickstart do

  desc 'Generate Default Beaker Host Config File, valid options are: vmpooler or vagrant.'
  task :gen_hosts, [:provisioner] do |t, args|
    hosts_file = "acceptance/config/default__#{args[:provisioner]}_hosts.yaml"
    if args[:provisioner] == 'vagrant'
      cli = VAGRANT
    elsif args[:provisioner] == 'vmpooler'
      cli = VMPOOLER
    else
      puts "No provisioner provided, defaulting to vmpooler."
      hosts_file = "acceptance/config/default_vmpooler_hosts.yaml"
      cli = VMPOOLER
    end
    FileUtils.mkdir_p('acceptance/config') # -p ignores when dir already exists
    if !File.exist?(hosts_file) then
      File.open(hosts_file, 'w') do |fh|
        fh.print(cli.execute)
      end
    else
      puts "Host Config File: #{hosts_file} already exists so not overwriting"
    end
  end


  desc 'Generate Default Pre-Suite'
  task :gen_pre_suite do
    pre_suite_file = "acceptance/setup/default_pre_suite.rb"
    FileUtils.mkdir_p('acceptance/setup') # -p ignores when dir already exists
    if !File.exist?(pre_suite_file) then
      File.open(pre_suite_file, 'w') do |fh|
        fh.print('install_puppet')
      end
    else
      puts "Pre Suite File: #{pre_suite_file} already exists so not overwriting"
    end
  end

  desc 'Generate Default Smoke Test'
  task :gen_smoke_test do
    smoke_test_file = "acceptance/setup/default_pre_suite.rb"
    FileUtils.mkdir_p('acceptance/tests') # -p ignores when dir already exists
    if !File.exist?(smoke_test_file) then
      File.open("acceptance/tests/default_smoke_test.rb", 'w') do |fh|
        fh.print("test_name 'puppet install smoketest'
step 'puppet install smoketest: verify \\'puppet help\\' can be successfully called on
all hosts'
    hosts.each do |host|
      on host, puppet('help')
    end")
      end
    else
      puts "Smoke Test File: #{smoke_test_file} already exists so not overwriting"
    end
  end

  desc 'Run Default Smoke Test, after generating default host config and test files, valid options are: vmpooler or vagrant.'
  task :run_test, [:provisioner] => ["beaker_quickstart:gen_hosts", 'beaker_quickstart:gen_pre_suite',
                                     'beaker_quickstart:gen_smoke_test'] do
  |t, args|
    provisioner             = args[:provisioner] ||='vmpooler'
    system_args             = Hash.new
    system_args[:hosts]     = "acceptance/config/default_#{provisioner}_hosts.yaml"
    system_args[:pre_suite] = 'acceptance/setup/default_pre_suite.rb'
    system_args[:tests]     = 'acceptance/tests/default_smoke_test.rb'
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