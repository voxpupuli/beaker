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
  let(:metadata)      { @metadata ||= {} }
  let(:presets)       { Beaker::Options::Presets.new }
  let(:opts)          { presets.presets.merge(presets.env_vars).merge({ :type => 'foss' }) }
  let(:basic_hosts)   { make_hosts( { :pe_ver => '3.0',
                                      :platform => 'linux',
                                      :roles => [ 'agent' ],
                                      :type  => 'foss' }, 4 ) }
  let(:hosts)         { basic_hosts[0][:roles] = ['master', 'database', 'dashboard']
                        basic_hosts[1][:platform] = 'windows'
                        basic_hosts[2][:platform] = 'osx-10.9-x86_64'
                        basic_hosts[3][:platform] = 'eos'
                        basic_hosts  }
  let(:hosts_sorted)  { [ hosts[1], hosts[0], hosts[2], hosts[3] ] }
  let(:winhost)       { make_host( 'winhost', { :platform => 'windows',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp',
                                                :type => 'foss',
                                                :is_cygwin => true} ) }
  let(:winhost_non_cygwin) { make_host( 'winhost_non_cygwin', { :platform => 'windows',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp',
                                                :type => 'foss',
                                                :is_cygwin => 'false' } ) }
  let(:machost)       { make_host( 'machost', { :platform => 'osx-10.9-x86_64',
                                                :pe_ver => '3.0',
                                                :type => 'foss',
                                                :working_dir => '/tmp' } ) }
  let(:freebsdhost9)   { make_host( 'freebsdhost9', { :platform => 'freebsd-9-x64',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp' } ) }
  let(:freebsdhost10)   { make_host( 'freebsdhost10', { :platform => 'freebsd-10-x64',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp' } ) }
  let(:unixhost)      { make_host( 'unixhost', { :platform => 'linux',
                                                 :pe_ver => '3.0',
                                                 :working_dir => '/tmp',
                                                :type => 'foss',
                                                 :dist => 'puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386' } ) }
  let(:eoshost)       { make_host( 'eoshost', { :platform => 'eos',
                                                :pe_ver => '3.0',
                                                :working_dir => '/tmp',
                                                :type => 'foss',
                                                :dist => 'puppet-enterprise-3.7.1-rc0-78-gffc958f-eos-4-i386' } ) }
  let(:win_temp)      { 'C:\\Windows\\Temp' }


  context '#configure_foss_defaults_on' do
    it 'uses aio paths for hosts with role aio' do
      hosts.each do |host|
        host[:pe_ver] = nil
        host[:version] = nil
        host[:roles] = host[:roles] | ['aio']
      end
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_foss_defaults_on( hosts )
    end

    it 'uses no paths for hosts with no type' do
      hosts.each do |host|
        host[:type] = nil
      end
      expect(subject).to receive(:add_aio_defaults_on).never
      expect(subject).to receive(:add_foss_defaults_on).never
      expect(subject).to receive(:add_puppet_paths_on).never

      subject.configure_foss_defaults_on( hosts )
    end

    it 'uses aio paths for hosts with aio type (backwards compatability)' do
      hosts.each do |host|
        host[:type] = 'aio'
      end
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_foss_defaults_on).never
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_foss_defaults_on( hosts )
    end

    it 'uses aio paths for hosts of version >= 4.0' do
      hosts.each do |host|
        host[:version] = '4.0'
        host[:pe_ver] = nil
        host[:roles] = host[:roles] - ['aio']
      end
      expect(subject).to receive(:add_aio_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_foss_defaults_on( hosts )
    end

    it 'uses foss paths for hosts of version < 4.0' do
      hosts.each do |host|
        host[:version] = '3.8'
        host[:pe_ver] = nil
      end
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).never
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_foss_defaults_on( hosts )
    end

    it 'uses foss paths for foss-like type foss-package' do
      hosts.each do |host|
        host[:type] = 'foss-package'
        host[:version] = '3.8'
        host[:pe_ver] = nil
      end
      expect(subject).to receive(:add_foss_defaults_on).exactly(hosts.length).times
      expect(subject).to receive(:add_aio_defaults_on).never
      expect(subject).to receive(:add_puppet_paths_on).exactly(hosts.length).times

      subject.configure_foss_defaults_on( hosts )
    end

  end

  context 'lookup_in_env' do
    it 'returns a default properly' do
      env_var = subject.lookup_in_env('noway', 'nonesuch', 'returnme')
      expect(env_var).to be == 'returnme'
      env_var = subject.lookup_in_env('noway', nil, 'returnme')
      expect(env_var).to be == 'returnme'
    end
    it 'finds correct env variable' do
      allow(ENV).to receive(:[]).with(nil).and_return(nil)
      allow(ENV).to receive(:[]).with('REALLYNONE').and_return(nil)
      allow(ENV).to receive(:[]).with('NONESUCH').and_return('present')
      allow(ENV).to receive(:[]).with('NOWAY_PROJ_NONESUCH').and_return('exists')
      env_var = subject.lookup_in_env('nonesuch', 'noway-proj', 'fail')
      expect(env_var).to be == 'exists'
      env_var = subject.lookup_in_env('nonesuch')
      expect(env_var).to be == 'present'
      env_var = subject.lookup_in_env('reallynone')
      expect(env_var).to be == nil
      env_var = subject.lookup_in_env('reallynone',nil,'default')
      expect(env_var).to be == 'default'
    end
  end

  context 'build_giturl' do
    it 'returns urls properly' do
      allow(ENV).to receive(:[]).with('SERVER').and_return(nil)
      allow(ENV).to receive(:[]).with('FORK').and_return(nil)
      allow(ENV).to receive(:[]).with('PUPPET_FORK').and_return(nil)
      allow(ENV).to receive(:[]).with('PUPPET_SERVER').and_return(nil)
      url = subject.build_giturl('puppet')
      expect(url).to be == 'https://github.com/puppetlabs/puppet.git'
      url = subject.build_giturl('puppet', 'er0ck')
      expect(url).to be == 'https://github.com/er0ck/puppet.git'
      url = subject.build_giturl('puppet', 'er0ck', 'bitbucket.com')
      expect(url).to be == 'https://bitbucket.com/er0ck-puppet.git'
      url = subject.build_giturl('puppet', 'er0ck', 'github.com', 'https://')
      expect(url).to be == 'https://github.com/er0ck/puppet.git'
      url = subject.build_giturl('puppet', 'er0ck', 'github.com', 'https')
      expect(url).to be == 'https://github.com/er0ck/puppet.git'
      url = subject.build_giturl('puppet', 'er0ck', 'github.com', 'git@')
      expect(url).to be == 'git@github.com:er0ck/puppet.git'
      url = subject.build_giturl('puppet', 'er0ck', 'github.com', 'git')
      expect(url).to be == 'git@github.com:er0ck/puppet.git'
      url = subject.build_giturl('puppet', 'er0ck', 'github.com', 'ssh')
      expect(url).to be == 'git@github.com:er0ck/puppet.git'
    end
  end

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

      allow( subject ).to receive( :metadata ).and_return( metadata )
      expect( subject ).to receive( :logger ).and_return( logger )
      expect( subject ).to receive( :on ).with( host, cmd ).and_yield
      expect( subject ).to receive( :stdout ).and_return( '2' )

      subject.instance_variable_set( :@metadata, {} )
      version = subject.find_git_repo_versions( host, path, repository )

      expect( version ).to be == { 'name' => '2' }
    end
  end

  context 'install_puppet_from_freebsd_ports_on' do
    it 'installs puppet on FreeBSD 9' do
      expect(freebsdhost9).to receive(:install_package).with('puppet')

      subject.install_puppet_from_freebsd_ports_on( freebsdhost9, {}  )
    end

    it 'installs puppet on FreeBSD 10' do
      expect(freebsdhost10).to receive(:install_package).with('sysutils/puppet')

      subject.install_puppet_from_freebsd_ports_on( freebsdhost10, {}  )
    end
  end

  context 'install_puppet_from_msi' do
    before :each do
      expect(subject).to receive(:get_temp_path).and_return(win_temp)
    end

    it 'installs puppet on cygwin windows' do
      allow(subject).to receive(:link_exists?).and_return( true )
      expect(subject).to receive(:on).with(winhost, "curl -o \"#{win_temp}\\puppet-3.7.1.msi\" -O http://downloads.puppetlabs.com/windows/puppet-3.7.1.msi")
      expect(subject).to receive(:on).with(winhost, " echo 'export PATH=$PATH:\"/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin\":\"/cygdrive/c/Program Files/Puppet Labs/Puppet/bin\"' > /etc/bash.bashrc ")
      expect(subject).to receive(:install_msi_on).with(winhost, "#{win_temp}\\puppet-3.7.1.msi", {}, {:debug => nil})

      subject.install_puppet_from_msi( winhost, {:version => '3.7.1', :win_download_url => 'http://downloads.puppetlabs.com/windows'}  )
    end

    it 'installs puppet on non-cygwin windows' do
      allow(subject).to receive(:link_exists?).and_return( true )

      expect(winhost_non_cygwin).to receive(:mkdir_p).with('C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules')

      expect(subject).to receive(:on).with(winhost_non_cygwin, instance_of( Beaker::Command )) do |host, beaker_command|
        expect(beaker_command.command).to eq('powershell.exe')
        expect(beaker_command.args).to eq(["-ExecutionPolicy Bypass", "-InputFormat None", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command $webclient = New-Object System.Net.WebClient;  $webclient.DownloadFile('http://downloads.puppetlabs.com/windows/puppet-3.7.1.msi','#{win_temp}\\puppet-3.7.1.msi')"])
      end.once

      expect(subject).to receive(:install_msi_on).with(winhost_non_cygwin, "#{win_temp}\\puppet-3.7.1.msi", {}, {:debug => nil})

      subject.install_puppet_from_msi( winhost_non_cygwin, {:version => '3.7.1', :win_download_url => 'http://downloads.puppetlabs.com/windows'}   )
    end
  end

  context 'clone_git_repo_on' do
    it 'does a ton of stuff it probably shouldnt' do
      repo = { :name => 'puppet',
               :path => 'git://my.server.net/puppet.git',
               :rev => 'master' }
      path = '/path/to/repos'
      host = { 'platform' => 'debian' }
      logger = double.as_null_object

      allow( subject ).to receive( :metadata ).and_return( metadata )
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )

      expect( subject ).to receive( :logger ).exactly( 2 ).times.and_return( logger )
      expect( subject ).to receive( :on ).exactly( 3 ).times

      subject.instance_variable_set( :@metadata, {} )
      subject.clone_git_repo_on( host, path, repo )
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
      allow( subject ).to receive( :metadata ).and_return( metadata )
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )
      expect( subject ).to receive( :logger ).exactly( 2 ).times.and_return( logger )
      expect( subject ).to receive( :on ).with( host, "test -d #{path} || mkdir -p #{path}", {:accept_all_exit_codes=>true} ).exactly( 1 ).times
      # this is the the command we want to test
      expect( subject ).to receive( :on ).with( host, cmd, {:accept_all_exit_codes=>true} ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, "cd #{path}/#{repo[:name]} && git remote rm origin && git remote add origin #{repo[:path]} && git fetch origin +refs/pull/*:refs/remotes/origin/pr/* +refs/heads/*:refs/remotes/origin/* && git clean -fdx && git checkout -f #{repo[:rev]}", {:accept_all_exit_codes=>true} ).exactly( 1 ).times

      subject.instance_variable_set( :@metadata, {} )
      subject.clone_git_repo_on( host, path, repo )
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
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )
      logger = double.as_null_object
      allow( subject ).to receive( :metadata ).and_return( metadata )
      expect( subject ).to receive( :logger ).exactly( 2 ).times.and_return( logger )
      expect( subject ).to receive( :on ).with( host, "test -d #{path} || mkdir -p #{path}", {:accept_all_exit_codes=>true} ).exactly( 1 ).times
      # this is the the command we want to test
      expect( subject ).to receive( :on ).with( host, cmd, {:accept_all_exit_codes=>true} ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, "cd #{path}/#{repo[:name]} && git remote rm origin && git remote add origin #{repo[:path]} && git fetch origin +refs/pull/*:refs/remotes/origin/pr/* +refs/heads/*:refs/remotes/origin/* && git clean -fdx && git checkout -f #{repo[:rev]}", {:accept_all_exit_codes=>true} ).exactly( 1 ).times

      subject.instance_variable_set( :@metadata, {} )
      subject.clone_git_repo_on( host, path, repo )
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

      allow( subject ).to receive( :metadata ).and_return( metadata )
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )

      expect( subject ).to receive( :logger ).exactly( 3 ).times.and_return( logger )
      expect( subject ).to receive( :on ).exactly( 4 ).times

      subject.instance_variable_set( :@metadata, {} )
      subject.install_from_git( host, path, repo )
    end

    it 'should attempt to install ruby code' do
      repo   = { :name => 'puppet',
                 :path => 'git://my.server.net/puppet.git',
                 :rev => 'master',
                 :depth => 1 }

      path   = '/path/to/repos'
      cmd    = "test -d #{path}/#{repo[:name]} || git clone --branch #{repo[:rev]} --depth #{repo[:depth]} #{repo[:path]} #{path}/#{repo[:name]}"
      host   = { 'platform' => 'debian' }
      logger = double.as_null_object
      allow( subject ).to receive( :metadata ).and_return( metadata )
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )
      expect( subject ).to receive( :logger ).exactly( 3 ).times.and_return( logger )
      expect( subject ).to receive( :on ).with( host, "test -d #{path} || mkdir -p #{path}", {:accept_all_exit_codes=>true} ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, cmd, {:accept_all_exit_codes=>true} ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, "cd #{path}/#{repo[:name]} && git remote rm origin && git remote add origin #{repo[:path]} && git fetch origin +refs/pull/*:refs/remotes/origin/pr/* +refs/heads/*:refs/remotes/origin/* && git clean -fdx && git checkout -f #{repo[:rev]}", {:accept_all_exit_codes=>true} ).exactly( 1 ).times
      expect( subject ).to receive( :on ).with( host, "cd #{path}/#{repo[:name]} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi", {:accept_all_exit_codes=>true} ).exactly( 1 ).times

      subject.instance_variable_set( :@metadata, {} )
      subject.install_from_git_on( host, path, repo )
    end
   end

  describe '#install_puppet' do
    let(:hosts) do
      make_hosts({:platform => platform })
    end

    before do
      allow( subject ).to receive(:options).and_return(opts)
      allow( subject ).to receive(:hosts).and_return(hosts)
      allow( subject ).to receive(:on).and_return(Beaker::Result.new({},''))
    end
    context 'on el-6' do
      let(:platform) { Beaker::Platform.new('el-6-i386') }
      it 'installs' do
        expect(subject).to receive(:on).with(hosts[0], /puppetlabs-release-el-6\.noarch\.rpm/)
        expect(hosts[0]).to receive(:install_package).with('puppet')
        subject.install_puppet
      end
      it 'installs specific version of puppet when passed :version' do
        expect(hosts[0]).to receive(:install_package).with('puppet-3')
        subject.install_puppet( :version => '3' )
      end
      it 'can install specific versions of puppets dependencies' do
        expect(hosts[0]).to receive(:install_package).with('puppet-3')
        expect(hosts[0]).to receive(:install_package).with('hiera-2001')
        expect(hosts[0]).to receive(:install_package).with('facter-1999')
        subject.install_puppet( :version => '3', :facter_version => '1999', :hiera_version => '2001' )
      end
    end
    context 'on el-5' do
      let(:platform) { Beaker::Platform.new('el-5-i386') }
      it 'installs' do
        expect(subject).to receive(:on).with(hosts[0], /puppetlabs-release-el-5\.noarch\.rpm/)
        expect(hosts[0]).to receive(:install_package).with('puppet')
        subject.install_puppet
      end
    end
    context 'on fedora' do
      let(:platform) { Beaker::Platform.new('fedora-18-x86_84') }
      it 'installs' do
        expect(subject).to receive(:on).with(hosts[0], /puppetlabs-release-fedora-18\.noarch\.rpm/)
        expect(hosts[0]).to receive(:install_package).with('puppet')
        subject.install_puppet
      end
    end
    context 'on debian' do
      let(:platform) { Beaker::Platform.new('debian-7-amd64') }
      it 'installs latest if given no version info' do
        hosts.each do |host|
          expect(subject).to receive(:install_puppetlabs_release_repo).with(host)
        end
        expect(hosts[0]).to receive(:install_package).with('puppet')
        subject.install_puppet
      end
      it 'installs specific version of puppet when passed :version' do
        expect(hosts[0]).to receive(:install_package).with('puppet=3-1puppetlabs1')
        expect(hosts[0]).to receive(:install_package).with('puppet-common=3-1puppetlabs1')
        subject.install_puppet( :version => '3' )
      end
      it 'can install specific versions of puppets dependencies' do
        expect(hosts[0]).to receive(:install_package).with('facter=1999-1puppetlabs1')
        expect(hosts[0]).to receive(:install_package).with('hiera=2001-1puppetlabs1')
        expect(hosts[0]).to receive(:install_package).with('puppet-common=3-1puppetlabs1')
        expect(hosts[0]).to receive(:install_package).with('puppet=3-1puppetlabs1')
        subject.install_puppet( :version => '3', :facter_version => '1999', :hiera_version => '2001' )
      end
    end
    context 'on windows' do
      let(:platform) { Beaker::Platform.new('windows-2008r2-i386') }

      before :each do
        expect(subject).to receive(:get_temp_path).exactly(hosts.length).times.and_return(win_temp)
      end

      it 'installs specific version of puppet when passed :version' do
        allow(hosts[0]).to receive(:is_cygwin?).and_return(true)
        allow(subject).to receive(:link_exists?).and_return( true )
        expect(subject).to receive(:on).with(hosts[0], "curl -o \"#{win_temp}\\puppet-3.msi\" -O http://downloads.puppetlabs.com/windows/puppet-3.msi")
        expect(subject).to receive(:on).with(hosts[0], " echo 'export PATH=$PATH:\"/cygdrive/c/Program Files (x86)/Puppet Labs/Puppet/bin\":\"/cygdrive/c/Program Files/Puppet Labs/Puppet/bin\"' > /etc/bash.bashrc ")
        expect(subject).to receive(:install_msi_on).with(hosts[0], "#{win_temp}\\puppet-3.msi", {}, {:debug => nil}).exactly(1).times
        allow(subject).to receive(:install_msi_on).with(any_args)

        subject.install_puppet(:version => '3')
      end
      it 'installs from custom url when passed :win_download_url' do
        allow(hosts[0]).to receive(:is_cygwin?).and_return(true)
        allow(subject).to receive(:link_exists?).and_return( true )
        expect(subject).to receive(:on).with(hosts[0], "curl -o \"#{win_temp}\\puppet-3.msi\" -O http://nightlies.puppetlabs.com/puppet-latest/repos/windows/puppet-3.msi")
        expect(subject).to receive(:install_msi_on).with(hosts[0], "#{win_temp}\\puppet-3.msi", {}, {:debug => nil})
        allow(subject).to receive(:install_msi_on).with(any_args)

        subject.install_puppet( :version => '3', :win_download_url => 'http://nightlies.puppetlabs.com/puppet-latest/repos/windows' )
      end
    end
    describe 'on unsupported platforms' do
      let(:platform) { Beaker::Platform.new('solaris-11-x86_64') }
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
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )
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
        expect(subject).to receive(:on).with( host, /^(rpm --replacepkgs -ivh).*/ ).ordered
        subject.install_puppetlabs_release_repo host
      end

    end

  end

  describe "#install_puppetlabs_dev_repo" do
    let( :package_name ) { "puppet" }
    let( :package_version ) { "7.5.6" }
    let( :host ) do
      FakeHost.create('fakvm', platform.to_s, opts)
    end
    let( :logger_double ) do
      logger_double = Object.new
      allow(logger_double).to receive(:debug)
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )
      subject.instance_variable_set(:@logger, logger_double)
      logger_double
    end

    RSpec.shared_examples "install-dev-repo" do

      it "scp's files to SUT then modifies them with find-and-sed 2-hit combo" do
        allow(rez).to receive(:exit_code) { 0 }
        allow(logger_double).to receive(:debug)
        allow(subject).to receive(:link_exists?).and_return(true)
        expect(subject).to receive(:on).with( host, /^mkdir -p .*$/ ).ordered
        expect(subject).to receive(:scp_to).with( host, repo_config, /.*/ ).ordered
        expect(subject).to receive(:scp_to).with( host, repo_dir, /.*/ ).ordered
        expect(subject).to receive(:on).with( host, /^find .* sed .*/ ).ordered
        subject.install_puppetlabs_dev_repo host, package_name, package_version
      end

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
          allow(logger_double).to receive(:debug)

          stub_uninteresting_portions_of_install_puppetlabs_dev_repo!

          opts[:dev_builds_repos] = ['PC1']
          expect(subject).to receive(:on).with( host, /^find .* sed .*PC1.*/ )
          subject.install_puppetlabs_dev_repo host, package_name, package_version
        end

        it 'sets up the main repository if that was downloaded' do
          allow(rez).to receive(:exit_code) { 0 }
          allow(logger_double).to receive(:debug)

          stub_uninteresting_portions_of_install_puppetlabs_dev_repo!

          expect(subject).to receive(:on).with( host, /^find .* sed .*main.*/ )
          subject.install_puppetlabs_dev_repo host, package_name, package_version
        end

      end

      describe "that are redhat-like" do
        let( :platform ) { Beaker::Platform.new('el-7-i386') }
        include_examples "install-dev-repo"

        it 'downloads products or devel repo -- in that order, by default' do
          allow(subject).to receive(:on).with( host, /^find .* sed .*/ )
          stub_uninteresting_portions_of_install_puppetlabs_dev_repo!

          expect(logger_double).to receive(:debug).exactly( 2 ).times
          expect(subject).to receive(:link_exists?).with(/.*products.*/).and_return( false )
          expect(subject).to receive(:link_exists?).with(/.*devel.*/).twice.and_return( true )

          subject.install_puppetlabs_dev_repo host, package_name, package_version
        end

        it 'allows ordered customization of repos based on the :dev_builds_repos option' do
          opts[:dev_builds_repos] = ['PC17', 'yomama', 'McGuyver', 'McGruber', 'panama']
          allow(subject).to receive(:on).with( host, /^find .* sed .*/ )
          stub_uninteresting_portions_of_install_puppetlabs_dev_repo!

          logger_call_num = opts[:dev_builds_repos].length + 2
          expect(logger_double).to receive(:debug).exactly( logger_call_num ).times
          opts[:dev_builds_repos].each do |repo|
            expect(subject).to receive(:link_exists?).with(/.*repo.*/).ordered.and_return( false )
          end
          expect(subject).to receive(:link_exists?).with(/.*products.*/).ordered.and_return( false )
          expect(subject).to receive(:link_exists?).with(/.*devel.*/).twice.ordered.and_return( true )

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

    before :each do
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )
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

  describe '#install_puppet_agent_from_msi_on' do
    let( :opts )     { { :puppet_agent_version => 'VERSION' } }
    let( :platform ) { 'windows' }
    let( :host )     { { :platform => platform } }

    it 'uses x86 msi when host is_x86_64 and install_32 is set on the host' do
      host['install_32'] = true

      expect( host ).to receive( :is_x86_64? ).and_return( true )
      expect( subject ).to receive( :install_a_puppet_msi_on ).with( host, opts )

      subject.install_puppet_agent_from_msi_on( host, opts )
      expect( host['dist'] ).to be == "puppet-agent-VERSION-x86"

    end

    it 'uses x86 msi when host is_x86_64 and install_32 is set on the options' do
      opts['install_32'] = true

      expect( host ).to receive( :is_x86_64? ).and_return( true )
      expect( subject ).to receive( :install_a_puppet_msi_on ).with( host, opts )

      subject.install_puppet_agent_from_msi_on( host, opts )
      expect( host['dist'] ).to be == "puppet-agent-VERSION-x86"

    end

    it 'uses x86 msi when host is_x86_64 and ruby_arch is x86 on the host' do
      host['ruby_arch'] = 'x86'

      expect( host ).to receive( :is_x86_64? ).and_return( true )
      expect( subject ).to receive( :install_a_puppet_msi_on ).with( host, opts )

      subject.install_puppet_agent_from_msi_on( host, opts )
      expect( host['dist'] ).to be == "puppet-agent-VERSION-x86"

    end

    it 'uses x86 msi when host !is_x86_64' do

      expect( host ).to receive( :is_x86_64? ).and_return( false )
      expect( subject ).to receive( :install_a_puppet_msi_on ).with( host, opts )

      subject.install_puppet_agent_from_msi_on( host, opts )
      expect( host['dist'] ).to be == "puppet-agent-VERSION-x86"

    end

    it 'uses x64 msi when host is_x86_64, no install_32 and ruby_arch != x86' do

      expect( host ).to receive( :is_x86_64? ).and_return( true )
      expect( subject ).to receive( :install_a_puppet_msi_on ).with( host, opts )

      subject.install_puppet_agent_from_msi_on( host, opts )
      expect( host['dist'] ).to be == "puppet-agent-VERSION-x64"

    end
  end

  describe '#install_puppet_agent_dev_repo_on' do

    it 'raises an exception when host platform is unsupported' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['ptan', '5', 'x4']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }
      allow( subject ).to receive( :options ).and_return( {} )

      expect{
        subject.install_puppet_agent_dev_repo_on( host, opts )
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

      subject.install_puppet_agent_dev_repo_on( host, opts )
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

      subject.install_puppet_agent_dev_repo_on( host, opts )
    end

    it 'runs the correct install for windows platforms' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['windows', '5', 'x64']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }
      allow( subject ).to receive( :options ).and_return( {} )
      copied_path = "#{win_temp}\\puppet-agent-x64.msi"
      mock_echo = Object.new()
      allow( mock_echo ).to receive( :raw_output ).and_return( copied_path )

      expect(subject).to receive(:fetch_http_file).once.with(/\/windows$/, 'puppet-agent-x64.msi', /\/windows$/)
      expect(subject).to receive(:scp_to).once.with(host, /\/puppet-agent-x64.msi$/, /cygpath/)
      expect(subject).to receive(:install_msi_on).with(host, copied_path, {}, {:debug => nil}).once
      expect(subject).to receive(:on).ordered.with(host, /echo/).and_return(mock_echo)

      subject.install_puppet_agent_dev_repo_on( host, opts )
    end

    it 'runs the correct install for osx platforms (newest link format)' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['osx', '10.9', 'x86_64', 'mavericks']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }


      expect(subject).to receive(:link_exists?).with(/#{Regexp.escape('puppet-agent/0.1.0/repos/apple/10.9/PC1/x86_64')}/).and_return(true).twice
      expect(subject).to receive(:fetch_http_file).once.with(/#{Regexp.escape('apple/10.9/PC1/x86_64')}$/, 'puppet-agent-0.1.0-1.osx10.9.dmg', /\/osx$/)
      expect(subject).to receive(:scp_to).once.with(host, /\/puppet-agent-0.1.0-1.osx10.9.dmg$/, /var\/root/)
      expect(host).to receive( :install_package ).with(/puppet-agent-0.1.0\*/)

      subject.install_puppet_agent_dev_repo_on( host, opts )
    end

    it 'runs the correct install for osx platforms (new link format)' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['osx', '10.9', 'x86_64', 'mavericks']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }

      expect(subject).to receive(:link_exists?).with(/#{Regexp.escape('puppet-agent/0.1.0/repos/apple/10.9/PC1/x86_64/')}/).and_return(false, true)
      expect(subject).to receive(:fetch_http_file).once.with(/#{Regexp.escape('/apple/10.9/PC1/x86_64')}$/, 'puppet-agent-0.1.0-1.mavericks.dmg', /\/osx$/)
      expect(subject).to receive(:scp_to).once.with(host, /\/puppet-agent-0.1.0-1.mavericks.dmg$/, /var\/root/)
      expect(host).to receive( :install_package ).with(/puppet-agent-0.1.0\*/)

      subject.install_puppet_agent_dev_repo_on( host, opts )
    end

    it 'runs the correct install for osx platforms (old link format)' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['osx', '10.9', 'x86_64', 'mavericks']}
      host = basic_hosts.first
      host['platform'] = platform
      opts = { :version => '0.1.0' }

      expect(subject).to receive(:link_exists?).with(/#{Regexp.escape('/puppet-agent/0.1.0/repos/apple/10.9/PC1/x86_64/')}/).and_return(false, false)
      expect(subject).to receive(:fetch_http_file).once.with(/#{Regexp.escape('/puppet-agent/0.1.0/repos/apple/PC1')}$/, 'puppet-agent-0.1.0-osx-10.9-x86_64.dmg', /\/osx$/)
      expect(subject).to receive(:scp_to).once.with(host, /\/puppet-agent-0.1.0-osx-10.9-x86_64.dmg$/, /var\/root/)
      expect(host).to receive( :install_package ).with(/puppet-agent-0.1.0\*/)

      subject.install_puppet_agent_dev_repo_on( host, opts )
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

      subject.install_puppet_agent_dev_repo_on( host, opts )
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

      subject.install_puppet_agent_dev_repo_on( host, opts )
    end
  end

  describe '#install_puppet_agent_pe_promoted_repo_on' do

    it 'splits the platform string version correctly to get ubuntu puppet-agent packages (format 9999)' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['ubuntu', '9999', 'x42']}
      host = basic_hosts.first
      host['platform'] = platform

      expect(subject).to receive(:fetch_http_file).once.with(/\/puppet-agent\//, "puppet-agent-ubuntu-99.99-x42.tar.gz", /ubuntu/)
      expect(subject).to receive(:scp_to).once.with(host, /-ubuntu-99.99-x42\./, "/root")
      expect(subject).to receive(:on).ordered.with(host, /^tar.*-ubuntu-99.99-x42/)
      expect(subject).to receive(:on).ordered.with(host, /dpkg\ -i\ --force-all/)
      expect(subject).to receive(:on).ordered.with(host, /apt-get\ update/)

      subject.install_puppet_agent_pe_promoted_repo_on( host, {} )
    end

    it 'doesn\'t split the platform string version correctly to get ubuntu puppet-agent packages when unnecessary (format 99.99)' do
      platform = Object.new()
      allow(platform).to receive(:to_array) { ['ubuntu', '99.99', 'x42']}
      host = basic_hosts.first
      host['platform'] = platform

      expect(subject).to receive(:fetch_http_file).once.with(/\/puppet-agent\//, "puppet-agent-ubuntu-99.99-x42.tar.gz", /ubuntu/)
      expect(subject).to receive(:scp_to).once.with(host, /-ubuntu-99.99-x42\./, "/root")
      expect(subject).to receive(:on).ordered.with(host, /^tar.*-ubuntu-99.99-x42/)
      expect(subject).to receive(:on).ordered.with(host, /dpkg\ -i\ --force-all/)
      expect(subject).to receive(:on).ordered.with(host, /apt-get\ update/)

      subject.install_puppet_agent_pe_promoted_repo_on( host, {} )
    end

  end

  describe '#install_cert_on_windows' do
    before do
      allow(subject).to receive(:on).and_return(Beaker::Result.new({},''))
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

  describe '#install_puppet_agent_dev_repo_on' do
    let( :package_name ) { 'puppet-agent' }
    let( :platform ) { @platform || 'other' }
    let( :host ) do
      FakeHost.create( 'fakvm', platform, opts )
    end

    before :each do
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )
    end

    def test_fetch_http_file(agent_version = '1.0.0')
      expect( subject ).to receive( :configure_type_defaults_on ).with(host)
      expect( subject ).to receive( :fetch_http_file ).with( /[^\/]\z/, anything, anything )
      subject.install_puppet_agent_dev_repo_on( host, opts.merge({ :puppet_agent_version => agent_version }) )
    end

    context 'on windows' do
      before :each do
        @platform = 'windows-7-x86_64'
      end

      it 'copies package to the cygwin root directory and installs it' do
        expect( subject ).to receive( :install_msi_on ).with( any_args )
        expect( subject ).to receive( :scp_to ).with( host, /puppet-agent-x86\.msi/, '`cygpath -smF 35`/' )
        test_fetch_http_file
      end
    end

    context 'on debian' do
      before :each do
        @platform = 'debian-5-x86_64'
      end

      it 'copies repo_config to the root user directory and installs it' do
        expect( subject ).to receive( :scp_to ).with( host, /\/puppet-agent_1\.0\.0-1_amd64\.deb/, '/root' )
        expect( subject ).to receive( :on ).with( host, /dpkg -i --force-all .+puppet-agent_1\.0\.0-1_amd64\.deb/ )
        expect( subject ).to receive( :on ).with( host, /apt-get update/ )
        test_fetch_http_file
      end
    end

    context 'on solaris 10' do
      before :each do
        @platform = 'solaris-10-x86_64'
      end

      [
          ['1.0.1.786.477', '1.0.1.786.477'],
          ['1.0.1.786.a477', '1.0.1.786.a477'],
          ['1.0.1.786.477-', '1.0.1.786.477-'],
          ['1.0.1.0000786.477', '1.0.1.0000786.477'],
          ['1.000000.1.786.477', '1.000000.1.786.477'],
          ['-1.0.1.786.477', '-1.0.1.786.477'],
          ['1.2.5.38.6813', '1.2.5.38.6813']
      ].each do |val, expected|

        it "copies package to the root directory and installs it" do
          expect( subject ).to receive( :link_exists? ).with(/puppet-agent-#{expected}-1\.i386\.pkg\.gz/).and_return( true )
          expect( subject ).to receive( :scp_to ).with( host, /\/puppet-agent-#{expected}-1.i386\.pkg\.gz/, '/' )
          expect( subject ).to receive( :create_remote_file ).with( host, '/noask', /noask file/m )
          expect( subject ).to receive( :on ).with( host, "gunzip -c puppet-agent-#{expected}-1.i386.pkg.gz | pkgadd -d /dev/stdin -a noask -n all" )
          test_fetch_http_file(val)
        end

        it "copies old package to the root directory and installs it" do
          expect( subject ).to receive( :link_exists? ).with(/puppet-agent-#{expected}-1\.i386\.pkg\.gz/).and_return( false )
          expect( subject ).to receive( :scp_to ).with( host, /\/puppet-agent-#{expected}.i386\.pkg\.gz/, '/' )
          expect( subject ).to receive( :create_remote_file ).with( host, '/noask', /noask file/m )
          expect( subject ).to receive( :on ).with( host, "gunzip -c puppet-agent-#{expected}.i386.pkg.gz | pkgadd -d /dev/stdin -a noask -n all" )
          test_fetch_http_file(val)
        end
      end
    end

    context 'on solaris 11' do
      before :each do
        @platform = 'solaris-11-x86_64'
      end

      [
          ['1.0.1.786.477', '1.0.1.786.477'],
          ['1.0.1.786.a477', '1.0.1.786.477'],
          ['1.0.1.786.477-', '1.0.1.786.477'],
          ['1.0.1.0000786.477', '1.0.1.786.477'],
          ['1.000000.1.786.477', '1.0.1.786.477'],
          ['-1.0.1.786.477', '1.0.1.786.477'],
          ['1.2.5-78-gbb3022f', '1.2.5.78.3022'],
          ['1.2.5.38.6813', '1.2.5.38.6813']
      ].each do |val, expected|

        it "copies package to the root user directory and installs it" do
          # version = 1.0.0
          expect( subject ).to receive( :link_exists? ).with(/puppet-agent@#{expected},5\.11-1\.i386\.p5p/).and_return( true )
          expect( subject ).to receive( :scp_to ).with( host, /\/puppet-agent@#{expected},5\.11-1\.i386\.p5p/, '/root' )
          expect( subject ).to receive( :on ).with( host, "pkg install -g puppet-agent@#{expected},5.11-1.i386.p5p puppet-agent" )
          test_fetch_http_file(val)
        end

        it "copies old package to the root directory and installs it" do
          expect( subject ).to receive( :link_exists? ).with(/puppet-agent@#{expected},5\.11-1\.i386\.p5p/).and_return( false )
          expect( subject ).to receive( :scp_to ).with( host, /\/puppet-agent@#{expected},5\.11\.i386\.p5p/, '/root' )
          expect( subject ).to receive( :on ).with( host, "pkg install -g puppet-agent@#{expected},5.11.i386.p5p puppet-agent" )
          test_fetch_http_file(val)
        end
      end
    end
  end

  describe '#install_puppet_agent_pe_promoted_repo_on' do
    let( :package_name ) { 'puppet-agent' }
    let( :platform ) { @platform || 'other' }
    let( :host ) do
      FakeHost.create( 'fakvm', platform, opts )
    end

    before :each do
      allow( subject ).to receive( :configure_foss_defaults_on ).and_return( true )
      allow( subject ).to receive( :install_msi_on ).with( any_args )
    end

    def test_fetch_http_file_no_ending_slash(platform)
      @platform = platform
      allow( subject ).to receive( :scp_to )
      allow( subject ).to receive( :configure_type_defaults_on ).with(host)

      expect( subject ).to receive( :fetch_http_file ).with( /[^\/]\z/, anything, anything )
      subject.install_puppet_agent_pe_promoted_repo_on( host, opts )
    end

    context 'on windows' do

      it 'calls fetch_http_file with no ending slash' do
        test_fetch_http_file_no_ending_slash( 'windows-7-x86_64' )
      end

    end

    it 'calls fetch_http_file with no ending slash' do
      test_fetch_http_file_no_ending_slash( 'debian-5-x86_64' )
    end

  end

  describe '#remove_puppet_on' do
    let(:aixhost) { make_host('aix', :platform => 'aix-53-power') }
    let(:sol10host) { make_host('sol10', :platform => 'solaris-10-x86_64') }
    let(:sol11host) { make_host('sol11', :platform => 'solaris-11-x86_64') }
    let(:el6host) { make_host('el6', :platform => 'el-6-x64') }

    pkg_list = 'foo bar'

    it 'uninstalls packages on aix, including tar' do
      aix_depend_list = 'tar'
      result = Beaker::Result.new(aixhost,'')
      result.stdout = pkg_list
      result2 = Beaker::Result.new(aixhost,'')
      result2.stdout = aix_depend_list

      expected_list = pkg_list + " " + aix_depend_list
      cmd_args = ''

      expect( subject ).to receive(:on).exactly(3).times.and_return(result, result2, result)
      expect( aixhost ).to receive(:uninstall_package).with(expected_list, cmd_args)

      subject.remove_puppet_on( aixhost )
    end

    it 'uninstalls packages on solaris 10' do
      result = Beaker::Result.new(sol10host,'')
      result.stdout = pkg_list

      expected_list = pkg_list
      cmd_args = '-a noask'

      expect( subject ).to receive(:on).exactly(2).times.and_return(result, result)
      expect( sol10host ).to receive(:uninstall_package).with(expected_list, cmd_args)

      subject.remove_puppet_on( sol10host  )
    end

    it 'uninstalls packages on solaris 11' do
      result = Beaker::Result.new(sol11host,'')
      result.stdout='foo bar'

      expected_list = pkg_list
      cmd_args = ''

      expect( subject ).to receive(:on).exactly(3).times.and_return(result, result, result)
      expect( sol11host ).to receive(:uninstall_package).with(expected_list, cmd_args)

      subject.remove_puppet_on( sol11host  )
    end

    it 'raises error on other platforms' do
      expect { subject.remove_puppet_on( el6host ) }.to raise_error(RuntimeError, /unsupported platform/)
    end

  end

end
