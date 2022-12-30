require 'spec_helper'

def load_yaml_file(path)
  # Ruby 2.x has no safe_load_file
  if YAML.respond_to?(:safe_load_file)
    permitted = [Beaker::Options::OptionsHash, Symbol, RSpec::Mocks::Double, Time]
    YAML.safe_load_file(path, permitted_classes: permitted, aliases: true)
  else
    YAML.load_file(path)
  end
end

module Beaker
  describe CLI do

    let(:cli)      {
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('.beaker.yml').and_return(false)
      described_class.new.parse_options
    }

    context 'initializing and parsing' do
      let( :cli ) {
        described_class.new
      }

      describe 'instance variable initialization' do
        it 'creates a logger for use before parse is called' do
          expect(Beaker::Logger).to receive(:new).once.and_call_original
          expect(cli.logger).to be_instance_of(Beaker::Logger)
        end

        it 'generates the timestamp' do
          expect(Time).to receive(:now).once
          cli
        end
      end

      describe '#parse_options' do
        it 'returns self' do
          expect(cli.parse_options).to be_instance_of(described_class)
        end

        it 'replaces the logger object with a new one' do
          expect(Beaker::Logger).to receive(:new).with(no_args).once.and_call_original
          expect(Beaker::Logger).to receive(:new).once.and_call_original
          cli.parse_options
        end
      end

      describe '#parse_options special behavior' do
        # NOTE: this `describe` block must be separate, with the following `before` block.
        #       Use the above `describe` block for #parse_options when access to the logger object is not needed
        before do
          # Within parse_options() the reassignment of cli.logger makes it impossible to capture subsequent logger calls.
          # So, hijack the reassignment call so that we can keep a reference to it.
          allow(Beaker::Logger).to receive(:new).with(no_args).once.and_call_original
          allow(Beaker::Logger).to receive(:new).once.and_return(cli.instance_variable_get(:@logger))
        end

        it 'prints the version and exits cleanly' do
          expect(cli.logger).to receive(:notify).once
          expect{ cli.parse_options(['--version']) }.to raise_exception(SystemExit) { |e| expect(e.success?).to eq(true) }
        end

        it 'prints the help and exits cleanly' do
          expect(cli.logger).to receive(:notify).once
          expect{ cli.parse_options(['--help']) }.to raise_exception(SystemExit) { |e| expect(e.success?).to eq(true) }
        end
      end

      describe '#print_version_and_options' do
        before do
          options  = Beaker::Options::OptionsHash.new
          options[:beaker_version] = 'version_number'
          cli.instance_variable_set(:@options, options)
        end

        it 'prints the version and dumps the options' do
          expect(cli.logger).to receive(:info).exactly(3).times
          cli.print_version_and_options
        end
      end
    end


    describe '#configured_options' do
      it 'returns a list of options that were not presets' do
        attribution = cli.instance_variable_get(:@attribution)
        attribution.each do |attribute, setter|
          if setter == 'preset'
            expect(cli.configured_options[attribute]).to be_nil
          end
        end
      end
    end

    describe '#combined_instance_and_options_hosts' do
      let(:options_host) { {'HOSTS' => {'ubuntu' => {:options_attribute => 'options'}} }}
      let(:instance_host ) {
        [Beaker::Host.create('ubuntu', {:platform => 'host'}, {} )]
      }

      before do
        cli.instance_variable_set(:@options, options_host)
        cli.instance_variable_set(:@hosts, instance_host)
      end

      it 'combines the options and instance host objects' do
        merged_host = cli.combined_instance_and_options_hosts
        expect(merged_host).to have_key('ubuntu')
        expect(merged_host['ubuntu']).to have_key(:options_attribute)
        expect(merged_host['ubuntu']).to have_key(:platform)
        expect(merged_host['ubuntu'][:options_attribute]).to eq('options')
        expect(merged_host['ubuntu'][:platform]).to eq('host')
      end

      context 'when hosts share IP addresses' do
        let(:options_host) do
          {'HOSTS' => {'host1' => {:options_attribute => 'options'},
                       'host2' => {:options_attribute => 'options'}}}
        end
        let(:instance_host ) do
          [Beaker::Host.create('host1',
                               {:platform => 'host', :ip => '127.0.0.1'}, {} ),
           Beaker::Host.create('host2',
                               {:platform => 'host', :ip => '127.0.0.1'}, {} )]
        end

        it 'creates separate entries for each host' do
          expected_hosts = instance_host.map(&:hostname)
          merged_hosts = cli.combined_instance_and_options_hosts

          expect(merged_hosts.keys).to eq(expected_hosts)
        end
      end
    end

    context 'execute!' do
      before do
       stub_const("Beaker::Logger", double().as_null_object )
        File.open("sample.cfg", "w+") do |file|
          file.write("HOSTS:\n")
          file.write("  myhost:\n")
          file.write("    roles:\n")
          file.write("      - master\n")
          file.write("    platform: ubuntu-x-x\n")
          file.write("CONFIG:\n")
        end
        allow( cli ).to receive(:setup).and_return(true)
        allow( cli ).to receive(:validate).and_return(true)
        allow( cli ).to receive(:provision).and_return(true)
      end

      describe "test fail mode" do
        it 'runs pre_cleanup after a failed pre_suite if using slow fail_mode' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'slow'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode])
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          expect( cli ).to receive(:run_suite).twice
          expect{ cli.execute! }.to raise_error
          expect(cli.instance_variable_get(:@attribution)[:logger]).to be == 'runtime'
          expect(cli.instance_variable_get(:@attribution)[:timestamp]).to be == 'runtime'
          expect(cli.instance_variable_get(:@attribution)[:beaker_version]).to be == 'runtime'

        end

        it 'continues testing after failed test if using slow fail_mode' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'slow'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          expect( cli ).to receive(:run_suite).exactly( 4 ).times
          expect{ cli.execute! }.to raise_error

        end

        it 'stops testing after failed test if using fast fail_mode' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          expect( cli ).to receive(:run_suite).exactly( 3 ).times
          expect{ cli.execute! }.to raise_error

        end
      end

      describe "SUT preserve mode" do
        it 'cleans up SUTs post testing if tests fail and preserve_hosts = never' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'never'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).once

          expect{ cli.execute! }.to raise_error

        end

        it 'cleans up SUTs post testing if no tests fail and preserve_hosts = never' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'never'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).once

          expect{ cli.execute! }.not_to raise_error

        end


        it 'preserves SUTs post testing if no tests fail and preserve_hosts = always' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'always'
          options[:log_dated_dir] = '.'
          options[:hosts_file] = 'sample.cfg'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)
          cli.instance_variable_set(:@hosts, {})

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).not_to receive(:cleanup)

          expect{ cli.execute! }.not_to raise_error

        end

        it 'preserves SUTs post testing if no tests fail and preserve_hosts = always' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'always'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).not_to receive(:cleanup)

          expect{ cli.execute! }.to raise_error
        end

        it 'cleans up SUTs post testing if no tests fail and preserve_hosts = onfail' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onfail'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).once

          expect{ cli.execute! }.not_to raise_error

        end

        it 'preserves SUTs post testing if tests fail and preserve_hosts = onfail' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onfail'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).not_to receive(:cleanup)

          expect{ cli.execute! }.to raise_error

        end

        it 'cleans up SUTs post testing if tests fail and preserve_hosts = onpass' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onpass'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_throw("bad test")
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).to receive(:cleanup).once

          expect{ cli.execute! }.to raise_error

        end

        it 'preserves SUTs post testing if no tests fail and preserve_hosts = onpass' do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onpass'
          options[:log_dated_dir] = '.'
          options[:hosts_file] = 'sample.cfg'
          cli.instance_variable_set(:@hosts, {})
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).not_to receive(:cleanup)

          expect{ cli.execute! }.not_to raise_error
        end
      end

      describe "#preserve_hosts_file" do
        it 'removes the pre-suite/post-suite/tests and sets to []' do
          hosts =  make_hosts
          options = cli.instance_variable_get(:@options)
          options[:log_dated_dir] = Dir.mktmpdir
          File.open("sample.cfg", "w+") do |file|
            file.write("HOSTS:\n")
            hosts.each do |host|
              file.write("  #{host.name}:\n")
              file.write("    roles:\n")
              host[:roles].each do |role|
                file.write("      - #{role}\n")
              end
              file.write("    platform: #{host[:platform]}\n")
            end
            file.write("CONFIG:\n")
          end
          options[:hosts_file] = 'sample.cfg'
          options[:pre_suite] = ['pre1', 'pre2', 'pre3']
          options[:post_suite] = ['post1']
          options[:pre_cleanup] = ['preclean1']
          options[:tests] = ['test1', 'test2']

          cli.instance_variable_set(:@options, options)
          cli.instance_variable_set(:@hosts, hosts)

          preserved_file = cli.preserve_hosts_file
          hosts_yaml = load_yaml_file(preserved_file)
          expect(hosts_yaml['CONFIG'][:tests]).to be == []
          expect(hosts_yaml['CONFIG'][:pre_suite]).to be == []
          expect(hosts_yaml['CONFIG'][:post_suite]).to be == []
          expect(hosts_yaml['CONFIG'][:pre_cleanup]).to be == []
        end
      end

      describe 'hosts file saving when preserve_hosts should happen' do

        before do
          options = cli.instance_variable_get(:@options)
          options[:fail_mode] = 'fast'
          options[:preserve_hosts] = 'onpass'
          options[:hosts_file] = 'sample.cfg'
          cli.instance_variable_set(:@options, options)
          allow( cli ).to receive(:run_suite).with(:pre_suite, :fast).and_return(true)
          allow( cli ).to receive(:run_suite).with(:tests, options[:fail_mode]).and_return(true)
          allow( cli ).to receive(:run_suite).with(:post_suite).and_return(true)
          allow( cli ).to receive(:run_suite).with(:pre_cleanup).and_return(true)

          hosts = [
            make_host('petey', { :hypervisor => 'peterPan' }),
            make_host('hatty', { :hypervisor => 'theMadHatter' }),
          ]
          cli.instance_variable_set(:@hosts, hosts)

          netmanager = double(:netmanager)
          cli.instance_variable_set(:@network_manager, netmanager)
          expect( netmanager ).not_to receive(:cleanup)


          allow( cli ).to receive( :print_env_vars_affecting_beaker )
          logger = cli.instance_variable_get(:@logger)
          expect( logger ).to receive( :send ).with( anything, anything ).ordered
          expect( logger ).to receive( :send ).with( anything, anything ).ordered
        end

        it 'executes without error' do
          options = cli.instance_variable_get(:@options)
          Dir.mktmpdir do |dir|
            options[:log_dated_dir] = File.absolute_path(dir)

            expect{ cli.execute! }.not_to raise_error
          end
        end

        it 'copies a file into the correct location' do
          options = cli.instance_variable_get(:@options)
          Dir.mktmpdir do |dir|
            options[:log_dated_dir] = File.absolute_path(dir)

            cli.execute!

            copied_hosts_file = File.join(File.absolute_path(dir), 'hosts_preserved.yml')
            expect( File ).to exist(copied_hosts_file)
          end
        end

        it 'generates a valid YAML file when it copies' do
          options = cli.instance_variable_get(:@options)
          Dir.mktmpdir do |dir|
            options[:log_dated_dir] = File.absolute_path(dir)

            cli.execute!

            copied_hosts_file = File.join(File.absolute_path(dir), 'hosts_preserved.yml')
            expect{ load_yaml_file(copied_hosts_file) }.not_to raise_error
          end
        end

        it 'sets :provision to false in the copied hosts file' do
          options = cli.instance_variable_get(:@options)
          Dir.mktmpdir do |dir|
            options[:log_dated_dir] = File.absolute_path(dir)

            cli.execute!

            copied_hosts_file = File.join(File.absolute_path(dir), 'hosts_preserved.yml')
            yaml_content = load_yaml_file(copied_hosts_file)
            expect( yaml_content['CONFIG']['provision'] ).to be_falsy
          end
        end

        it 'sets the @options :hosts_preserved_yaml_file to the copied file' do
          options = cli.instance_variable_get(:@options)
          Dir.mktmpdir do |dir|
            options[:log_dated_dir] = File.absolute_path(dir)

            expect( options ).not_to have_key(:hosts_preserved_yaml_file)
            cli.execute!
            expect( options ).to have_key(:hosts_preserved_yaml_file)

            copied_hosts_file = File.join(File.absolute_path(dir), 'hosts_preserved.yml')
            expect( options[:hosts_preserved_yaml_file] ).to be === copied_hosts_file
          end
        end

        describe 'output text informing the user that re-use is possible' do

          it 'if unsupported, does not output extra text' do
            options = cli.instance_variable_get(:@options)
            Dir.mktmpdir do |dir|
              options[:log_dated_dir] = File.absolute_path(dir)
              copied_hosts_file = File.join(File.absolute_path(dir), options[:hosts_file])

              logger = cli.instance_variable_get(:@logger)
              expect( logger ).not_to receive( :send ).with( anything, "\nYou can re-run commands against the already provisioned SUT(s) by following these steps:\n")
              expect( logger ).not_to receive( :send ).with( anything, "- change the hosts file to #{copied_hosts_file}")
              expect( logger ).not_to receive( :send ).with( anything, '- use the --no-provision flag')

              cli.execute!
            end
          end

          it 'if supported, outputs the text letting the user know they can re-use these hosts' do
            options = cli.instance_variable_get(:@options)
            Dir.mktmpdir do |dir|
              options[:log_dated_dir] = File.absolute_path(dir)

              hosts = cli.instance_variable_get(:@hosts)
              hosts << make_host('fusion', { :hypervisor => 'fusion' })

              reproducing_cmd = "the faith of the people"
              allow( cli ).to receive( :build_hosts_preserved_reproducing_command ).and_return( reproducing_cmd )

              logger = cli.instance_variable_get(:@logger)
              expect( logger ).to receive( :send ).with( anything, "\nYou can re-run commands against the already provisioned SUT(s) with:\n").ordered
              expect( logger ).to receive( :send ).with( anything, reproducing_cmd).ordered

              cli.execute!
            end
          end

          it 'if supported && docker is a hypervisor, outputs text + the untested warning' do
            options = cli.instance_variable_get(:@options)
            Dir.mktmpdir do |dir|
              options[:log_dated_dir] = File.absolute_path(dir)

              hosts = cli.instance_variable_get(:@hosts)
              hosts << make_host('fusion', { :hypervisor => 'fusion' })
              hosts << make_host('docker', { :hypervisor => 'docker' })

              reproducing_cmd = "the crow flies true says the shoe to you"
              allow( cli ).to receive( :build_hosts_preserved_reproducing_command ).and_return( reproducing_cmd )

              logger = cli.instance_variable_get(:@logger)
              expect( logger ).to receive( :send ).with( anything, "\nYou can re-run commands against the already provisioned SUT(s) with:\n").ordered
              expect( logger ).to receive( :send ).with( anything, '(docker support is untested for this feature. please reference the docs for more info)').ordered
              expect( logger ).to receive( :send ).with( anything, reproducing_cmd).ordered

              cli.execute!
            end
          end

          it 'if unsupported && docker is a hypervisor, no extra text output' do
            options = cli.instance_variable_get(:@options)
            Dir.mktmpdir do |dir|
              options[:log_dated_dir] = File.absolute_path(dir)
              copied_hosts_file = File.join(File.absolute_path(dir), options[:hosts_file])

              hosts = cli.instance_variable_get(:@hosts)
              hosts << make_host('docker', { :hypervisor => 'docker' })

              logger = cli.instance_variable_get(:@logger)
              expect( logger ).not_to receive( :send ).with( anything, "\nYou can re-run commands against the already provisioned SUT(s) with:\n")
              expect( logger ).not_to receive( :send ).with( anything, '(docker support is untested for this feature. please reference the docs for more info)')
              expect( logger ).not_to receive( :send ).with( anything, "- change the hosts file to #{copied_hosts_file}")
              expect( logger ).not_to receive( :send ).with( anything, '- use the --no-provision flag')

              cli.execute!
            end
          end


        end
      end

      describe '#build_hosts_preserved_reproducing_command' do

        it 'replaces the hosts file' do
          new_hosts_file  = 'john/deer/was/here.txt'
          command_to_sub  = 'p --log-level debug --hosts pants/of/plan.poo jam --jankies --flag-business'
          command_correct = "p --log-level debug --hosts #{new_hosts_file} jam --jankies --flag-business"

          answer = cli.build_hosts_preserved_reproducing_command(command_to_sub, new_hosts_file)
          expect( answer ).to be_start_with(command_correct)
        end

        it 'doesn\'t replace an entry if no --hosts key is found' do
          command_to_sub  = 'p --log-level debug johnnypantaloons7 --jankies --flag-business'
          command_correct = 'p --log-level debug johnnypantaloons7 --jankies --flag-business'

          answer = cli.build_hosts_preserved_reproducing_command(command_to_sub, 'john/deer/plans.txt')
          expect( answer ).to be_start_with(command_correct)
        end

        it 'removes any old --provision flags' do
          command_to_sub  = '--provision jam  --provision --jankies --flag-business'
          command_correct = 'jam --jankies --flag-business'

          answer = cli.build_hosts_preserved_reproducing_command(command_to_sub, 'can/talk/to/pigs.yml')
          expect( answer ).to be_start_with(command_correct)
        end

        it 'removes any old --no-provision flags' do
          command_to_sub  = 'jam  --no-provision --jankoos --no-provision --flag-businesses'
          command_correct = 'jam --jankoos --flag-businesses'

          answer = cli.build_hosts_preserved_reproducing_command(command_to_sub, 'can/talk/to/bears.yml')
          expect( answer ).to be_start_with(command_correct)
        end
      end

    end
  end
end
