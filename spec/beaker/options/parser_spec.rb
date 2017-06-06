require "spec_helper"

module Beaker
  module Options

    describe Parser do
      let(:parser) { Parser.new }
      let(:opts_path) { File.join(File.expand_path(File.dirname(__FILE__)), "data", "opts.txt") }
      let(:hosts_path) { File.join(File.expand_path(File.dirname(__FILE__)), "data", "hosts.cfg") }

      it "supports usage function" do
        expect { parser.usage }.to_not raise_error
      end

      describe 'parse_git_repos' do

        it "transforms arguments of <PROJECT_NAME>/<REF> to <GIT_BASE_URL>/<lowercased_project_name>#<REF>" do
          opts = ["PUPPET/3.1"]
          expect(parser.parse_git_repos(opts)).to be === ["#{parser.repo}/puppet.git#3.1"]
        end

        it "recognizes PROJECT_NAMEs of PUPPET, FACTER, HIERA, and HIERA-PUPPET" do
          projects = [['puppet', 'my_branch', 'PUPPET/my_branch'],
                      ['facter', 'my_branch', 'FACTER/my_branch'],
                      ['hiera', 'my_branch', 'HIERA/my_branch'],
                      ['hiera-puppet', 'my_branch', 'HIERA-PUPPET/my_branch']]
          projects.each do |project, ref, input|
            expect(parser.parse_git_repos([input])).to be === ["#{parser.repo}/#{project}.git##{ref}"]
          end
        end
      end

      describe 'split_arg' do

        it "can split comma separated list into an array" do
          arg = "file1,file2,file3"
          expect(parser.split_arg(arg)).to be === ["file1", "file2", "file3"]
        end

        it "can use an existing Array as an acceptable argument" do
          arg = ["file1", "file2", "file3"]
          expect(parser.split_arg(arg)).to be === ["file1", "file2", "file3"]
        end

        it "can generate an array from a single value" do
          arg = "i'mjustastring"
          expect(parser.split_arg(arg)).to be === ["i'mjustastring"]
        end
      end

      context 'testing path traversing' do

        let(:test_dir) { 'tmp/tests' }
        let(:rb_test) { File.expand_path(test_dir + '/my_ruby_file.rb') }
        let(:pl_test) { File.expand_path(test_dir + '/my_perl_file.pl') }
        let(:sh_test) { File.expand_path(test_dir + '/my_shell_file.sh') }
        let(:rb_other) { File.expand_path(test_dir + '/other/my_other_ruby_file.rb') }

        it 'only collects ruby files as test files' do
          files = [rb_test, pl_test, sh_test, rb_other]
          create_files(files)
          expect(parser.file_list([File.expand_path(test_dir)])).to be === [rb_test, rb_other]
        end

        it 'raises an error when no ruby files are found' do
          files = [pl_test, sh_test]
          create_files(files)
          expect { parser.file_list([File.expand_path(test_dir)]) }.to raise_error(ArgumentError)
        end

        it 'raises an error when no paths are specified for searching' do
          @files = ''
          expect { parser.file_list('') }.to raise_error(ArgumentError)
        end
      end

      context 'combining split_arg and file_list maintain test file ordering' do
        let(:test_dir) { 'tmp/tests' }
        let(:other_test_dir) { 'tmp/tests2' }

        before :each do
          files = [
              '00_EnvSetup.rb', '035_StopFirewall.rb', '05_HieraSetup.rb',
              '01_TestSetup.rb', '03_PuppetMasterSanity.rb',
              '06_InstallModules.rb', '02_PuppetUserAndGroup.rb',
              '04_ValidateSignCert.rb', '07_InstallCACerts.rb']

          @lone_file = '08_foss.rb'

          @fileset1 = files.shuffle.map { |file| test_dir + '/' + file }
          @fileset2 = files.shuffle.map { |file| other_test_dir + '/' + file }

          @sorted_expanded_fileset1 = @fileset1.map { |f| File.expand_path(f) }.sort
          @sorted_expanded_fileset2 = @fileset2.map { |f| File.expand_path(f) }.sort

          create_files(@fileset1)
          create_files(@fileset2)
          create_files([@lone_file])
        end

        it "when provided a file followed by dir, runs the file first" do
          arg    = "#{@lone_file},#{test_dir}"
          output = parser.file_list(parser.split_arg(arg))
          expect(output).to be === [@lone_file, @sorted_expanded_fileset1].flatten
        end

        it "when provided a dir followed by a file, runs the file last" do
          arg    = "#{test_dir},#{@lone_file}"
          output = parser.file_list(parser.split_arg(arg))
          expect(output).to be === [@sorted_expanded_fileset1, @lone_file].flatten
        end

        it "correctly orders files in a directory" do
          arg    = "#{test_dir}"
          output = parser.file_list(parser.split_arg(arg))
          expect(output).to be === @sorted_expanded_fileset1
        end

        it "when provided two directories orders each directory separately" do
          arg    = "#{test_dir}/,#{other_test_dir}/"
          output = parser.file_list(parser.split_arg(arg))
          expect(output).to be === @sorted_expanded_fileset1 + @sorted_expanded_fileset2
        end
      end

      describe '#parse_args' do
        before { FakeFS.deactivate! }

        it 'pulls the args into key called :command_line' do
          my_args = ['--log-level', 'debug', '-h', hosts_path]  

          expect(parser.parse_args(my_args)[:command_line]).to include(my_args.join(' '))
          expect(parser.attribution[:command_line]).to be == 'cmd'
          expect(parser.attribution[:hosts_file]).to be == 'cmd'
          expect(parser.attribution[:log_level]).to be == 'cmd'
          expect(parser.attribution[:pe_dir]).to be == 'preset'
        end

        describe 'does prioritization correctly' do
          let(:env) { @env || {:level => 'highest'} }
          let(:argv) { @argv || {:level => 'second'} }
          let(:host_file) { @host_file || {:level => 'third'} }
          let(:opt_file) { @opt_file || {:level => 'fourth', 
                            :ssh => {
                              :auth_methods => 'auth123',
                              :user_known_hosts_file => 'hosts123'
                            }                                
          } }
          let(:subcommand_file) {@subcommand_file || {:level => 'fifth'}}
          let(:homedir_file) {@homedir_file || {:level => 'sixth',
                              :ssh => {
                                :auth_methods => 'auth_home_123'
                              }
          }}
          let(:presets) { {:level => 'lowest',
                            :ssh => {
                              :config => 'config123',
                              :paranoid => 'paranoid123',
                              :port => 'port123',
                              :forward_agent => 'forwardagent123',
                              :keys => 'keys123',
                              :keepalive => 'keepalive123'
                            } 
          } }

          before :each do
            expect(parser).to receive(:normalize_args).and_return(true)
          end

          def mock_out_parsing
            presets_obj = double()
            allow(presets_obj).to receive(:presets).and_return(presets)
            allow(presets_obj).to receive(:env_vars).and_return(env)
            parser.instance_variable_set(:@presets, presets_obj)

            command_line_parser_obj = double()
            allow(command_line_parser_obj).to receive(:parse).and_return(argv)
            parser.instance_variable_set(:@command_line_parser, command_line_parser_obj)

            allow(OptionsFileParser).to receive(:parse_options_file).and_return(opt_file)
            allow(parser).to receive(:parse_hosts_options).and_return(host_file)

            allow(SubcommandOptionsParser).to receive(:parse_subcommand_options).and_return(homedir_file, subcommand_file)
          end

          it 'presets have the lowest priority' do
            @env = @argv = @host_file = @opt_file = @subcommand_file = @homedir_file = {}
            mock_out_parsing

            opts = parser.parse_args([])
            attribution = parser.attribution
            expect(opts[:level]).to be == 'lowest'
            expect(attribution[:level]).to be == 'preset'
          end

          it 'home directory options should have sixth priority' do
            @env = @argv = @host_file = @opt_file = @subcommand_file = {}
            mock_out_parsing

            opts = parser.parse_args([])
            attribution = parser.attribution
            expect(opts[:ssh][:auth_methods]).to be == 'auth_home_123'
            expect(attribution[:ssh][:auth_methods]).to be == 'homedir'
            expect(opts[:level]).to be == 'sixth'
            expect(attribution[:level]).to be == 'homedir'
          end

          it 'subcommand_options should have fifth priority' do
            @env = @argv = @host_file = @opt_file = {}
            mock_out_parsing

            opts = parser.parse_args([])
            attribution = parser.attribution
            expect(opts[:level]).to be == 'fifth'
            expect(attribution[:level]).to be == 'subcommand'
          end

          it 'options file has fourth priority' do
            @env = @argv = @host_file = {}
            mock_out_parsing

            opts = parser.parse_args([])
            attribution = parser.attribution
            expect(attribution[:ssh]).to be_a(Hash)
            expect(attribution[:ssh][:auth_methods]).to be == 'options_file'
            expect(attribution[:ssh][:user_known_hosts_file]).to be == 'options_file'
            expect(attribution[:ssh][:config]).to be == 'preset'
            expect(attribution[:ssh][:paranoid]).to be == 'preset'
            expect(attribution[:ssh][:port]).to be == 'preset'
            expect(attribution[:ssh][:forward_agent]).to be == 'preset'
            expect(attribution[:ssh][:keys]).to be == 'preset'
            expect(attribution[:ssh][:keepalive]).to be == 'preset'
            expect(opts[:level]).to be == 'fourth'
            expect(attribution[:level]).to be == 'options_file'
          end

          it 'host file CONFIG section has third priority' do
            @env = @argv = {}
            mock_out_parsing

            opts = parser.parse_args([])
            attribution = parser.attribution
            expect(opts[:level]).to be == 'third'
            expect(attribution[:level]).to be == 'host_file'
          end

          it 'command line arguments have second priority' do
            @env = {}
            mock_out_parsing

            opts = parser.parse_args([])
            attribution = parser.attribution
            expect(opts[:level]).to be == 'second'
            expect(attribution[:level]).to be == 'cmd'
          end

          it 'env vars have highest priority' do
            mock_out_parsing

            opts = parser.parse_args([])
            attribution = parser.attribution
            expect(opts[:level]).to be == 'highest'
            expect(attribution[:level]).to be == 'env'
          end

        end

        it "can correctly combine arguments from different sources" do
          build_url = 'http://my.build.url/'
          type      = 'git'
          log_level = 'debug'

          old_build_url    = ENV["BUILD_URL"]
          ENV["BUILD_URL"] = build_url

          args   = ["-h", hosts_path, "--log-level", log_level, "--type", type, "--install", "PUPPET/1.0,HIERA/hello"]
          output = parser.parse_args(args)
          attribution = parser.attribution
          expect(output[:hosts_file]).to be == hosts_path  
          expect(attribution[:hosts_file]).to be == 'cmd'
          expect(output[:jenkins_build_url]).to be == build_url
          expect(attribution[:jenkins_build_url]).to be == 'env'
          expect(output[:install]).to include('git://github.com/puppetlabs/hiera.git#hello')
          expect(attribution[:install]).to be == 'runtime'

          ENV["BUILD_URL"] = old_build_url
        end

        it "ensures that fail-mode is one of fast/slow" do
          args = ["-h", hosts_path, "--log-level", "debug", "--fail-mode", "nope"]
          expect { parser.parse_args(args) }.to raise_error(ArgumentError)
        end

      end

      describe '#parse_hosts_options' do

        context 'Hosts file exists' do
          before :each do
            allow(File).to receive(:exists?).and_return(true)
          end

          it 'returns the parser\'s output' do
            parser.instance_variable_set( :@options, {} )
            test_value = 'blaqwetjijl,emikfuj1235'
            allow( Beaker::Options::HostsFileParser ).to receive(
              :parse_hosts_file
            ).and_return( test_value )
            val1, _ = parser.parse_hosts_options
            expect( val1 ).to be === test_value
          end
        end

        context 'Hosts file does not exist' do
          require 'beaker-hostgenerator'
          before :each do
            allow(File).to receive(:exists?).and_return(false)
          end

          it 'calls beaker-hostgenerator to get hosts information' do
            parser.instance_variable_set( :@options, {
              :hosts_file => 'notafile.yml'
            } )
            allow( Beaker::Options::HostsFileParser ).to receive(
              :parse_hosts_file
            ).and_raise( Errno::ENOENT )

            mock_beaker_hostgenerator_cli = Object.new
            cli_execute_return = 'job150865'
            expect( mock_beaker_hostgenerator_cli ).to receive(
              :execute
            ).and_return( cli_execute_return )
            expect( BeakerHostGenerator::CLI ).to receive(
              :new
            ).and_return( mock_beaker_hostgenerator_cli )
            allow( Beaker::Options::HostsFileParser ).to receive(
              :parse_hosts_string
            ).with( cli_execute_return )
            parser.parse_hosts_options
          end

          it 'sets the :hosts_file_generated flag to signal others when needed' do
            options_test = {
              :hosts_file => 'not_a_file.yml'
            }
            parser.instance_variable_set( :@options, options_test )
            allow( Beaker::Options::HostsFileParser ).to receive(
              :parse_hosts_file
            ).and_raise( Errno::ENOENT )

            mock_beaker_hostgenerator_cli = Object.new
            allow( mock_beaker_hostgenerator_cli ).to receive( :execute )
            allow( BeakerHostGenerator::CLI ).to receive(
              :new
            ).and_return( mock_beaker_hostgenerator_cli )
            allow( Beaker::Options::HostsFileParser ).to receive( :parse_hosts_string )
            parser.parse_hosts_options

            expect( options_test[:hosts_file_generated] ).to be true
          end

          it 'beaker-hostgenerator failures trigger nice prints & a rethrow' do
            options_test = {
              :hosts_file => 'not_a_file.yml'
            }
            parser.instance_variable_set( :@options, options_test )
            allow( Beaker::Options::HostsFileParser ).to receive(
              :parse_hosts_file
            ).and_raise( Errno::ENOENT )

            mock_beaker_hostgenerator_cli = Object.new
            expect( BeakerHostGenerator::CLI ).to receive(
              :new
            ).and_return( mock_beaker_hostgenerator_cli )
            expect( mock_beaker_hostgenerator_cli ).to receive(
              :execute
            ).and_raise( BeakerHostGenerator::Exceptions::InvalidNodeSpecError )
            expect( Beaker::Options::HostsFileParser ).not_to receive( :parse_hosts_string )
            expect( $stdout ).to receive( :puts ).with(
              /does not exist/
            ).ordered
            expect( $stderr ).to receive( :puts ).with(
              /Exiting with an Error/
            ).ordered

            expect {
              parser.parse_hosts_options
            }.to raise_error( BeakerHostGenerator::Exceptions::InvalidNodeSpecError )
          end

          it 'can be passed a nil hosts file and get the default hash back' do
            parser.instance_variable_set( :@options, {} )

            host_options = parser.parse_hosts_options
            expect(host_options[:HOSTS]).to be === {}

          end
        end

      end

      context "set_default_host!" do

        let(:roles) { @roles || [["master", "agent", "database"], ["agent"]] }
        let(:node1) { {:node1 => {:roles => roles[0]}} }
        let(:node2) { {:node2 => {:roles => roles[1]}} }
        let(:hosts) { node1.merge(node2) }

        it "does nothing if the default host is already set" do
          @roles = [["master"], ["agent", "default"]]
          parser.set_default_host!(hosts)
          expect(hosts[:node1][:roles].include?('default')).to be === false
          expect(hosts[:node2][:roles].include?('default')).to be === true
        end

        it "makes the master default" do
          @roles = [["master"], ["agent"]]
          parser.set_default_host!(hosts)
          expect(hosts[:node1][:roles].include?('default')).to be === true
          expect(hosts[:node2][:roles].include?('default')).to be === false
        end

        it "makes a single node default" do
          @roles = [["master", "database", "dashboard", "agent"]]
          parser.set_default_host!(node1)
          expect(hosts[:node1][:roles].include?('default')).to be === true
        end

        it "makes a single non-master node default" do
          @roles = [["database", "dashboard", "agent"]]
          parser.set_default_host!(node1)
          expect(hosts[:node1][:roles].include?('default')).to be === true
        end

        it "raises an error if two nodes are defined as default" do
          @roles = [["master", "default"], ["default"]]
          expect { parser.set_default_host!(hosts) }.to raise_error(ArgumentError)
        end

      end

      describe "normalize_args" do
        let(:hosts) do
          Beaker::Options::OptionsHash.new.merge({
                                                     'HOSTS'          => {
                                                         :master => {
                                                             :roles    => ["master", "agent", "arbitrary_role"],
                                                             :platform => 'el-7-x86_64',
                                                             :user     => 'root',
                                                         },
                                                         :agent  => {
                                                             :roles    => ["agent", "default", "other_abitrary_role"],
                                                             :platform => 'el-7-x86_64',
                                                             :user     => 'root',
                                                         },
                                                     },
                                                     'fail_mode'      => 'slow',
                                                     'preserve_hosts' => 'always',
                                                     'host_tags'      => {}
                                                 })
        end

        def fake_hosts_file_for_platform(hosts, platform)
          hosts['HOSTS'].values.each { |h| h[:platform] = platform }
          filename = "hosts_file_#{platform}"
          File.open(filename, "w") do |file|
            YAML.dump(hosts, file)
          end
          filename
        end

        shared_examples_for(:a_platform_supporting_only_agents) do |platform, _type|

          it "restricts #{platform} hosts to agent" do
            args = []
            args << '--hosts' << fake_hosts_file_for_platform(hosts, platform)
            expect { parser.parse_args(args) }.to raise_error(ArgumentError, /#{platform}.*may not have roles: master, database, dashboard/)
          end
        end

        context "restricts agents" do
          it_should_behave_like(:a_platform_supporting_only_agents, 'windows-version-arch')
          it_should_behave_like(:a_platform_supporting_only_agents, 'el-4-arch')
        end

        context "ssh user" do

          it 'uses the ssh[:user] if it is provided' do
            hosts['HOSTS'][:master][:ssh] = {:user => 'hello'}
            parser.instance_variable_set(:@options, hosts)
            parser.normalize_args
            expect(hosts['HOSTS'][:master][:user]).to be == 'hello'
          end

          it 'uses default user if there is an ssh hash, but no ssh[:user]' do
            hosts['HOSTS'][:master][:ssh] = {:hello => 'hello'}
            parser.instance_variable_set(:@options, hosts)
            parser.normalize_args
            expect(hosts['HOSTS'][:master][:user]).to be == 'root'
          end

          it 'uses default user if no ssh hash' do
            parser.instance_variable_set(:@options, hosts)
            parser.normalize_args
            expect(hosts['HOSTS'][:master][:user]).to be == 'root'
          end
        end

      end

      describe '#normalize_tags!' do
        let (:test_tag_and      ) { @test_tag_and     || [] }
        let (:test_tag_or       ) { @test_tag_or      || [] }
        let (:test_tag_exclude  ) { @test_tag_exclude || [] }
        let (:options           ) {
          opts                    = Beaker::Options::OptionsHash.new
          opts[:test_tag_and]     = test_tag_and
          opts[:test_tag_or]      = test_tag_or
          opts[:test_tag_exclude] = test_tag_exclude
          opts
        }

        it 'does not error if no tags overlap' do
          @test_tag_and     = 'can,tommies,potatoes,plant'
          @test_tag_or      = 'juicy,zoomba,plantation'
          @test_tag_exclude = 'joey,long_running,pants'
          parser.instance_variable_set(:@options, options)

          expect { parser.normalize_test_tags! }.not_to raise_error
        end

        it 'splits the basic case correctly' do
          @test_tag_and     = 'can,tommies,potatoes,plant'
          @test_tag_or      = 'johnny,wordsmith,zebra'
          @test_tag_exclude = 'joey,long_running,pants'
          parser.instance_variable_set(:@options, options)

          parser.normalize_test_tags!
          expect(options[:test_tag_and]    ).to be === ['can', 'tommies', 'potatoes', 'plant']
          expect(options[:test_tag_or]     ).to be === ['johnny', 'wordsmith', 'zebra']
          expect(options[:test_tag_exclude]).to be === ['joey', 'long_running', 'pants']
        end

        it 'returns empty arrays for empty strings' do
          @test_tag_and     = ''
          @test_tag_or      = ''
          @test_tag_exclude = ''
          parser.instance_variable_set(:@options, options)

          parser.normalize_test_tags!
          expect(options[:test_tag_and]    ).to be === []
          expect(options[:test_tag_or]     ).to be === []
          expect(options[:test_tag_exclude]).to be === []
        end

        it 'lowercases all tags correctly for later use' do
          @test_tag_and     = 'jeRRy_And_tOM,PARka'
          @test_tag_or      = 'clearLy_They,Neva'
          @test_tag_exclude = 'lEet_spEAK,pOland'
          parser.instance_variable_set(:@options, options)

          parser.normalize_test_tags!
          expect(options[:test_tag_and]    ).to be === ['jerry_and_tom', 'parka']
          expect(options[:test_tag_or]     ).to be === ['clearly_they', 'neva']
          expect(options[:test_tag_exclude]).to be === ['leet_speak', 'poland']
        end
      end

      describe '#resolve_symlinks' do
        let (:options) { Beaker::Options::OptionsHash.new }

        it 'calls File.realpath if hosts_file is set' do
          options[:hosts_file] = opts_path
          parser.instance_variable_set(:@options, options)

          parser.resolve_symlinks!
          expect(parser.instance_variable_get(:@options)[:hosts_file]).to be === opts_path
        end

        it 'does not throw an error if hosts_file is not set' do
          options[:hosts_file] = nil
          parser.instance_variable_set(:@options, options)

          expect { parser.resolve_symlinks! }.to_not raise_error
        end
      end

      describe '#get_hypervisors' do
        it 'returns a unique list' do
          hosts_dupe   = {
              'vm1' => {hypervisor: 'hi'},
              'vm2' => {hypervisor: 'hi'},
              'vm3' => {hypervisor: 'bye'}
          }
          hosts_single = {'vm1' => {hypervisor: 'hi'}}

          expect(parser.get_hypervisors(hosts_dupe)).to eq(%w(hi bye))
          expect(parser.get_hypervisors(hosts_single)).to eq(%w(hi))
        end
      end

      describe '#get_roles' do
        it 'returns a unique list' do
          roles_dupe   = {
              'vm1' => {roles: ['master']},
              'vm2' => {roles: %w(database dashboard)},
              'vm3' => {roles: ['bye']}
          }
          roles_single = {'vm1' => {roles: ['hi']}}

          expect(parser.get_roles(roles_dupe)).to eq([['master'], %w(database dashboard), ['bye']])
          expect(parser.get_roles(roles_single)).to eq([['hi']])
        end
      end

      describe '#check_hypervisor_config' do
        let (:options) { Beaker::Options::OptionsHash.new }
        let (:invalid_file) { '/tmp/doesnotexist_visor.yml' }

        before :each do
          FakeFS.deactivate!
        end

        it 'checks ec2_yaml when blimpy' do
          options[:ec2_yaml] = hosts_path
          options[:dot_fog]  = invalid_file
          parser.instance_variable_set(:@options, options)

          expect { parser.check_hypervisor_config('blimpy') }.to_not raise_error
        end

        it 'throws an error if ec2_yaml for blimpy is invalid' do
          options[:ec2_yaml] = invalid_file
          options[:dot_fog]  = hosts_path
          parser.instance_variable_set(:@options, options)

          expect { parser.check_hypervisor_config('blimpy') }.to raise_error(ArgumentError, /required by blimpy/)
        end

        %w(aix solaris vcloud).each do |visor|
          it "checks dot_fog when #{visor}" do
            options[:ec2_yaml] = invalid_file
            options[:dot_fog]  = hosts_path
            parser.instance_variable_set(:@options, options)

            expect { parser.check_hypervisor_config(visor) }.to_not raise_error
          end

          it "throws an error if dot_fog for #{visor} is invalid" do
            options[:ec2_yaml] = hosts_path
            options[:dot_fog]  = invalid_file
            parser.instance_variable_set(:@options, options)

            expect { parser.check_hypervisor_config(visor) }.to raise_error(ArgumentError, /required by #{visor}/)
          end
        end

        it 'does not throw error on unknown visor' do
          expect { parser.check_hypervisor_config('unknown_visor') }.to_not raise_error
        end
      end
    end
  end
end
