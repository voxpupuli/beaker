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

  describe 'sorted_hosts' do
    it 'can reorder so that the master comes first' do
      allow( subject ).to receive( :hosts ).and_return( hosts_sorted )
      expect( subject.sorted_hosts ).to be === hosts
    end

    it 'leaves correctly ordered hosts alone' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      expect( subject.sorted_hosts ).to be === hosts
    end

    it 'does not allow nil entries' do
      allow( subject ).to receive( :options ).and_return( { :masterless => true } )
      masterless_host = [basic_hosts[0]]
      allow( subject ).to receive( :hosts ).and_return( masterless_host )
      expect( subject.sorted_hosts ).to be === masterless_host
    end
  end

  describe 'installer_cmd' do

    it 'generates a windows PE install command for a windows host' do
      winhost['dist'] = 'puppet-enterprise-3.0'
      allow( subject ).to receive( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2], winhost ] )
      allow( winhost ).to receive( :is_cygwin?).and_return(true)
      expect( subject.installer_cmd( winhost, {} ) ).to be === "cd /tmp && cmd /C 'start /w msiexec.exe /qn /L*V tmp.log /i puppet-enterprise-3.0.msi PUPPET_MASTER_SERVER=vm1 PUPPET_AGENT_CERTNAME=winhost'"
    end

    it 'generates a unix PE install command for a unix host' do
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp/puppet-enterprise-3.1.0-rc0-230-g36c9e5c-debian-7-i386 && ./puppet-enterprise-installer -a /tmp/answers"
    end

    it 'generates a unix PE frictionless install command for a unix host with role "frictionless"' do
      allow( subject ).to receive( :version_is_less ).and_return( false )
      allow( subject ).to receive( :master ).and_return( 'testmaster' )
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['roles'] = ['frictionless']
      expect( subject.installer_cmd( the_host, {} ) ).to be ===  "cd /tmp && curl --tlsv1 -kO https://testmaster:8140/packages/3.0/install.bash && bash install.bash"
    end

    it 'generates a unix PE frictionless install command for a unix host with role "frictionless" and "frictionless_options"' do
      allow( subject ).to receive( :version_is_less ).and_return( false )
      allow( subject ).to receive( :master ).and_return( 'testmaster' )
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['roles'] = ['frictionless']
      the_host['frictionless_options'] = { 'main' => { 'dns_alt_names' => 'puppet' } }
      expect( subject.installer_cmd( the_host, {} ) ).to be ===  "cd /tmp && curl --tlsv1 -kO https://testmaster:8140/packages/3.0/install.bash && bash install.bash main:dns_alt_names=puppet"
    end

    it 'generates a osx PE install command for a osx host' do
      the_host = machost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp && hdiutil attach .dmg && installer -pkg /Volumes/puppet-enterprise-3.0/puppet-enterprise-installer-3.0.pkg -target /"
    end

    it 'generates an EOS PE install command for an EOS host' do
      the_host = eoshost.dup
      commands = ['enable', "extension puppet-enterprise-#{the_host['pe_ver']}-#{the_host['platform']}.swix"]
      command = commands.join("\n")
      expect( subject.installer_cmd( the_host, {} ) ).to be === "Cli -c '#{command}'"
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
      allow( subject ).to receive( :version_is_less ).and_return( false )
      allow( subject ).to receive( :master ).and_return( 'testmaster' )
      the_host = unixhost.dup
      the_host['pe_installer'] = 'puppet-enterprise-installer'
      the_host['roles'] = ['frictionless']
      the_host[:pe_debug] = true
      expect( subject.installer_cmd( the_host, {} ) ).to be === "cd /tmp && curl --tlsv1 -kO https://testmaster:8140/packages/3.0/install.bash && bash -x install.bash"
    end

  end


  describe 'fetch_pe' do

    it 'can push a local PE .tar.gz to a host and unpack it' do
      allow( File ).to receive( :directory? ).and_return( true ) #is local
      allow( File ).to receive( :exists? ).and_return( true ) #is a .tar.gz
      unixhost['pe_dir'] = '/local/file/path'
      allow( subject ).to receive( :scp_to ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar.gz'
      expect( subject ).to receive( :scp_to ).with( unixhost, "#{ path }/#{ filename }#{ extension }", "#{ unixhost['working_dir'] }/#{ filename }#{ extension }" ).once
      expect( subject ).to receive( :on ).with( unixhost, /gunzip/ ).once
      expect( subject ).to receive( :on ).with( unixhost, /tar -xvf/ ).once
      subject.fetch_pe( [unixhost], {} )
    end

    it 'can download a PE .tar from a URL to a host and unpack it' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ) do |arg|
        if arg =~ /.tar.gz/ #there is no .tar.gz link, only a .tar
          false
        else
          true
        end
      end
      allow( subject ).to receive( :on ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar'
      expect( subject ).to receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; curl #{ path }/#{ filename }#{ extension } | tar -xvf -" ).once
      subject.fetch_pe( [unixhost], {} )
    end

    it 'can download a PE .tar from a URL to #fetch_and_push_pe' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ) do |arg|
        if arg =~ /.tar.gz/ #there is no .tar.gz link, only a .tar
          false
        else
          true
        end
      end
      allow( subject ).to receive( :on ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar'
      expect( subject ).to receive( :fetch_and_push_pe ).with( unixhost, anything, filename, extension ).once
      expect( subject ).to receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; cat #{ filename }#{ extension } | tar -xvf -" ).once
      subject.fetch_pe( [unixhost], {:fetch_local_then_push_to_host => true} )
    end

    it 'can download a PE .tar.gz from a URL to a host and unpack it' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ).and_return( true ) #is a tar.gz
      allow( subject ).to receive( :on ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar.gz'
      expect( subject ).to receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; curl #{ path }/#{ filename }#{ extension } | gunzip | tar -xvf -" ).once
      subject.fetch_pe( [unixhost], {} )
    end

    it 'can download a PE .tar.gz from a URL to #fetch_and_push_pe' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ).and_return( true ) #is a tar.gz
      allow( subject ).to receive( :on ).and_return( true )

      path = unixhost['pe_dir']
      filename = "#{ unixhost['dist'] }"
      extension = '.tar.gz'
      expect( subject ).to receive( :fetch_and_push_pe ).with( unixhost, anything, filename, extension ).once
      expect( subject ).to receive( :on ).with( unixhost, "cd #{ unixhost['working_dir'] }; cat #{ filename }#{ extension } | gunzip | tar -xvf -" ).once
      subject.fetch_pe( [unixhost], {:fetch_local_then_push_to_host => true} )
    end

    it 'can download a PE .swix from a URL to an EOS host and unpack it' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ).and_return( true ) #is a tar.gz
      allow( subject ).to receive( :on ).and_return( true )

      path = eoshost['pe_dir']
      filename = "#{ eoshost['dist'] }"
      extension = '.swix'
      commands = ['enable', "copy #{path}/#{filename}#{extension} extension:"]
      command = commands.join("\n")
      expect( subject ).to receive( :on ).with( eoshost, "Cli -c '#{command}'" ).once
      subject.fetch_pe( [eoshost], {} )
    end

    it 'can push a local PE package to a windows host' do
      allow( File ).to receive( :directory? ).and_return( true ) #is local
      allow( File ).to receive( :exists? ).and_return( true ) #is present
      winhost['dist'] = 'puppet-enterprise-3.0'
      allow( subject ).to receive( :scp_to ).and_return( true )

      path = winhost['pe_dir']
      filename = "puppet-enterprise-#{ winhost['pe_ver'] }"
      extension = '.msi'
      expect( subject ).to receive( :scp_to ).with( winhost, "#{ path }/#{ filename }#{ extension }", "#{ winhost['working_dir'] }/#{ filename }#{ extension }" ).once
      subject.fetch_pe( [winhost], {} )

    end

    it 'can download a PE dmg from a URL to a mac host' do
      allow( File ).to receive( :directory? ).and_return( false ) #is not local
      allow( subject ).to receive( :link_exists? ).and_return( true ) #is  not local
      allow( subject ).to receive( :on ).and_return( true )

      path = machost['pe_dir']
      filename = "#{ machost['dist'] }"
      extension = '.dmg'
      expect( subject ).to receive( :on ).with( machost, "cd #{ machost['working_dir'] }; curl -O #{ path }/#{ filename }#{ extension }" ).once
      subject.fetch_pe( [machost], {} )
    end

    it 'can push a PE dmg to a mac host' do
      allow( File ).to receive( :directory? ).and_return( true ) #is local
      allow( File ).to receive( :exists? ).and_return( true ) #is present
      allow( subject ).to receive( :scp_to ).and_return( true )

      path = machost['pe_dir']
      filename = "#{ machost['dist'] }"
      extension = '.dmg'
      expect( subject ).to receive( :scp_to ).with( machost, "#{ path }/#{ filename }#{ extension }", "#{ machost['working_dir'] }/#{ filename }#{ extension }" ).once
      subject.fetch_pe( [machost], {} )
    end

    it "does nothing for a frictionless agent for PE >= 3.2.0" do
      unixhost['roles'] << 'frictionless'
      unixhost['pe_ver'] = '3.2.0'

      expect( subject).to_not receive(:scp_to)
      expect( subject).to_not receive(:on)
      allow( subject ).to receive(:version_is_less).with('3.2.0', '3.2.0').and_return(false)
      subject.fetch_pe( [unixhost], {} )
    end
  end

  describe 'do_install' do
    it 'can perform a simple installation' do
      allow( subject ).to receive( :on ).and_return( Beaker::Result.new( {}, '' ) )
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :create_remote_file ).and_return( true )
      allow( subject ).to receive( :sign_certificate_for ).and_return( true )
      allow( subject ).to receive( :stop_agent_on ).and_return( true )
      allow( subject ).to receive( :sleep_until_puppetdb_started ).and_return( true )
      allow( subject ).to receive( :version_is_less ).with('3.0', '4.0').and_return( true )
      allow( subject ).to receive( :version_is_less ).with('3.0', '3.4').and_return( true )
      allow( subject ).to receive( :version_is_less ).with('3.0', '3.0').and_return( false )
      allow( subject ).to receive( :version_is_less ).with('3.0', '3.4').and_return( true )
      allow( subject ).to receive( :wait_for_host_in_dashboard ).and_return( true )
      allow( subject ).to receive( :puppet_agent ) do |arg|
        "puppet agent #{arg}"
      end
      allow( subject ).to receive( :puppet ) do |arg|
        "puppet #{arg}"
      end

      allow( subject ).to receive( :hosts ).and_return( hosts )
      #create answers file per-host, except windows
      expect( subject ).to receive( :create_remote_file ).with( hosts[0], /answers/, /q/ ).once
      #run installer on all hosts
      expect( subject ).to receive( :on ).with( hosts[0], /puppet-enterprise-installer/ ).once
      expect( subject ).to receive( :on ).with( hosts[1], /msiexec.exe/ ).once
      expect( subject ).to receive( :on ).with( hosts[2], / hdiutil attach puppet-enterprise-3.0-osx-10.9-x86_64.dmg && installer -pkg \/Volumes\/puppet-enterprise-3.0\/puppet-enterprise-installer-3.0.pkg -target \// ).once
      expect( subject ).to receive( :on ).with( hosts[3], /^Cli/ ).once
      #does extra mac/EOS specific commands
      expect( subject ).to receive( :on ).with( hosts[2], /puppet config set server/ ).once
      expect( subject ).to receive( :on ).with( hosts[3], /puppet config set server/ ).once
      expect( subject ).to receive( :on ).with( hosts[2], /puppet config set certname/ ).once
      expect( subject ).to receive( :on ).with( hosts[3], /puppet config set certname/ ).once
      expect( subject ).to receive( :on ).with( hosts[2], /puppet agent -t/, :acceptable_exit_codes => [1] ).once
      expect( subject ).to receive( :on ).with( hosts[3], /puppet agent -t/, :acceptable_exit_codes => [0, 1] ).once
      #sign certificate per-host
      expect( subject ).to receive( :sign_certificate_for ).with( hosts[0] ).once
      expect( subject ).to receive( :sign_certificate_for ).with( hosts[1] ).once
      expect( subject ).to receive( :sign_certificate_for ).with( hosts[2] ).once
      expect( subject ).to receive( :sign_certificate_for ).with( hosts[3] ).once
      #stop puppet agent on all hosts
      expect( subject ).to receive( :stop_agent_on ).with( hosts[0] ).once
      expect( subject ).to receive( :stop_agent_on ).with( hosts[1] ).once
      expect( subject ).to receive( :stop_agent_on ).with( hosts[2] ).once
      expect( subject ).to receive( :stop_agent_on ).with( hosts[3] ).once
      #wait for puppetdb to start
      expect( subject ).to receive( :sleep_until_puppetdb_started ).with( hosts[0] ).once
      #run each puppet agent once
      expect( subject ).to receive( :on ).with( hosts[0], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).once
      expect( subject ).to receive( :on ).with( hosts[1], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).once
      expect( subject ).to receive( :on ).with( hosts[2], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).once
      expect( subject ).to receive( :on ).with( hosts[3], /puppet agent -t/, :acceptable_exit_codes => [0,2] ).once
      #run rake task on dashboard
      expect( subject ).to receive( :on ).with( hosts[0], /\/opt\/puppet\/bin\/rake -sf \/opt\/puppet\/share\/puppet-dashboard\/Rakefile .* RAILS_ENV=production/ ).once
      #wait for all hosts to appear in the dashboard
      #run puppet agent now that installation is complete
      expect( subject ).to receive( :on ).with( hosts, /puppet agent/, :acceptable_exit_codes => [0,2] ).once
      subject.do_install( hosts, opts )
    end

    it 'can perform a masterless installation' do
      hosts = make_hosts({
        :pe_ver => '3.0',
        :roles => ['agent']
      }, 1)

      allow( subject ).to receive( :hosts ).and_return( hosts )
      allow( subject ).to receive( :options ).and_return({ :masterless => true })
      allow( subject ).to receive( :on ).and_return( Beaker::Result.new( {}, '' ) )
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :create_remote_file ).and_return( true )
      allow( subject ).to receive( :stop_agent_on ).and_return( true )
      allow( subject ).to receive( :version_is_less ).with(anything, '3.2.0').exactly(hosts.length + 1).times.and_return( false )

      expect( subject ).to receive( :on ).with( hosts[0], /puppet-enterprise-installer/ ).once
      expect( subject ).to receive( :create_remote_file ).with( hosts[0], /answers/, /q/ ).once
      expect( subject ).to_not receive( :sign_certificate_for )
      expect( subject ).to receive( :stop_agent_on ).with( hosts[0] ).once
      expect( subject ).to_not receive( :sleep_until_puppetdb_started )
      expect( subject ).to_not receive( :wait_for_host_in_dashboard )
      expect( subject ).to_not receive( :on ).with( hosts[0], /puppet agent -t/, :acceptable_exit_codes => [0,2] )
      subject.do_install( hosts, opts)
    end
  end

  describe 'do_higgs_install' do

    before :each do
      my_time = double( "time double" )
      allow( my_time ).to receive( :strftime ).and_return( "2014-07-01_15.27.53" )
      allow( Time ).to receive( :new ).and_return( my_time )

      hosts[0]['working_dir'] = "tmp/2014-07-01_15.27.53"
      hosts[0]['dist'] = 'dist'
      hosts[0]['pe_installer'] = 'pe-installer'
      allow( hosts[0] ).to receive( :tmpdir ).and_return( "/tmp/2014-07-01_15.27.53" )

      @fail_result = Beaker::Result.new( {}, '' )
      @fail_result.stdout = "No match here"
      @success_result = Beaker::Result.new( {}, '' )
      @success_result.stdout = "Please go to https://website in your browser to continue installation"
    end

    it 'can perform a simple installation' do
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :sleep ).and_return( true )

      allow( subject ).to receive( :hosts ).and_return( hosts )

      #run higgs installer command
      expect( subject ).to receive( :on ).with( hosts[0],
                                         "cd /tmp/2014-07-01_15.27.53/puppet-enterprise-3.0-linux ; nohup ./pe-installer <<<Y > higgs_2014-07-01_15.27.53.log 2>&1 &",
                                        opts ).once
      #check to see if the higgs installation has proceeded correctly, works on second check
      expect( subject ).to receive( :on ).with( hosts[0], /cat #{hosts[0]['higgs_file']}/, { :accept_all_exit_codes => true }).and_return( @fail_result, @success_result )
      subject.do_higgs_install( hosts[0], opts )
    end

    it 'fails out after checking installation log 10 times' do
      allow( subject ).to receive( :fetch_pe ).and_return( true )
      allow( subject ).to receive( :sleep ).and_return( true )

      allow( subject ).to receive( :hosts ).and_return( hosts )

      #run higgs installer command
      expect( subject ).to receive( :on ).with( hosts[0],
                                         "cd /tmp/2014-07-01_15.27.53/puppet-enterprise-3.0-linux ; nohup ./pe-installer <<<Y > higgs_2014-07-01_15.27.53.log 2>&1 &",
                                        opts ).once
      #check to see if the higgs installation has proceeded correctly, works on second check
      expect( subject ).to receive( :on ).with( hosts[0], /cat #{hosts[0]['higgs_file']}/, { :accept_all_exit_codes => true }).exactly(10).times.and_return( @fail_result )
      expect{ subject.do_higgs_install( hosts[0], opts ) }.to raise_error
    end

  end

  describe 'install_pe' do

    it 'calls do_install with sorted hosts' do
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :hosts ).and_return( hosts_sorted )
      allow( subject ).to receive( :do_install ).and_return( true )
      expect( subject ).to receive( :do_install ).with( hosts, {} )
      subject.install_pe
    end

    it 'fills in missing pe_ver' do
      hosts.each do |h|
        h['pe_ver'] = nil
      end
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '2.8' )
      allow( subject ).to receive( :hosts ).and_return( hosts_sorted )
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :do_install ).and_return( true )
      expect( subject ).to receive( :do_install ).with( hosts, {} )
      subject.install_pe
      hosts.each do |h|
        expect( h['pe_ver'] ).to be === '2.8'
      end
    end
  end

  describe 'install_higgs' do
    it 'fills in missing pe_ver' do
      hosts[0]['pe_ver'] = nil
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '2.8' )
      allow( subject ).to receive( :hosts ).and_return( [ hosts[1], hosts[0], hosts[2] ] )
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :do_higgs_install ).and_return( true )
      expect( subject ).to receive( :do_higgs_install ).with( hosts[0], {} )
      subject.install_higgs
      expect( hosts[0]['pe_ver'] ).to be === '2.8'
    end

  end

  describe 'upgrade_pe' do

    it 'calls puppet-enterprise-upgrader for pre 3.0 upgrades' do
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '2.8' )
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version_win ).and_return( '2.8' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      allow( subject ).to receive( :hosts ).and_return( the_hosts )
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :version_is_less ).with('3.0', '3.4.0').and_return( true )
      allow( subject ).to receive( :version_is_less ).with('2.8', '3.0').and_return( true )
      version = version_win = '2.8'
      path = "/path/to/upgradepkg"
      expect( subject ).to receive( :do_install ).with( the_hosts, {:type=>:upgrade, :set_console_password=>true} )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_installer'] ).to be === 'puppet-enterprise-upgrader'
      end
    end

    it 'uses standard upgrader for post 3.0 upgrades' do
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '3.1' )
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version_win ).and_return( '3.1' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      allow( subject ).to receive( :hosts ).and_return( the_hosts )
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :version_is_less ).with('3.0', '3.4.0').and_return( true )
      allow( subject ).to receive( :version_is_less ).with('3.1', '3.0').and_return( false )
      version = version_win = '3.1'
      path = "/path/to/upgradepkg"
      expect( subject ).to receive( :do_install ).with( the_hosts, {:type=>:upgrade, :set_console_password=>true} )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_installer'] ).to be nil
      end
    end

    it 'updates pe_ver post upgrade' do
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version ).and_return( '2.8' )
      allow( Beaker::Options::PEVersionScraper ).to receive( :load_pe_version_win ).and_return( '2.8' )
      the_hosts = [ hosts[0].dup, hosts[1].dup, hosts[2].dup ]
      allow( subject ).to receive( :hosts ).and_return( the_hosts )
      allow( subject ).to receive( :options ).and_return( {} )
      allow( subject ).to receive( :version_is_less ).with('3.0', '3.4.0').and_return( true )
      allow( subject ).to receive( :version_is_less ).with('2.8', '3.0').and_return( true )
      version = version_win = '2.8'
      path = "/path/to/upgradepkg"
      expect( subject ).to receive( :do_install ).with( the_hosts, {:type=>:upgrade, :set_console_password=>true} )
      subject.upgrade_pe( path )
      the_hosts.each do |h|
        expect( h['pe_ver'] ).to be === '2.8'
      end
    end

  end

  describe 'fetch_and_push_pe' do

    it 'fetches the file' do
      allow( subject ).to receive( :scp_to )

      path = 'abcde/fg/hij'
      filename = 'pants'
      extension = '.txt'
      expect( subject ).to receive( :fetch_http_file ).with( path, "#{filename}#{extension}", 'tmp/pe' )
      subject.fetch_and_push_pe(unixhost, path, filename, extension)
    end

    it 'allows you to set the local copy dir' do
      allow( subject ).to receive( :scp_to )

      path = 'defg/hi/j'
      filename = 'pants'
      extension = '.txt'
      local_dir = '/root/domes'
      expect( subject ).to receive( :fetch_http_file ).with( path, "#{filename}#{extension}", local_dir )
      subject.fetch_and_push_pe(unixhost, path, filename, extension, local_dir)
    end

    it 'scp\'s to the host' do
      allow( subject ).to receive( :fetch_http_file )

      path = 'abcde/fg/hij'
      filename = 'pants'
      extension = '.txt'
      expect( subject ).to receive( :scp_to ).with( unixhost, "tmp/pe/#{filename}#{extension}", unixhost['working_dir'] )
      subject.fetch_and_push_pe(unixhost, path, filename, extension)
    end

  end

end
