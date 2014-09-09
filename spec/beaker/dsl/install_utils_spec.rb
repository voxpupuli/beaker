require 'spec_helper'

class ClassMixedWithDSLInstallUtils
  include Beaker::DSL::InstallUtils
  include Beaker::DSL::Structure
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns
end

describe ClassMixedWithDSLInstallUtils do
  let(:opts)          { Beaker::Options::Presets.presets.merge(Beaker::Options::Presets.env_vars) }
  let(:basic_hosts)   { make_hosts( { :pe_ver => '3.0',
                                       :platform => 'linux',
                                       :roles => [ 'agent' ] } ) }
  let(:hosts)         { basic_hosts[0][:roles] = ['master', 'database', 'dashboard']
                        basic_hosts[1][:platform] = 'windows'
                        basic_hosts[2][:platform] = 'osx-10.9-x86_64'
                        basic_hosts  }
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

      subject.should_receive( :logger ).and_return( logger )
      subject.should_receive( :on ).with( host, cmd ).and_yield
      subject.should_receive( :stdout ).and_return( '2' )

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

      subject.should_receive( :logger ).exactly( 3 ).times.and_return( logger )
      subject.should_receive( :on ).exactly( 4 ).times

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
      subject.should_receive( :logger ).exactly( 3 ).times.and_return( logger )
      subject.should_receive( :on ).with( host,"test -d #{path} || mkdir -p #{path}").exactly( 1 ).times
      # this is the the command we want to test
      subject.should_receive( :on ).with( host, cmd ).exactly( 1 ).times
      subject.should_receive( :on ).with( host, "cd #{path}/#{repo[:name]} && git remote rm origin && git remote add origin #{repo[:path]} && git fetch origin && git clean -fdx && git checkout -f #{repo[:rev]}" ).exactly( 1 ).times
      subject.should_receive( :on ).with( host, "cd #{path}/#{repo[:name]} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi" ).exactly( 1 ).times

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
      subject.should_receive( :logger ).exactly( 3 ).times.and_return( logger )
      subject.should_receive( :on ).with( host,"test -d #{path} || mkdir -p #{path}").exactly( 1 ).times
      # this is the the command we want to test
      subject.should_receive( :on ).with( host, cmd ).exactly( 1 ).times
      subject.should_receive( :on ).with( host, "cd #{path}/#{repo[:name]} && git remote rm origin && git remote add origin #{repo[:path]} && git fetch origin && git clean -fdx && git checkout -f #{repo[:rev]}" ).exactly( 1 ).times
      subject.should_receive( :on ).with( host, "cd #{path}/#{repo[:name]} && if [ -f install.rb ]; then ruby ./install.rb ; else true; fi" ).exactly( 1 ).times

      subject.install_from_git( host, path, repo )
    end
   end

  describe 'sorted_hosts' do
    it 'can reorder so that the master comes first' do
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      expect( subject.sorted_hosts ).to be === hosts
    end

    it 'leaves correctly ordered hosts alone' do
      subject.stub( :hosts ).and_return( hosts )
      expect( subject.sorted_hosts ).to be === hosts
    end
  end

  describe 'installer_cmd' do

    it 'generates a windows PE install command for a windows host' do
      winhost['dist'] = 'puppet-enterprise-3.0'
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2], winhost ] )
      expect( subject.installer_cmd( winhost, {} ) ).to be === "cd /tmp && cmd /C 'start /w msiexec.exe /qn /L*V tmp.log /i puppet-enterprise-3.0.msi PUPPET_MASTER_SERVER=vm1 PUPPET_AGENT_CERTNAME=winhost'"
    end

    it 'generates a unix PE install command for a unix host' do
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp/puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386 && ./puppet-enterprise-installer -a /tmp/answers"
    end

    it 'generates a unix PE frictionless install command for a unix host with role "frictionless"' do
      subject.stub( :version_is_less ).and_return( false )
      subject.stub( :master ).and_return( 'testmaster' )
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['roles'] = ['frictionless']
      expect( subject.installer_cmd( the_host, {} ) ).to be ===  "cd /tmp && curl -kO https://testmaster:8140/packages/3.0/install.bash && bash install.bash"
    end

    it 'generates a osx PE install command for a osx host' do
      the_host = machost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp && hdiutil attach .dmg && installer -pkg /Volumes/puppet-enterprise-3.0/puppet-enterprise-installer-3.0.pkg -target /"
    end

    it 'generates a unix PE install command in verbose for a unix host when pe_debug is enabled' do
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host[:pe_debug] = true
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp/puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386 && ./puppet-enterprise-installer -D -a /tmp/answers"
    end

    it 'generates a osx PE install command in verbose for a osx host when pe_debug is enabled' do
      the_host = machost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host[:pe_debug] = true
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp && hdiutil attach .dmg && installer -verboseR -pkg /Volumes/puppet-enterprise-3.0/puppet-enterprise-installer-3.0.pkg -target /"
    end

    it 'generates a unix PE frictionless install command in verbose for a unix host with role "frictionless" and pe_debug is enabled' do
      subject.stub( :version_is_less ).and_return( false )
      subject.stub( :master ).and_return( 'testmaster' )
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['roles'] = ['frictionless']
      the_host[:pe_debug] = true
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp && curl -kO https://testmaster:8140/packages/3.0/install.bash && bash -x install.bash"
    end

  end


  describe 'fetch_puppet' do

    it 'can push a local PE .tar.gz to a host and unpack it' do
      File.stub( :directory? ).and_return( true ) #is local
      File.stub( :exists? ).and_return( true ) #is a .tar.gz
      unixhost['pe_dir'] = '/local/file/path'
      subject.stub( :scp_to ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar.gz'
      subject.should_receive( :scp_to ).with( unixhost, "#{ path }/#{ filename }#{ extension }", "#{ unixhost['working_dir'] }/#{ filename }#{ extension }" ).once
      subject.should_receive( :on ).with( unixhost, /gunzip/ ).once
      subject.should_receive( :on ).with( unixhost, /tar -xvf/ ).once
      subject.fetch_puppet( [unixhost], {} )
    end

    it 'can download a PE .tar from a URL to a host and unpack it' do
      File.stub( :directory? ).and_return( false ) #is not local
      unixhost['pe_dir'] = 'http://www.path.com/dir/'
      subject.stub( :link_exists? ) do |arg|
        if arg =~ /.tar.gz/ #there is no .tar.gz link, only a .tar
          false
        else
          true
        end
      end
      subject.stub( :on ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar'
      subject.should_receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; curl #{ path }/#{ filename }#{ extension } | tar -xvf -" ).once
      subject.fetch_puppet( [unixhost], {} )
    end

    it 'can download a PE .tar.gz from a URL to a host and unpack it' do
      File.stub( :directory? ).and_return( false ) #is not local
      unixhost['pe_dir'] = 'http://www.path.com/dir/'
      subject.stub( :link_exists? ).and_return( true ) #is a tar.gz
      subject.stub( :on ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar.gz'
      subject.should_receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; curl #{ path }/#{ filename }#{ extension } | gunzip | tar -xvf -" ).once
      subject.fetch_puppet( [unixhost], {} )
    end

    it 'can push a local PE package to a windows host' do
      File.stub( :directory? ).and_return( true ) #is local
      File.stub( :exists? ).and_return( true ) #is present
      winhost['pe_dir'] = '/local/file/path'
      winhost['dist'] = 'puppet-enterprise-3.0'
      subject.stub( :scp_to ).and_return( true )

      path = winhost['pe_dir']
      filename = "puppet-enterprise-#{ winhost['pe_ver'] }"
      extension = '.msi'
      subject.should_receive( :scp_to ).with( winhost, "#{ path }/#{ filename }#{ extension }", "#{ winhost['working_dir'] }/#{ filename }#{ extension }" ).once
      subject.fetch_puppet( [winhost], {} )

    end

    it 'can download a PE dmg from a URL to a mac host' do
      File.stub( :directory? ).and_return( false ) #is not local
      machost['pe_dir'] = 'http://www.path.com/dir/'
      subject.stub( :link_exists? ).and_return( true ) #is  not local
      subject.stub( :on ).and_return( true )

      path = machost['pe_dir']
      filename = "#{ machost['dist'] }"
      extension = '.dmg'
      subject.should_receive( :on ).with( machost, "cd #{ machost['working_dir'] }; curl -O #{ path }/#{ filename }#{ extension }" ).once
      subject.fetch_puppet( [machost], {} )
    end

    it 'can push a PE dmg to a mac host' do
      File.stub( :directory? ).and_return( true ) #is local
      machost['pe_dir'] = 'http://www.path.com/dir/'
      File.stub( :exists? ).and_return( true ) #is present
      subject.stub( :scp_to ).and_return( true )

      path = machost['pe_dir']
      filename = "#{ machost['dist'] }"
      extension = '.dmg'
      subject.should_receive( :scp_to ).with( machost, "#{ path }/#{ filename }#{ extension }", "#{ machost['working_dir'] }/#{ filename }#{ extension }" ).once
      subject.fetch_puppet( [machost], {} )
    end

    it "does nothing for a frictionless agent for PE >= 3.2.0" do
      unixhost['roles'] << 'frictionless'
      unixhost['pe_ver'] = '3.2.0'

      subject.should_not_receive(:scp_to)
      subject.should_not_receive(:on)
      subject.stub(:version_is_less).with('3.2.0', '3.2.0').and_return(false)
      subject.fetch_puppet( [unixhost], {} )
    end
  end

  describe 'do_install' do
    it 'can perform a simple installation' do
      subject.stub( :on ).and_return( Beaker::Result.new( {}, '' ) )
      subject.stub( :fetch_puppet ).and_return( true )
      subject.stub( :create_remote_file ).and_return( true )
      subject.stub( :sign_certificate_for ).and_return( true )
      subject.stub( :stop_agent_on ).and_return( true )
      subject.stub( :sleep_until_puppetdb_started ).and_return( true )
      subject.stub( :version_is_less ).with('3.0', '3.4').and_return( true )
      subject.stub( :version_is_less ).with('3.0', '3.0').and_return( false )
      subject.stub( :wait_for_host_in_dashboard ).and_return( true )
      subject.stub( :puppet_agent ).and_return do |arg|
        "puppet agent #{arg}"
      end
      subject.stub( :puppet ).and_return do |arg|
        "puppet #{arg}"
      end

      subject.stub( :hosts ).and_return( hosts )
      #determine mastercert
      subject.should_receive( :on ).with( hosts[0], /uname/ ).once
      #create answers file per-host, except windows
      subject.should_receive( :create_remote_file ).with( hosts[0], /answers/, /q/ ).once
      #run installer on all hosts
      subject.should_receive( :on ).with( hosts[0], /puppet-enterprise-installer/ ).once
      subject.should_receive( :on ).with( hosts[1], /msiexec.exe/ ).once
      subject.should_receive( :on ).with( hosts[2], / hdiutil attach puppet-enterprise-3.0-osx-10.9-x86_64.dmg && installer -pkg \/Volumes\/puppet-enterprise-3.0\/puppet-enterprise-installer-3.0.pkg -target \// ).once
      #does extra mac specific commands
      subject.should_receive( :on ).with( hosts[2], /puppet config set server/ ).once
      subject.should_receive( :on ).with( hosts[2], /puppet config set certname/ ).once
      subject.should_receive( :on ).with( hosts[2], /puppet agent -t/, :acceptable_exit_codes => [1] ).once
      #sign certificate per-host
      subject.should_receive( :sign_certificate_for ).with( hosts[0] ).once
      subject.should_receive( :sign_certificate_for ).with( hosts[1] ).once
      subject.should_receive( :sign_certificate_for ).with( hosts[2] ).once
      #stop puppet agent on all hosts
      subject.should_receive( :stop_agent_on ).with( hosts[0] ).once
      subject.should_receive( :stop_agent_on ).with( hosts[1] ).once
      subject.should_receive( :stop_agent_on ).with( hosts[2] ).once
      #wait for puppetdb to start
      subject.should_receive( :sleep_until_puppetdb_started ).with( hosts[0] ).once
      #run each puppet agent once
      subject.should_receive( :on ).with( hosts[0], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).once
      subject.should_receive( :on ).with( hosts[1], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).once
      subject.should_receive( :on ).with( hosts[2], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).once
      #run rake task on dashboard
      subject.should_receive( :on ).with( hosts[0], /\/opt\/puppet\/bin\/rake -sf \/opt\/puppet\/share\/puppet-dashboard\/Rakefile .* RAILS_ENV=production/ ).once
      #wait for all hosts to appear in the dashboard
      subject.should_receive( :wait_for_host_in_dashboard ).with( hosts[0] ).once
      subject.should_receive( :wait_for_host_in_dashboard ).with( hosts[1] ).once
      subject.should_receive( :wait_for_host_in_dashboard ).with( hosts[2] ).once
      #run puppet agent now that installation is complete
      subject.should_receive( :on ).with( hosts, /puppet agent/, :acceptable_exit_codes => [0,2] ).once
      subject.do_install( hosts, opts )
    end
  end

  describe 'do_higgs_install' do

    before :each do
      my_time = double( "time double" )
      my_time.stub( :strftime ).and_return( "2014-07-01_15.27.53" )
      Time.stub( :new ).and_return( my_time )

      hosts[0]['working_dir'] = "tmp/2014-07-01_15.27.53"
      hosts[0]['dist'] = 'dist'
      hosts[0]['pe_installer'] = 'pe-installer'
      hosts[0].stub( :tmpdir ).and_return( "/tmp/2014-07-01_15.27.53" )

      @fail_result = Beaker::Result.new( {}, '' )
      @fail_result.stdout = "No match here"
      @success_result = Beaker::Result.new( {}, '' )
      @success_result.stdout = "Please go to https://website in your browser to continue installation"
    end

    it 'can perform a simple installation' do
      subject.stub( :fetch_puppet ).and_return( true )
      subject.stub( :sleep ).and_return( true )

      subject.stub( :hosts ).and_return( hosts )

      #run higgs installer command
      subject.should_receive( :on ).with( hosts[0],
                                         "cd /tmp/2014-07-01_15.27.53/puppet-enterprise-3.0-linux ; nohup ./pe-installer <<<Y > higgs_2014-07-01_15.27.53.log 2>&1 &",
                                        opts ).once
      #check to see if the higgs installation has proceeded correctly, works on second check
      subject.should_receive( :on ).with( hosts[0], /cat #{hosts[0]['higgs_file']}/, { :acceptable_exit_codes => 0..255 }).and_return( @fail_result, @success_result )
      subject.do_higgs_install( hosts[0], opts )
    end

    it 'fails out after checking installation log 10 times' do
      subject.stub( :fetch_puppet ).and_return( true )
      subject.stub( :sleep ).and_return( true )

      subject.stub( :hosts ).and_return( hosts )

      #run higgs installer command
      subject.should_receive( :on ).with( hosts[0],
                                         "cd /tmp/2014-07-01_15.27.53/puppet-enterprise-3.0-linux ; nohup ./pe-installer <<<Y > higgs_2014-07-01_15.27.53.log 2>&1 &",
                                        opts ).once
      #check to see if the higgs installation has proceeded correctly, works on second check
      subject.should_receive( :on ).with( hosts[0], /cat #{hosts[0]['higgs_file']}/, { :acceptable_exit_codes => 0..255 }).exactly(10).times.and_return( @fail_result )
      expect{ subject.do_higgs_install( hosts[0], opts ) }.to raise_error
    end

  end

  describe '#install_puppet' do
    let(:hosts) do
      make_hosts({:platform => platform })
    end

    before do
      subject.stub(:hosts).and_return(hosts)
      subject.stub(:on).and_return(Beaker::Result.new({},''))
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

  describe 'install_pe' do

    it 'calls do_install with sorted hosts' do
      subject.stub( :options ).and_return( {} )
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      subject.stub( :do_install ).and_return( true )
      subject.should_receive( :do_install ).with( hosts, {} )
      subject.install_pe
    end

    it 'fills in missing pe_ver' do
      hosts.each do |h|
        h['pe_ver'] = nil
      end
      Beaker::Options::PEVersionScraper.stub( :load_pe_version ).and_return( '2.8' )
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      subject.stub( :options ).and_return( {} )
      subject.stub( :do_install ).and_return( true )
      subject.should_receive( :do_install ).with( hosts, {} )
      subject.install_pe
      hosts.each do |h|
        expect( h['pe_ver'] ).to be === '2.8'
      end
    end
  end

  describe 'install_higgs' do
    it 'fills in missing pe_ver' do
      hosts[0]['pe_ver'] = nil
      Beaker::Options::PEVersionScraper.stub( :load_pe_version ).and_return( '2.8' )
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      subject.stub( :options ).and_return( {} )
      subject.stub( :do_higgs_install ).and_return( true )
      subject.should_receive( :do_higgs_install ).with( hosts[0], {} )
      subject.install_higgs
      expect( hosts[0]['pe_ver'] ).to be === '2.8'
    end

  end

  describe 'upgrade_pe' do

    it 'calls puppet-enterprise-upgrader for pre 3.0 upgrades' do
      Beaker::Options::PEVersionScraper.stub( :load_pe_version ).and_return( '2.8' )
      Beaker::Options::PEVersionScraper.stub( :load_pe_version_win ).and_return( '2.8' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      subject.stub( :hosts ).and_return( the_hosts )
      subject.stub( :options ).and_return( {} )
      subject.stub( :version_is_less ).with('2.8', '3.0').and_return( true )
      version = version_win = '2.8'
      path = "/path/to/upgradepkg"
      subject.should_receive( :do_install ).with( the_hosts, { :type => :upgrade } )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_installer'] ).to be === 'puppet-enterprise-upgrader'
      end
    end

    it 'uses standard upgrader for post 3.0 upgrades' do
      Beaker::Options::PEVersionScraper.stub( :load_pe_version ).and_return( '3.1' )
      Beaker::Options::PEVersionScraper.stub( :load_pe_version_win ).and_return( '3.1' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      subject.stub( :hosts ).and_return( the_hosts )
      subject.stub( :options ).and_return( {} )
      subject.stub( :version_is_less ).with('3.1', '3.0').and_return( false )
      version = version_win = '3.1'
      path = "/path/to/upgradepkg"
      subject.should_receive( :do_install ).with( the_hosts, { :type => :upgrade } )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_installer'] ).to be nil
      end
    end

    it 'updates pe_ver post upgrade' do
      Beaker::Options::PEVersionScraper.stub( :load_pe_version ).and_return( '2.8' )
      Beaker::Options::PEVersionScraper.stub( :load_pe_version_win ).and_return( '2.8' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      subject.stub( :hosts ).and_return( the_hosts )
      subject.stub( :options ).and_return( {} )
      subject.stub( :version_is_less ).with('2.8', '3.0').and_return( true )
      version = version_win = '2.8'
      path = "/path/to/upgradepkg"
      subject.should_receive( :do_install ).with( the_hosts, { :type => :upgrade } )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_ver'] ).to be === '2.8'
      end
    end

  end


  def fetch_allows
    allow(File).to receive( :exists? ) { true }
    allow(File).to receive( :open ).and_yield()
    allow(subject).to receive( :logger ) { logger }
  end

  describe "#fetch_http_file" do
    let( :logger) { double("Beaker::Logger", :notify => nil , :debug => nil ) }

    before do
      fetch_allows
    end

    describe "given valid arguments" do

      it "returns its second and third arguments concatenated." do
        result = subject.fetch_http_file "http://beaker.tool/", "name", "destdir"
        expect(result).to eq("destdir/name")
      end

    end

  end

  describe "#fetch_http_dir" do
    let( :logger) { double("Beaker::Logger", :notify => nil , :debug => nil ) }
    let( :result) { double(:each_line => []) }

    before do
      fetch_allows
    end

    describe "given valid arguments" do

      it "returns basename of first argument concatenated to second." do
        expect(subject).to receive(:`).with(/^wget.*/).ordered { result }
        result = subject.fetch_http_dir "http://beaker.tool/beep", "destdir"
        expect(result).to eq("destdir/beep")
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
    let( :repo_config ) { "repoconfig" }
    let( :repo_dir ) { "repodir" }

    before do
      allow(subject).to receive(:fetch_http_file) { repo_config }
      allow(subject).to receive(:fetch_http_dir) { repo_dir }
      allow(subject).to receive(:on).with(host, "apt-get update") { }
      allow(subject).to receive(:options) { opts }
      allow(subject).to receive(:link_exists?) { true }
    end

    it "scp's files to SUT then modifies them with find-and-sed 2-hit combo" do
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

    describe "When host is a debian-like platform" do
      let( :platform ) { Beaker::Platform.new('debian-7-i386') }
      include_examples "install-dev-repo"
    end

    describe "When host is a redhat-like platform" do
      let( :platform ) { Beaker::Platform.new('el-7-i386') }
      include_examples "install-dev-repo"
    end

  end

end
