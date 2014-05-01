require "spec_helper"

module Beaker
  module Options

    describe Parser do
      let(:parser)           { Parser.new }
      let(:opts_path)        { File.join(File.expand_path(File.dirname(__FILE__)), "data", "opts.txt") }
      let(:hosts_path)       { File.join(File.expand_path(File.dirname(__FILE__)), "data", "hosts.cfg") }
      let(:badyaml_path)     { File.join(File.expand_path(File.dirname(__FILE__)), "data", "badyaml.cfg") }
      let(:home)             { ENV['HOME'] }

      it "supports usage function" do
        expect{parser.usage}.to_not raise_error
      end

      repo = 'git://github.com/puppetlabs'

      it "has repo set to #{repo}" do
        expect(parser.repo).to be === "#{repo}"
      end

      #test parse_install_options
      it "can transform --install PUPPET/3.1 into #{repo}/puppet.git#3.1" do
        opts = ["PUPPET/3.1"]
        expect(parser.parse_git_repos(opts)).to be === ["#{repo}/puppet.git#3.1"]
      end
      it "can transform --install FACTER/v.1.0 into #{repo}/facter.git#v.1.0" do
        opts = ["FACTER/v.1.0"]
        expect(parser.parse_git_repos(opts)).to be === ["#{repo}/facter.git#v.1.0"]
      end
      it "can transform --install HIERA/xyz into #{repo}/hiera.git#xyz" do
        opts = ["HIERA/xyz"]
        expect(parser.parse_git_repos(opts)).to be === ["#{repo}/hiera.git#xyz"]
      end
      it "can transform --install HIERA-PUPPET/path/to/repo into #{repo}/hiera-puppet.git#path/to/repo" do
        opts = ["HIERA-PUPPET/path/to/repo"]
        expect(parser.parse_git_repos(opts)).to be === ["#{repo}/hiera-puppet.git#path/to/repo"]
      end
      it "can transform --install PUPPET/3.1,FACTER/v.1.0 into #{repo}/puppet.git#3.1,#{repo}/facter.git#v.1.0" do
        opts = ["PUPPET/3.1", "FACTER/v.1.0"]
        expect(parser.parse_git_repos(opts)).to be === ["#{repo}/puppet.git#3.1", "#{repo}/facter.git#v.1.0"]
      end
      it "can leave --install git://github.com/puppetlabs/puppet.git#my/full/path alone" do
        opts = ["git://github.com/puppetlabs/puppet.git#my/full/path"]
        expect(parser.parse_git_repos(opts)).to be === ["git://github.com/puppetlabs/puppet.git#my/full/path"]
      end

      #split_arg testing
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

      context 'testing path traversing', :use_fakefs => true do
        let(:test_dir) { 'tmp/tests' }

        let(:paths)  { create_files(@files) }
        let(:rb_test)  { File.expand_path(test_dir + '/my_ruby_file.rb')    }
        let(:pl_test)  { File.expand_path(test_dir + '/my_perl_file.pl')    }
        let(:sh_test)  { File.expand_path(test_dir + '/my_shell_file.sh')   }
        let(:rb_other)  { File.expand_path(test_dir + '/other/my_other_ruby_file.rb')   }

        it 'only collects ruby files as test files' do
          @files = [ rb_test, pl_test, sh_test, rb_other ]
          paths
          expect(parser.file_list([File.expand_path(test_dir)])).to be === [rb_test, rb_other]
        end
        it 'raises an error when no ruby files are found' do
          @files = [ pl_test, sh_test ]
          paths
          expect{parser.file_list([File.expand_path(test_dir)])}.to raise_error(ArgumentError)
        end
        it 'raises an error when no paths are specified for searching' do
          @files = ''
          expect{parser.file_list('')}.to raise_error(ArgumentError)
        end

      end

      context 'combining split_arg and file_list maintain test file ordering', :use_fakefs => true do
        let(:test_dir) { 'tmp/tests/' }
        let(:other_test_dir) {'tmp/tests2/' }

        before :each do
          @files = ['00_EnvSetup.rb', '035_StopFirewall.rb', '05_HieraSetup.rb', '01_TestSetup.rb', '03_PuppetMasterSanity.rb', '06_InstallModules.rb', '02_PuppetUserAndGroup.rb', '04_ValidateSignCert.rb', '07_InstallCACerts.rb'].shuffle!.map!{|x| test_dir + x }
          @other_files = ['00_EnvSetup.rb', '035_StopFirewall.rb', '05_HieraSetup.rb', '01_TestSetup.rb', '03_PuppetMasterSanity.rb', '06_InstallModules.rb', '02_PuppetUserAndGroup.rb', '04_ValidateSignCert.rb', '07_InstallCACerts.rb'].shuffle!.map!{|x| other_test_dir + x }
          create_files(@files)
          create_files(@other_files)
          create_files(['08_foss.rb'])
        end

        it "when provided a file followed by dir, runs the file first" do
          arg = "08_foss.rb,#{test_dir}"
          expect(parser.file_list(parser.split_arg(arg))).to be === ["08_foss.rb", "#{File.expand_path(test_dir)}/00_EnvSetup.rb", "#{File.expand_path(test_dir)}/01_TestSetup.rb", "#{File.expand_path(test_dir)}/02_PuppetUserAndGroup.rb", "#{File.expand_path(test_dir)}/035_StopFirewall.rb", "#{File.expand_path(test_dir)}/03_PuppetMasterSanity.rb", "#{File.expand_path(test_dir)}/04_ValidateSignCert.rb", "#{File.expand_path(test_dir)}/05_HieraSetup.rb", "#{File.expand_path(test_dir)}/06_InstallModules.rb", "#{File.expand_path(test_dir)}/07_InstallCACerts.rb"]
        end

        it "when provided a dir followed by a file, runs the file last" do
          arg = "#{test_dir},08_foss.rb"
          expect(parser.file_list(parser.split_arg(arg))).to be === ["#{File.expand_path(test_dir)}/00_EnvSetup.rb", "#{File.expand_path(test_dir)}/01_TestSetup.rb", "#{File.expand_path(test_dir)}/02_PuppetUserAndGroup.rb", "#{File.expand_path(test_dir)}/035_StopFirewall.rb", "#{File.expand_path(test_dir)}/03_PuppetMasterSanity.rb", "#{File.expand_path(test_dir)}/04_ValidateSignCert.rb", "#{File.expand_path(test_dir)}/05_HieraSetup.rb", "#{File.expand_path(test_dir)}/06_InstallModules.rb", "#{File.expand_path(test_dir)}/07_InstallCACerts.rb", "08_foss.rb"]
        end

        it "correctly orders files in a directory" do
          arg = "#{test_dir}"
          expect(parser.file_list(parser.split_arg(arg))).to be === ["#{File.expand_path(test_dir)}/00_EnvSetup.rb", "#{File.expand_path(test_dir)}/01_TestSetup.rb", "#{File.expand_path(test_dir)}/02_PuppetUserAndGroup.rb", "#{File.expand_path(test_dir)}/035_StopFirewall.rb", "#{File.expand_path(test_dir)}/03_PuppetMasterSanity.rb", "#{File.expand_path(test_dir)}/04_ValidateSignCert.rb", "#{File.expand_path(test_dir)}/05_HieraSetup.rb", "#{File.expand_path(test_dir)}/06_InstallModules.rb", "#{File.expand_path(test_dir)}/07_InstallCACerts.rb"]
        end

        it "when provided two directories orders each directory separately" do
          arg = "#{test_dir}/,#{other_test_dir}/"
          expect(parser.file_list(parser.split_arg(arg))).to be === ["#{File.expand_path(test_dir)}/00_EnvSetup.rb", "#{File.expand_path(test_dir)}/01_TestSetup.rb", "#{File.expand_path(test_dir)}/02_PuppetUserAndGroup.rb", "#{File.expand_path(test_dir)}/035_StopFirewall.rb", "#{File.expand_path(test_dir)}/03_PuppetMasterSanity.rb", "#{File.expand_path(test_dir)}/04_ValidateSignCert.rb", "#{File.expand_path(test_dir)}/05_HieraSetup.rb", "#{File.expand_path(test_dir)}/06_InstallModules.rb", "#{File.expand_path(test_dir)}/07_InstallCACerts.rb", "#{File.expand_path(other_test_dir)}/00_EnvSetup.rb", "#{File.expand_path(other_test_dir)}/01_TestSetup.rb", "#{File.expand_path(other_test_dir)}/02_PuppetUserAndGroup.rb", "#{File.expand_path(other_test_dir)}/035_StopFirewall.rb", "#{File.expand_path(other_test_dir)}/03_PuppetMasterSanity.rb", "#{File.expand_path(other_test_dir)}/04_ValidateSignCert.rb", "#{File.expand_path(other_test_dir)}/05_HieraSetup.rb", "#{File.expand_path(other_test_dir)}/06_InstallModules.rb", "#{File.expand_path(other_test_dir)}/07_InstallCACerts.rb"]
        end

      end

      #test yaml file checking
      it "raises error on improperly formatted yaml file" do
        FakeFS.deactivate!
        expect{parser.check_yaml_file(badyaml_path)}.to raise_error(ArgumentError)
      end
      it "raises an error when a yaml file is missing" do
        FakeFS.deactivate!
        expect{parser.check_yaml_file("not a path")}.to raise_error(ArgumentError)
      end

      it "can correctly combine arguments from different sources" do
        FakeFS.deactivate!
        ENV["BUILD_URL"] = "http://my.build.url/"
        build_url = ENV["BUILD_URL"]
        args = ["-h", hosts_path, "--log-level", "debug", "--type", "git", "--install", "PUPPET/1.0,HIERA/hello"]
        expect(parser.parse_args(args)).to be === {:project=>"Beaker", :department=>"#{ENV['USER']}", :validate=>true, :jenkins_build_url=> "http://my.build.url/", :forge_host=>"vulcan-acceptance.delivery.puppetlabs.net", :log_level=>"debug", :trace_limit=>10, :hosts_file=>hosts_path, :options_file=>nil, :type=>"git", :provision=>true, :preserve_hosts=>'never', :root_keys=>false, :quiet=>false, :xml=>false, :color=>true, :dry_run=>false, :timeout=>300, :fail_mode=>'slow', :timesync=>false, :repo_proxy=>false, :add_el_extras=>false, :add_master_entry=>false, :consoleport=>443, :pe_dir=>"/opt/enterprise/dists", :pe_version_file=>"LATEST", :pe_version_file_win=>"LATEST-win", :dot_fog=>"#{home}/.fog", :help=>false, :ec2_yaml=>"config/image_templates/ec2.yaml", :ssh=>{:config=>false, :paranoid=>false, :timeout=>300, :auth_methods=>["publickey"], :port=>22, :forward_agent=>true, :keys=>["#{home}/.ssh/id_rsa"], :user_known_hosts_file=>"#{home}/.ssh/known_hosts"}, :install=>["git://github.com/puppetlabs/puppet.git#1.0", "git://github.com/puppetlabs/hiera.git#hello"], :HOSTS=>{:"pe-ubuntu-lucid"=>{:roles=>["agent", "dashboard", "database", "master"], :vmname=>"pe-ubuntu-lucid", :platform=>"ubuntu-10.04-i386", :snapshot=>"clean-w-keys", :hypervisor=>"fusion"}, :"pe-centos6"=>{:roles=>["agent"], :vmname=>"pe-centos6", :platform=>"el-6-i386", :hypervisor=>"fusion", :snapshot=>"clean-w-keys"}}, :nfs_server=>"none", :home=>"#{home}", :answers=>{:q_puppet_enterpriseconsole_auth_user_email=>"admin@example.com", :q_puppet_enterpriseconsole_auth_password=>"~!@\#$%^*-/ aZ", :q_puppet_enterpriseconsole_smtp_host=>nil, :q_puppet_enterpriseconsole_smtp_port=>25, :q_puppet_enterpriseconsole_smtp_username=>nil, :q_puppet_enterpriseconsole_smtp_password=>nil, :q_puppet_enterpriseconsole_smtp_use_tls=>"n", :q_verify_packages=>"y", :q_puppetdb_password=>"~!@\#$%^*-/ aZ"}, :helper=>[], :load_path=>[], :tests=>[], :pre_suite=>[], :post_suite=>[], :modules=>[]}
      end

      it "ensures that fail-mode is one of fast/slow" do
        FakeFS.deactivate!
        args = ["-h", hosts_path, "--log-level", "debug", "--fail-mode", "nope"] 
        expect{parser.parse_args(args)}.to raise_error(ArgumentError)
      end

      it "ensures that type is one of pe/git" do
        FakeFS.deactivate!
        args = ["-h", hosts_path, "--log-level", "debug", "--type", "unkowns"]
        expect{parser.parse_args(args)}.to raise_error(ArgumentError)
      end

      describe "normalize_args" do
        let(:hosts) do
          {
            'HOSTS' => {
              :master => {
                :roles => ["master","agent","arbitrary_role"],
              },
              :agent => {
                :roles => ["agent","default","other_abitrary_role"],
              },
            }
          }
        end

        def fake_hosts_file_for_platform(hosts, platform)
          hosts['HOSTS'].values.each { |h| h[:platform] = platform }
          filename = "hosts_file_#{platform}"
          File.open(filename, "w") do |file|
            YAML.dump(hosts, file)
          end
          filename
        end

        shared_examples_for(:a_platform_supporting_only_agents) do |platform,type|
          let(:args) { ["--type", type] }

          it "restricts #{platform} hosts to agent for #{type}" do
            hosts_file = fake_hosts_file_for_platform(hosts, platform)
            args << "--hosts" << hosts_file
            expect { parser.parse_args(args) }.to raise_error(ArgumentError, /#{platform}.*may not have roles 'master', 'dashboard', or 'database'/)
          end
        end

        context "for pe" do
          it_should_behave_like(:a_platform_supporting_only_agents, 'solaris-version-arch', 'pe')
          it_should_behave_like(:a_platform_supporting_only_agents, 'windows-version-arch', 'pe')
          it_should_behave_like(:a_platform_supporting_only_agents, 'el-4-arch', 'pe')
        end

        context "for foss" do
          it_should_behave_like(:a_platform_supporting_only_agents, 'windows-version-arch', 'git')
          it_should_behave_like(:a_platform_supporting_only_agents, 'el-4-arch', 'git')

          it "allows master role for solaris" do
            hosts_file = fake_hosts_file_for_platform(hosts, 'solaris-version-arch')
            args = ["--type", "git", "--hosts", hosts_file]
            options_hash = parser.parse_args(args)
            expect(options_hash[:HOSTS][:master][:platform]).to match(/solaris/)
            expect(options_hash[:HOSTS][:master][:roles]).to include('master')
            expect(options_hash[:type]).to eq('git')
          end
        end
      end
    end
  end
end
