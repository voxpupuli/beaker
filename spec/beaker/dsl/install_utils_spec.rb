require 'spec_helper'

class ClassMixedWithDSLInstallUtils
  include Beaker::DSL::InstallUtils
  include Beaker::DSL::Structure
  include Beaker::DSL::Roles
end

describe ClassMixedWithDSLInstallUtils do
   let (:basic_hosts)   { make_hosts( { :pe_ver => '3.0',
                                        :platform => 'linux',
                                        :roles => [ 'agent' ] } ) }
   let (:hosts)         { basic_hosts[0][:roles] = ['master', 'database', 'dashboard']
                          basic_hosts[1][:platform] = 'windows'
                          basic_hosts  }
   let (:winhost)       { make_host( 'winhost', { 'platform' => 'windows',
                                                  'pe_ver' => '3.0',
                                                  'working_dir' => '/tmp' } ) }
   let (:unixhost)      { make_host( 'unixhost', { 'platform' => 'linux',
                                                   'pe_ver' => '3.0',
                                                   'working_dir' => '/tmp',
                                                   'dist' => 'puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386' } ) }


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
      host        = stub( 'Host' )
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

      subject.should_receive( :logger ).any_number_of_times.and_return( logger )
      subject.should_receive( :on ).exactly( 4 ).times

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

  describe 'version_is_less' do

    it 'reports 3.0.0-160-gac44cfb is not less than 3.0.0' do
      expect( subject.version_is_less( '3.0.0-160-gac44cfb', '3.0.0' ) ).to be === false
    end

    it 'reports 3.0.0-160-gac44cfb is not less than 2.8.2' do
      expect( subject.version_is_less( '3.0.0-160-gac44cfb', '2.8.2' ) ).to be === false
    end

    it 'reports 3.0.0 is less than 3.0.0-160-gac44cfb' do
      expect( subject.version_is_less( '3.0.0', '3.0.0-160-gac44cfb' ) ).to be === true
    end

    it 'reports 2.8.2 is less than 3.0.0-160-gac44cfb' do
      expect( subject.version_is_less( '2.8.2', '3.0.0-160-gac44cfb' ) ).to be === true
    end

    it 'reports 2.8 is less than 3.0.0-160-gac44cfb' do
      expect( subject.version_is_less( '2.8', '3.0.0-160-gac44cfb' ) ).to be === true
    end

    it 'reports 2.8 is less than 2.9' do
      expect( subject.version_is_less( '2.8', '2.9' ) ).to be === true
    end
  end

  describe 'installer_cmd' do

    it 'generates a windows PE install command for a windows host' do
      expect( subject.installer_cmd( winhost, {} ) ).to be === "cd /tmp && msiexec.exe /qn /i puppet-enterprise-3.0.msi"
    end

    it 'generates a unix PE install command for a unix host' do
      expect( subject.installer_cmd( unixhost, { :installer => 'puppet-enterprise-installer' } ) ).to be === "cd /tmp/puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386 && ./puppet-enterprise-installer"
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
      subject.should_receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; curl #{ path }/#{ filename }#{ extension } -o #{ filename }#{ extension }" ).once
      subject.should_receive( :on ).with( unixhost, /tar -xvf/ ).once
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
      subject.should_receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; curl #{ path }/#{ filename }#{ extension } -o #{ filename }#{ extension }" ).once
      subject.should_receive( :on ).with( unixhost, /gunzip/ ).once
      subject.should_receive( :on ).with( unixhost, /tar -xvf/ ).once
      subject.fetch_puppet( [unixhost], {} )
    end
     
    it 'can push a local PE package to a windows host' do
      File.stub( :directory? ).and_return( true ) #is local
      File.stub( :exists? ).and_return( true ) #is present
      winhost['pe_dir'] = '/local/file/path'
      subject.stub( :scp_to ).and_return( true )

      path = winhost['pe_dir']
      filename = "puppet-enterprise-#{ winhost['pe_ver'] }"
      extension = '.msi'
      subject.should_receive( :scp_to ).with( winhost, "#{ path }/#{ filename }#{ extension }", "#{ winhost['working_dir'] }/#{ filename }#{ extension }" ).once
      subject.fetch_puppet( [winhost], {} )

    end
  end

  describe 'do_install' do
    it 'can preform a simple installation' do
      subject.stub( :on ).and_return( Beaker::Result.new( {}, '' ) )
      subject.stub( :fetch_puppet ).and_return( true )
      subject.stub( :create_remote_file ).and_return( true )
      subject.stub( :sign_certificate ).and_return( true )
      subject.stub( :stop_agent ).and_return( true )
      subject.stub( :sleep_until_puppetdb_started ).and_return( true )
      subject.stub( :wait_for_host_in_dashboard ).and_return( true )
      subject.stub( :puppet_agent ).and_return( "puppet agent" )

      subject.stub( :hosts ).and_return( hosts )
      #determine mastercert
      subject.should_receive( :on ).with( hosts[0], /uname/ ).once
      #create working dirs per-host
      subject.should_receive( :on ).with( hosts[0], /mkdir/ ).once
      subject.should_receive( :on ).with( hosts[1], /mkdir/ ).once
      subject.should_receive( :on ).with( hosts[2], /mkdir/ ).once
      #create answers file per-host, except windows
      subject.should_receive( :create_remote_file ).with( hosts[0], /answers/, /q/ ).once
      subject.should_receive( :create_remote_file ).with( hosts[2], /answers/, /q/ ).once
      #run installer on all hosts
      subject.should_receive( :on ).with( hosts[0], /puppet-enterprise-installer/ ).once
      subject.should_receive( :on ).with( hosts[1], /msiexec.exe/ ).once
      subject.should_receive( :on ).with( hosts[2], /puppet-enterprise-installer/ ).once
      #sign certificate per-host
      subject.should_receive( :sign_certificate ).with( hosts[0] ).once
      subject.should_receive( :sign_certificate ).with( hosts[1] ).once
      subject.should_receive( :sign_certificate ).with( hosts[2] ).once
      #stop puppet agent on all hosts
      subject.should_receive( :stop_agent ).with( hosts[0] ).once
      subject.should_receive( :stop_agent ).with( hosts[1] ).once
      subject.should_receive( :stop_agent ).with( hosts[2] ).once
      #wait for puppetdb to start
      subject.should_receive( :sleep_until_puppetdb_started ).with( hosts[0] ).once
      #run each puppet agent once
      subject.should_receive( :on ).with( hosts[0], /puppet agent/, :acceptable_exit_codes => [0,2] ).once
      subject.should_receive( :on ).with( hosts[1], /puppet agent/, :acceptable_exit_codes => [0,2] ).once
      subject.should_receive( :on ).with( hosts[2], /puppet agent/, :acceptable_exit_codes => [0,2] ).once
      #run rake task on dashboard
      subject.should_receive( :on ).with( hosts[0], /\/opt\/puppet\/bin\/rake -sf \/opt\/puppet\/share\/puppet-dashboard\/Rakefile .* RAILS_ENV=production/ ).once
      #wait for all hosts to appear in the dashboard
      subject.should_receive( :wait_for_host_in_dashboard ).with( hosts[0] ).once
      subject.should_receive( :wait_for_host_in_dashboard ).with( hosts[1] ).once
      subject.should_receive( :wait_for_host_in_dashboard ).with( hosts[2] ).once
      #run puppet agent now that installation is complete
      subject.should_receive( :on ).with( hosts, /puppet agent/, :acceptable_exit_codes => [0,2] ).once
      subject.do_install( hosts )
    end
  end

  describe 'install_pe' do

    it 'calls do_install with sorted hosts' do
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      subject.stub( :do_install ).and_return( true )
      subject.should_receive( :do_install ).with( hosts )
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
      subject.should_receive( :do_install ).with( hosts )
      subject.install_pe
      hosts.each do |h|
        expect( h['pe_ver'] ).to be === '2.8'
      end
    end
  end

  describe 'upgrade_pe' do

    it 'calls puppet-enterprise-upgrader for pre 3.0 upgrades' do
      Beaker::Options::PEVersionScraper.stub( :load_pe_version ).and_return( '2.8' )
      Beaker::Options::PEVersionScraper.stub( :load_pe_version_win ).and_return( '2.8' )
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      subject.stub( :options ).and_return( {} )
      version = version_win = '2.8'
      path = "/path/to/upgradepkg"
      subject.should_receive( :do_install ).with( hosts, { :type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win => version_win, :installer => 'puppet-enterprise-upgrader' } )
      subject.upgrade_pe( path )
    end

    it 'uses standard upgrader for post 3.0 upgrades' do
      Beaker::Options::PEVersionScraper.stub( :load_pe_version ).and_return( '3.1' )
      Beaker::Options::PEVersionScraper.stub( :load_pe_version_win ).and_return( '3.1' )
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ]  )
      subject.stub( :options ).and_return( {} )
      version = version_win = '3.1'
      path = "/path/to/upgradepkg"
      subject.should_receive( :do_install ).with( hosts, { :type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win => version_win } )
      subject.upgrade_pe( path )
    end

    it 'updates pe_ver post upgrade' do
      Beaker::Options::PEVersionScraper.stub( :load_pe_version ).and_return( '2.8' )
      Beaker::Options::PEVersionScraper.stub( :load_pe_version_win ).and_return( '2.8' )
      subject.stub( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      subject.stub( :options ).and_return( {} )
      version = version_win = '2.8'
      path = "/path/to/upgradepkg"
      subject.should_receive( :do_install ).with( hosts, { :type => :upgrade, :pe_dir => path, :pe_ver => version, :pe_ver_win => version_win, :installer => 'puppet-enterprise-upgrader' } )
      subject.upgrade_pe( path )
      hosts.each do |h|
        expect( h['pe_ver'] ).to be === '2.8'
      end
    end

  end
end
