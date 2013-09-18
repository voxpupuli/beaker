require "spec_helper"

module Beaker
  module Options

    describe Parser do
      let(:parser)    { Parser.new }
      let(:opts_path) { File.join(File.expand_path(File.dirname(__FILE__)), "data", "opts.txt") }
      let(:hosts_path)  { File.join(File.expand_path(File.dirname(__FILE__)), "data", "hosts.cfg") }
      let(:badyaml_path)  { File.join(File.expand_path(File.dirname(__FILE__)), "data", "badyaml.cfg") }
      let(:home) {ENV['HOME']}

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
        args = ["-h", hosts_path, "--debug", "--type", "git", "--install", "PUPPET/1.0,HIERA/hello"]
        expect(parser.parse_args(args)).to be === {:hosts_file=>"/Users/anode/beaker/spec/beaker/options/data/hosts.cfg", :options_file=>nil, :type=>"git", :provision=>true, :preserve_hosts=>false, :root_keys=>false, :quiet=>false, :xml=>false, :color=>true, :debug=>true, :dry_run=>false, :fail_mode=>nil, :timesync=>false, :repo_proxy=>false, :add_el_extras=>false, :consoleport=>443, :pe_dir=>"/opt/enterprise/dists", :pe_version_file=>"LATEST", :pe_version_file_win=>"LATEST-win", :dot_fog=>"/Users/anode/.fog", :ec2_yaml=>"config/image_templates/ec2.yaml", :ssh=>{:config=>false, :paranoid=>false, :timeout=>300, :auth_methods=>["publickey"], :port=>22, :forward_agent=>true, :keys=>["/Users/anode/.ssh/id_rsa"], :user_known_hosts_file=>"/Users/anode/.ssh/known_hosts"}, :install=>["git://github.com/puppetlabs/puppet.git#1.0", "git://github.com/puppetlabs/hiera.git#hello"], :HOSTS=>{:"pe-ubuntu-lucid"=>{:roles=>["agent", "dashboard", "database", "master"], :vmname=>"pe-ubuntu-lucid", :platform=>"ubuntu-10.04-i386", :snapshot=>"clean-w-keys", :hypervisor=>"fusion"}, :"pe-centos6"=>{:roles=>["agent"], :vmname=>"pe-centos6", :platform=>"el-6-i386", :hypervisor=>"fusion", :snapshot=>"clean-w-keys"}}, :nfs_server=>"none", :helper=>[], :load_path=>[], :tests=>[], :pre_suite=>[], :post_suite=>[], :modules=>[]}
      end

      it "ensures that file-mode is one of fast/stop" do
        FakeFS.deactivate!
        args = ["-h", hosts_path, "--debug", "--fail-mode", "slow"] 
        expect{parser.parse_args(args)}.to raise_error(ArgumentError)
      end

      it "ensures that type is one of pe/git" do
        FakeFS.deactivate!
        args = ["-h", hosts_path, "--debug", "--type", "unkowns"]
        expect{parser.parse_args(args)}.to raise_error(ArgumentError)
      end

    end
  end
end
