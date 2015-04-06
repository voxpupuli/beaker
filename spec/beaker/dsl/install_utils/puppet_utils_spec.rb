require 'spec_helper'

class ClassMixedWithDSLInstallUtils
  include Beaker::DSL::InstallUtils
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Structure
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns

  def logger
    @logger ||= RSpec::Mocks::Double.new('logger').as_null_object
  end
end

describe ClassMixedWithDSLInstallUtils do
  let(:presets)       { Beaker::Options::Presets.new }
  let(:opts)          { presets.presets.merge(presets.env_vars) }
  let(:basic_hosts)   { make_hosts( { :pe_ver => '3.0',
                                       :platform => 'linux',
                                       :roles => [ 'agent' ] }, 4 ) }
  let(:hosts)         { basic_hosts[0][:roles] = ['master', 'database', 'dashboard']
                        basic_hosts[1][:platform] = 'windows'
                        basic_hosts[2][:platform] = 'osx-10.9-x86_64'
                        basic_hosts[3][:platform] = 'eos'
                        basic_hosts  }
  let(:hosts_sorted)  { [ hosts[1], hosts[0], hosts[2], hosts[3] ] }
  let(:winhost)       { make_host( 'winhost', { :platform => 'windows',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp' } ) }
  let(:machost)       { make_host( 'machost', { :platform => 'osx-10.9-x86_64',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp' } ) }
  let(:unixhost)      { make_host( 'unixhost', { :platform => 'linux',
                                                 :pe_ver => '3.0',
                                                 :working_dir => '/tmp',
                                                 :dist => 'puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386' } ) }
  let(:eoshost)       { make_host( 'eoshost', { :platform => 'eos',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp',
                                                :dist => 'puppet-enterprise-3.7.1-rc0-78-gffc958f-eos-4-i386' } ) }


  context 'extract_repo_info_from' do
    [{ :protocol => 'git', :path => 'git://github.com/puppetlabs/project.git' },
     { :protocol => 'ssh', :path => 'git@github.com:puppetlabs/project.git' },
     { :protocol => 'https', :path => 'https://github.com:puppetlabs/project' },
     { :protocol => 'file', :path => 'file:///home/example/project' }
    ].each do |type|
      it "handles #{ type[:protocol] } uris" do
        uri = "#{ type[:path] }#master"
        repo_info = subject.extract_repo_info_from uri
        expect( repo_info[:name] ).to be == 'project'
        expect( repo_info[:path] ).to be ==  type[:path]
        expect( repo_info[:rev] ).to  be == 'master'
      end
    end
  end

  context 'order_packages' do
    it 'orders facter, hiera before puppet, before anything else' do
      named_repos = [
        { :name => 'puppet_plugin' }, { :name => 'puppet' }, { :name => 'facter' }
      ]
      ordered_repos = subject.order_packages named_repos
      expect( ordered_repos[0][:name] ).to be == 'facter'
      expect( ordered_repos[1][:name] ).to be == 'puppet'
      expect( ordered_repos[2][:name] ).to be == 'puppet_plugin'
    end
  end

  context 'find_git_repo_versions' do
    it 'returns a hash of :name => version' do
      host        = double( 'Host' )
      repository  = { :name => 'name' }
      path        = '/path/to/repo'
      cmd         = 'cd /path/to/repo/name && git describe || true'
      logger = double.as_null_object

      expect( subject ).to receive( :logger ).and_return( logger )
      expect( subject ).to receive( :on ).with( host, cmd ).and_yield
      expect( subject ).to receive( :stdout ).and_return( '2' )

      version = subject.find_git_repo_versions( host, path, repository )

      expect( version ).to be == { 'name' => '2' }
    end
  end

  context 'install_from_git' do
    it 'does a ton of stuff it probably shouldnt' do
      repo = { :name => 'puppet',
               :path => 'git://my.server.net/puppet.git',
               :rev => 'master' }
      path = '/path/to/repos'
      host = { 'platform' => 'debian' }
      logger = double.as_null_object

      expect( subject ).to receive( :logger ).exactly( 3 ).times.and_return( logger )
      expect( subject ).to receive( :on ).exactly( 4 ).times

      subject.install_from_git( host, path, repo )
    end

    it 'allows a checkout depth of 1' do
      repo   = { :name => 'puppet',
                 :path => 'git://my.server.net/puppet.git',
                 :rev => 'master',
                 :depth => 1 }

      path   = '/path/to/repos'
      cmd    = "test -d #{path}/#{repo[:name]} || git clone --branch #{repo[:rev]} --depth #{repo[:depth]} #{repo[:path]} #{path}/#{repo[:name]}"
      host   = { 'platform' => 'debian' }
      logger = double.as_null_object
      expect( subject ).to receive( :logger ).exactly( 3 ).times.and_return( logger )
      expect( subject ).to receive( :on ).with( host,"test -d #{path} || mkdir -p #{path}").exactly( 1 ).times
      # this is the the command we want to test
      expect( subject ).to receive( :on ).with( host, cmd ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, "cd #{path}/#{repo[:name]} && git remote rm origin && git remote add origin #{repo[:path]} && git fetch origin +refs/pull/*:refs/remotes/origin/pr/* +refs/heads/*:refs/remotes/origin/* && git clean -fdx && git checkout -f #{repo[:rev]}" ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, "cd #{path}/#{repo[:name]} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi" ).exactly( 1 ).times

      subject.install_from_git( host, path, repo )
    end

    it 'allows a checkout depth with a rev from a specific branch' do
      repo   = { :name => 'puppet',
                 :path => 'git://my.server.net/puppet.git',
                 :rev => 'a2340acddadfeafd234230faf',
                 :depth => 50,
                 :depth_branch => 'master' }

      path   = '/path/to/repos'
      cmd    = "test -d #{path}/#{repo[:name]} || git clone --branch #{repo[:depth_branch]} --depth #{repo[:depth]} #{repo[:path]} #{path}/#{repo[:name]}"
      host   = { 'platform' => 'debian' }
      logger = double.as_null_object
      expect( subject ).to receive( :logger ).exactly( 3 ).times.and_return( logger )
      expect( subject ).to receive( :on ).with( host,"test -d #{path} || mkdir -p #{path}").exactly( 1 ).times
      # this is the the command we want to test
      expect( subject ).to receive( :on ).with( host, cmd ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, "cd #{path}/#{repo[:name]} && git remote rm origin && git remote add origin #{repo[:path]} && git fetch origin +refs/pull/*:refs/remotes/origin/pr/* +refs/heads/*:refs/remotes/origin/* && git clean -fdx && git checkout -f #{repo[:rev]}" ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, "cd #{path}/#{repo[:name]} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi" ).exactly( 1 ).times

      subject.install_from_git( host, path, repo )
    end
   end

  describe '#install_puppet' do
    let(:hosts) do
      make_hosts({:platform => platform })
    end

    before do
      allow( subject ).to receive(:hosts).and_return(hosts)
      allow( subject ).to receive(:on).and_return(Beaker::Result.new({},''))
    end
    context 'on el-6' do
      let(:platform) { "el-6-i386" }
      it 'installs' do
        expect(subject).to receive(:on).with(hosts[0], /puppetlabs-release-el-6\.noarch\.rpm/)
        expect(subject).to receive(:on).with(hosts[0], 'yum install -y puppet')
        subject.install_puppet
      end
      it 'installs specific version of puppet when passed :version' do
        expect(subject).to receive(:on).with(hosts[0], 'yum install -y puppet-3000')
        subject.install_puppet( :version => '3000' )
      end
      it 'can install specific versions of puppets dependencies' do
        expect(subject).to receive(:on).with(hosts[0], 'yum install -y puppet-3000')
        expect(subject).to receive(:on).with(hosts[0], 'yum install -y hiera-2001')
        expect(subject).to receive(:on).with(hosts[0], 'yum install -y facter-1999')
        subject.install_puppet( :version => '3000', :facter_version => '1999', :hiera_version => '2001' )
      end
    end
    context 'on el-5' do
      let(:platform) { "el-5-i386" }
      it 'installs' do
        expect(subject).to receive(:on).with(hosts[0], /puppetlabs-release-el-5\.noarch\.rpm/)
        expect(subject).to receive(:on).with(hosts[0], 'yum install -y puppet')
        subject.install_puppet
      end
    end
    context 'on fedora' do
      let(:platform) { "fedora-18-x86_84" }
      it 'installs' do
        expect(subject).to receive(:on).with(hosts[0], /puppetlabs-release-fedora-18\.noarch\.rpm/)
        expect(subject).to receive(:on).with(hosts[0], 'yum install -y puppet')
        subject.install_puppet
      end
    end
    context 'on debian' do
      let(:platform) { "debian-7-amd64" }
      it 'installs latest if given no version info' do
        expect(subject).to receive(:on).with(hosts[0], /puppetlabs-release-\$\(lsb_release -c -s\)\.deb/)
        expect(subject).to receive(:on).with(hosts[0], 'dpkg -i puppetlabs-release-$(lsb_release -c -s).deb')
        expect(subject).to receive(:on).with(hosts[0], 'apt-get update')
        expect(subject).to receive(:on).with(hosts[0], 'apt-get install -y puppet')
        subject.install_puppet
      end
      it 'installs specific version of puppet when passed :version' do
        expect(subject).to receive(:on).with(hosts[0], 'apt-get install -y puppet=3000-1puppetlabs1')
        subject.install_puppet( :version => '3000' )
      end
      it 'can install specific versions of puppets dependencies' do
        expect(subject).to receive(:on).with(hosts[0], 'apt-get install -y puppet=3000-1puppetlabs1')
        expect(subject).to receive(:on).with(hosts[0], 'apt-get install -y hiera=2001-1puppetlabs1')
        expect(subject).to receive(:on).with(hosts[0], 'apt-get install -y facter=1999-1puppetlabs1')
        subject.install_puppet( :version => '3000', :facter_version => '1999', :hiera_version => '2001' )
      end
    end
    context 'on windows' do
      let(:platform) { "windows-2008r2-i386" }
      it 'installs specific version of puppet when passed :version' do
        allow(subject).to receive(:link_exists?).and_return( true )
        expect(subject).to receive(:on).with(hosts[0], 'curl -O http://downloads.puppetlabs.com/windows/puppet-3000.msi')
        expect(subject).to receive(:on).with(hosts[0], " echo 'export PATH=$PATH:\"/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin\":\"/cygdrive/c/Program Files/Puppet Labs/Puppet/bin\"' > /etc/bash.bashrc ")
        expect(subject).to receive(:on).with(hosts[0], 'cmd /C \'start /w msiexec.exe /qn /i puppet-3000.msi\'')
        subject.install_puppet(:version => '3000')
      end
      it 'installs from custom url when passed :win_download_url' do
        allow(subject).to receive(:link_exists?).and_return( true )
        expect(subject).to receive(:on).with(hosts[0], 'curl -O http://nightlies.puppetlabs.com/puppet-latest/repos/windows/puppet-3000.msi')
        expect(subject).to receive(:on).with(hosts[0], 'cmd /C \'start /w msiexec.exe /qn /i puppet-3000.msi\'')
        subject.install_puppet( :version => '3000', :win_download_url => 'http://nightlies.puppetlabs.com/puppet-latest/repos/windows' )
      end
    end
    describe 'on unsupported platforms' do
      let(:platform) { 'solaris-11-x86_64' }
      let(:host) { make_host('henry', :platform => 'solaris-11-x86_64') }
      let(:hosts) { [host] }
      it 'by default raises an error' do
        expect(subject).to_not receive(:on)
        expect { subject.install_puppet }.to raise_error(/unsupported platform/)
      end
      it 'falls back to installing from gem when given :default_action => "gem_install"' do
        result = double
        gem_env_string = '{"RubyGems Environment": [ {"GEM PATHS": [], "EXECUTABLE DIRECTORY": "/does/not/exist" } ] }'
        allow( result ).to receive(:stdout).and_return gem_env_string
        allow(subject).to receive(:on).with(host, /gem environment/).and_return result
        expect(subject).to receive(:on).with(host, /gem install/)
        subject.install_puppet :default_action => 'gem_install'
      end
    end
  end

  describe 'configure_puppet_on' do
    before do
      allow(subject).to receive(:on).and_return(Beaker::Result.new({},''))
    end
    context 'on debian' do
      let(:platform) { 'debian-7-amd64' }
      let(:host) { make_host('testbox.test.local', :platform => 'debian-7-amd64') }
      it 'it sets the puppet.conf file to the provided config' do
        config = { 'main' => {'server' => 'testbox.test.local'} }
        expect(subject).to receive(:on).with(host, "echo \"[main]\nserver=testbox.test.local\n\n\" > #{host.puppet['config']}")
        subject.configure_puppet_on(host, config)
      end
    end
    context 'on windows' do
      let(:platform) { 'windows-2008R2-amd64' }
      let(:host) { make_host('testbox.test.local', :platform => 'windows-2008R2-amd64') }
      it 'it sets the puppet.conf file to the provided config' do
        config = { 'main' => {'server' => 'testbox.test.local'} }
        expect(subject).to receive(:on) do |host, command|
          expect(command.command).to eq('powershell.exe')
          expect(command.args).to eq(["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command $text = \\\"[main]`nserver=testbox.test.local`n`n\\\"; Set-Content -path '#{host.puppet['config']}' -value $text"])
        end
        subject.configure_puppet_on(host, config)
      end
    end
  end

  describe 'configure_puppet' do
    let(:hosts) do
      make_hosts({:platform => platform })
    end

    before do
      allow( subject ).to receive(:hosts).and_return(hosts)
      allow( subject ).to receive(:on).and_return(Beaker::Result.new({},''))
    end
    context 'on debian' do
      let(:platform) { 'debian-7-amd64' }
      it 'it sets the puppet.conf file to the provided config' do
        config = { 'main' => {'server' => 'testbox.test.local'} }
        expect(subject).to receive(:on).with(hosts[0], "echo \"[main]\nserver=testbox.test.local\n\n\" > #{hosts[0].puppet['config']}")
        subject.configure_puppet(config)
      end
    end
    context 'on windows' do
      let(:platform) { 'windows-2008R2-amd64' }
      it 'it sets the puppet.conf file to the provided config' do
        config = { 'main' => {'server' => 'testbox.test.local'} }
        expect(subject).to receive(:on) do |host, command|
          expect(command.command).to eq('powershell.exe')
          expect(command.args).to eq(["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command $text = \\\"[main]`nserver=testbox.test.local`n`n\\\"; Set-Content -path '#{host.puppet['config']}' -value $text"])
        end
        subject.configure_puppet(config)
      end
    end
  end

  describe "#install_puppetlabs_release_repo" do
    let( :platform ) { Beaker::Platform.new('solaris-7-i386') }
    let( :host ) do
      FakeHost.create('fakevm', platform.to_s)
    end

    before do
      allow(subject).to receive(:options) { opts }
    end

    describe "When host is unsupported platform" do
      let( :platform ) { Beaker::Platform.new('solaris-7-i386') }

      it "raises an exception." do
        expect{
          subject.install_puppetlabs_release_repo host
        }.to raise_error(RuntimeError, /No repository installation step for/)
      end
    end

    describe "When host is a debian-like platform" do
      let( :platform ) { Beaker::Platform.new('debian-7-i386') }

      it "downloads a deb file, installs, and updates the apt cache." do
        expect(subject).to receive(:on).with( host, /wget .*/ ).ordered
        expect(subject).to receive(:on).with( host, /dpkg .*/ ).ordered
        expect(subject).to receive(:on).with( host, "apt-get update" ).ordered
        subject.install_puppetlabs_release_repo host
      end

    end

    describe "When host is a redhat-like platform" do
      let( :platform ) { Beaker::Platform.new('el-7-i386') }

      it "installs an rpm" do
        expect(subject).to receive(:on).with( host, /rpm .*/ ).ordered
        subject.install_puppetlabs_release_repo host
      end

    end

  end

  RSpec.shared_examples "install-dev-repo" do

    it "scp's files to SUT then modifies them with find-and-sed 2-hit combo" do
      allow(rez).to receive(:exit_code) { 0 }
      allow(subject).to receive(:link_exists?).and_return(true)
      expect(subject).to receive(:on).with( host, /^mkdir -p .*$/ ).ordered
      expect(subject).to receive(:scp_to).with( host, repo_config, /.*/ ).ordered
      expect(subject).to receive(:scp_to).with( host, repo_dir, /.*/ ).ordered
      expect(subject).to receive(:on).with( host, /^find .* sed .*/ ).ordered
      subject.install_puppetlabs_dev_repo host, package_name, package_version
    end

  end

  describe "#install_puppetlabs_dev_repo" do
    let( :package_name ) { "puppet" }
    let( :package_version ) { "7.5.6" }
    let( :host ) do
      FakeHost.create('fakvm', platform.to_s, opts)
    end

    describe "When host is unsupported platform" do
      let( :platform ) { Beaker::Platform.new('solaris-7-i386') }

      it "raises an exception." do
        expect(subject).to receive(:on).with( host, /^mkdir -p .*$/ ).ordered
        allow(subject).to receive(:options) { opts }
        expect{
          subject.install_puppetlabs_dev_repo host, package_name, package_version
        }.to raise_error(RuntimeError, /No repository installation step for/)
      end
    end

    describe 'When on supported platforms' do
      # These are not factored into the `before` block above because they
      # are expectations in the share examples, but aren't interesting
      # beyond those basic tests
      def stub_uninteresting_portions_of_install_puppetlabs_dev_repo!
        allow(subject).to receive(:on).with( host, /^mkdir -p .*$/ ).ordered
        allow(subject).to receive(:scp_to).with( host, repo_config, /.*/ ).ordered
        allow(subject).to receive(:scp_to).with( host, repo_dir, /.*/ ).ordered
      end

      let( :repo_config ) { "repoconfig" }
      let( :repo_dir ) { "repodir" }
      let( :rez ) { double }

      before do
        allow(subject).to receive(:fetch_http_file) { repo_config }
        allow(subject).to receive(:fetch_http_dir) { repo_dir }
        allow(subject).to receive(:on).with(host, "apt-get update") { }
        allow(subject).to receive(:options) { opts }
        allow(subject).to receive(:on).with( host, /^.* -d .*/, {:acceptable_exit_codes =>[0,1]} ).and_return(rez)
      end

      describe "that are debian-like" do
        let( :platform ) { Beaker::Platform.new('debian-7-i386') }
        before { allow(subject).to receive(:link_exists?).and_return(true) }

        include_examples "install-dev-repo"

        it 'sets up the PC1 repository if that was downloaded' do
          allow(rez).to receive(:exit_code) { 0 }

          stub_uninteresting_portions_of_install_puppetlabs_dev_repo!

          expect(subject).to receive(:on).with( host, /^find .* sed .*PC1.*/ )
          subject.install_puppetlabs_dev_repo host, package_name, package_version
        end

        it 'sets up the main repository if that was downloaded' do
          allow(rez).to receive(:exit_code) { 1 }

          stub_uninteresting_portions_of_install_puppetlabs_dev_repo!

          expect(subject).to receive(:on).with( host, /^find .* sed .*main.*/ )
          subject.install_puppetlabs_dev_repo host, package_name, package_version
        end

      end

      describe "that are redhat-like" do
        let( :platform ) { Beaker::Platform.new('el-7-i386') }
        include_examples "install-dev-repo"

        it 'downloads PC1, products, or devel repo -- in that order' do
          allow(subject).to receive(:on).with( host, /^find .* sed .*/ )
          stub_uninteresting_portions_of_install_puppetlabs_dev_repo!

          expect(subject).to receive(:link_exists?).with(/.*PC1.*/).and_return( false )
          expect(subject).to receive(:link_exists?).with(/.*products.*/).and_return( false )
          expect(subject).to receive(:link_exists?).with(/.*devel.*/).and_return( true )

          subject.install_puppetlabs_dev_repo host, package_name, package_version
        end
      end
    end
  end

  describe '#install_packages_from_local_dev_repo' do
    let( :package_name ) { 'puppet-agent' }
    let( :platform ) { @platform || 'other' }
    let( :host ) do
      FakeHost.create('fakvm', platform, opts)
    end

    it 'sets the find command correctly for el-based systems' do
      @platform = 'el-1-3'
      expect( subject ).to receive( :on ).with( host, /\*\.rpm.+rpm\s-ivh/ )
      subject.install_packages_from_local_dev_repo( host, package_name )
    end

    it 'sets the find command correctly for debian-based systems' do
      @platform = 'debian-1-3'
      expect( subject ).to receive( :on ).with( host, /\*\.deb.+dpkg\s-i/ )
      subject.install_packages_from_local_dev_repo( host, package_name )
    end

    it 'fails correctly for systems not accounted for' do
      @platform = 'eos-1-3'
      expect{ subject.install_packages_from_local_dev_repo( host, package_name ) }.to raise_error RuntimeError
    end

  end

  describe '#install_puppetagent_dev_repo' do

    it 'raises an exception when host platform is unsupported' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['ptan', '5', 'x4']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }
      allow( subject ).to receive( :options ).and_return( {} )

      expect{
        subject.install_puppetagent_dev_repo( host, opts )
      }.to raise_error(RuntimeError, /No repository installation step for/)
    end

    it 'runs the correct install for el-based platforms' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['el', '5', 'x4']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }
      allow( subject ).to receive( :options ).and_return( {} )

      expect(subject).to receive(:fetch_http_file).once.with(/\/el\//, /-agent-/, /el/)
      expect(subject).to receive(:scp_to).once.with(host, /-agent-/, "/root")
      expect(subject).to receive(:on).once.with(host, /rpm\ -ivh/)

      subject.install_puppetagent_dev_repo( host, opts )
    end

    it 'runs the correct install for debian-based platforms' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['debian', '5', 'x4']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }
      allow( subject ).to receive( :options ).and_return( {} )

      expect(subject).to receive(:fetch_http_file).once.with(/\/deb\//, /-agent_/, /deb/)
      expect(subject).to receive(:scp_to).once.with(host, /-agent_/, "/root")
      expect(subject).to receive(:on).ordered.with(host, /dpkg\ -i\ --force-all/)
      expect(subject).to receive(:on).ordered.with(host, /apt-get\ update/)

      subject.install_puppetagent_dev_repo( host, opts )
    end

    it 'runs the correct install for windows platforms' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['windows', '5', 'x64']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }
      allow( subject ).to receive( :options ).and_return( {} )
      mock_echo = Object.new()
      allow( mock_echo ).to receive( :raw_output ).and_return( " " )

      expect(subject).to receive(:fetch_http_file).once.with(/\/windows$/, 'puppet-agent-x64.msi', /\/windows$/)
      expect(subject).to receive(:scp_to).once.with(host, /\/puppet-agent-x64.msi$/, /cygpath/)
      expect(subject).to receive(:on).ordered.with(host, /echo/).and_return(mock_echo)
      expect(subject).to receive(:on).ordered.with(host, anything)

      subject.install_puppetagent_dev_repo( host, opts )
    end

    it 'allows you to override the local copy directory' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['debian', '5', 'x4']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0', :copy_base_local => 'face' }
      allow( subject ).to receive( :options ).and_return( {} )

      expect(subject).to receive(:fetch_http_file).once.with(/\/deb\//, /-agent_/, /face/)
      expect(subject).to receive(:scp_to).once.with(host, /face/, "/root")
      expect(subject).to receive(:on).ordered.with(host, /dpkg\ -i\ --force-all/)
      expect(subject).to receive(:on).ordered.with(host, /apt-get\ update/)

      subject.install_puppetagent_dev_repo( host, opts )
    end

    it 'allows you to override the external copy directory' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['debian', '5', 'x4']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0', :copy_dir_external => 'muppetsB' }
      allow( subject ).to receive( :options ).and_return( {} )

      expect(subject).to receive(:fetch_http_file).once.with(/\/deb\//, /-agent_/, /deb/)
      expect(subject).to receive(:scp_to).once.with(host, /-agent_/, /muppetsB/)
      expect(subject).to receive(:on).ordered.with(host, /dpkg\ -i\ --force-all/)
      expect(subject).to receive(:on).ordered.with(host, /apt-get\ update/)

      subject.install_puppetagent_dev_repo( host, opts )
    end
  end

  describe '#install_cert_on_windows' do
    before do
      subject.stub(:on).and_return(Beaker::Result.new({},''))
    end

    context 'on windows' do
      let(:platform) { 'windows-2008R2-amd64' }
      let(:host) { make_host('testbox.test.local', :platform => 'windows-2008R2-amd64') }

      it 'should install all 3 certs' do
        cert = 'geotrust_global_ca'
        content = <<-EOM
        -----BEGIN CERTIFICATE-----
        MIIDVDCCAjygAwIBAgIDAjRWMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT
        MRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i
        YWwgQ0EwHhcNMDIwNTIxMDQwMDAwWhcNMjIwNTIxMDQwMDAwWjBCMQswCQYDVQQG
        EwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UEAxMSR2VvVHJ1c3Qg
        R2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2swYYzD9
        9BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9mOSm9BXiLnTjoBbdq
        fnGk5sRgprDvgOSJKA+eJdbtg/OtppHHmMlCGDUUna2YRpIuT8rxh0PBFpVXLVDv
        iS2Aelet8u5fa9IAjbkU+BQVNdnARqN7csiRv8lVK83Qlz6cJmTM386DGXHKTubU
        1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmRCw7+OC7RHQWa9k0+
        bw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5aszPeE4uwc2hGKceeoW
        MPRfwCvocWvk+QIDAQABo1MwUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTA
        ephojYn7qwVkDBF9qn1luMrMTjAfBgNVHSMEGDAWgBTAephojYn7qwVkDBF9qn1l
        uMrMTjANBgkqhkiG9w0BAQUFAAOCAQEANeMpauUvXVSOKVCUn5kaFOSPeCpilKIn
        Z57QzxpeR+nBsqTP3UEaBU6bS+5Kb1VSsyShNwrrZHYqLizz/Tt1kL/6cdjHPTfS
        tQWVYrmm3ok9Nns4d0iXrKYgjy6myQzCsplFAMfOEVEiIuCl6rYVSAlk6l5PdPcF
        PseKUgzbFbS9bZvlxrFUaKnjaZC2mqUPuLk/IH2uSrW4nOQdtqvmlKXBx4Ot2/Un
        hw4EbNX/3aBd7YdStysVAq45pmp06drE57xNNB6pXE0zX5IJL4hmXXeXxx12E6nV
        5fEWCRE11azbJHFwLJhWC9kXtNHjUStedejV0NxPNO3CBWaAocvmMw==
        -----END CERTIFICATE-----
        EOM
        
        expect(subject).to receive(:create_remote_file) do |host, file_path, file_content|
          expect(file_path).to eq("C:\\Windows\\Temp\\#{cert}.pem")
        end

        expect(subject).to receive(:on) do |host, command|
          expect(command).to eq("certutil -v -addstore Root C:\\Windows\\Temp\\#{cert}.pem")
        end

        subject.install_cert_on_windows(host, cert, content)
      end
    end
  end
end
