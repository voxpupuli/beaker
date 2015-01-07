require 'spec_helper'

describe Beaker do
  let( :options )        { make_opts.merge({ 'logger' => double().as_null_object }) }
  let( :ntpserver_set )  { "ntp_server_set" }
  let( :options_ntp )    { make_opts.merge({ 'ntp_server' => ntpserver_set }) }
  let( :ntpserver )      { Beaker::HostPrebuiltSteps::NTPSERVER }
  let( :apt_cfg )        { Beaker::HostPrebuiltSteps::APT_CFG }
  let( :ips_pkg_repo )   { Beaker::HostPrebuiltSteps::IPS_PKG_REPO }
  let( :sync_cmd )       { Beaker::HostPrebuiltSteps::ROOT_KEYS_SYNC_CMD }
  let( :windows_pkgs )   { Beaker::HostPrebuiltSteps::WINDOWS_PACKAGES }
  let( :unix_only_pkgs ) { Beaker::HostPrebuiltSteps::UNIX_PACKAGES }
  let( :sles_only_pkgs ) { Beaker::HostPrebuiltSteps::SLES_PACKAGES }
  let( :platform )       { @platform || 'unix' }
  let( :ip )             { "ip.address.0.0" }
  let( :stdout)          { @stdout || ip }
  let( :hosts )          { hosts = make_hosts( { :stdout => stdout, :platform => platform } )
                           hosts[0][:roles] = ['agent']
                           hosts[1][:roles] = ['master', 'dashboard', 'agent', 'database']
                           hosts[2][:roles] = ['agent']
                           hosts }
  let( :dummy_class )    { Class.new { include Beaker::HostPrebuiltSteps } }

  context 'timesync' do

    subject { dummy_class.new }

    it "can sync time on unix hosts" do
      hosts = make_hosts( { :platform => 'unix' } )

      expect( Beaker::Command ).to receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 3 ).times

      subject.timesync( hosts, options )
    end

    it "can retry on failure on unix hosts" do
      hosts = make_hosts( { :platform => 'unix', :exit_code => [1, 0] } )
      allow( subject ).to receive( :sleep ).and_return(true)

      expect( Beaker::Command ).to receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 6 ).times

      subject.timesync( hosts, options )
    end

    it "eventually gives up and raises an error when unix hosts can't be synched" do
      hosts = make_hosts( { :platform => 'unix', :exit_code => 1 } )
      allow( subject ).to receive( :sleep ).and_return(true)

      expect( Beaker::Command ).to receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 5 ).times

      expect{ subject.timesync( hosts, options ) }.to raise_error
    end

    it "can sync time on windows hosts" do
      hosts = make_hosts( { :platform => 'windows' } )

      expect( Beaker::Command ).to receive( :new ).with("w32tm /register").exactly( 3 ).times
      expect( Beaker::Command ).to receive( :new ).with("net start w32time").exactly( 3 ).times
      expect( Beaker::Command ).to receive( :new ).with("w32tm /config /manualpeerlist:#{ntpserver} /syncfromflags:manual /update").exactly( 3 ).times
      expect( Beaker::Command ).to receive( :new ).with("w32tm /resync").exactly( 3 ).times

      subject.timesync( hosts, options )

    end

    it "can sync time on Sles hosts" do
      hosts = make_hosts( { :platform => 'sles-13.1-x64' } )

      expect( Beaker::Command ).to receive( :new ).with("sntp #{ntpserver}").exactly( 3 ).times

      subject.timesync( hosts, options )

    end

    it "can set time server on unix hosts" do
      hosts = make_hosts( { :platform => 'unix' } )

      expect( Beaker::Command ).to receive( :new ).with("ntpdate -t 20 #{ntpserver_set}").exactly( 3 ).times

      subject.timesync( hosts, options_ntp )
    end

    it "can set time server on windows hosts" do
      hosts = make_hosts( { :platform => 'windows' } )

      expect( Beaker::Command ).to receive( :new ).with("w32tm /register").exactly( 3 ).times
      expect( Beaker::Command ).to receive( :new ).with("net start w32time").exactly( 3 ).times
      expect( Beaker::Command ).to receive( :new ).with("w32tm /config /manualpeerlist:#{ntpserver_set} /syncfromflags:manual /update").exactly( 3 ).times
      expect( Beaker::Command ).to receive( :new ).with("w32tm /resync").exactly( 3 ).times

      subject.timesync( hosts, options_ntp )

    end

    it "can set time server on Sles hosts" do
      hosts = make_hosts( { :platform => 'sles-13.1-x64' } )

      expect( Beaker::Command ).to receive( :new ).with("sntp #{ntpserver_set}").exactly( 3 ).times

      subject.timesync( hosts, options_ntp )

    end
  end

  context "epel_info_for!" do
    subject { dummy_class.new }

    it "can return the correct url for an el-6 host" do
      host = make_host( 'testhost', { :platform => Beaker::Platform.new('el-6-platform') } )

      expect( subject.epel_info_for( host, options )).to be === ["http://mirrors.kernel.org/fedora-epel/6", "i386", "epel-release-6-8.noarch.rpm"]
    end

    it "can return the correct url for an el-5 host" do
      host = make_host( 'testhost', { :platform => Beaker::Platform.new('el-5-platform') } )

      expect( subject.epel_info_for( host, options )).to be === ["http://mirrors.kernel.org/fedora-epel/5", "i386", "epel-release-5-4.noarch.rpm"]

    end

    it "raises an error on non el-5/6 host" do
      host = make_host( 'testhost', { :platform => Beaker::Platform.new('el-4-platform') } )

      expect{ subject.epel_info_for( host, options )}.to raise_error

    end

  end

  context "apt_get_update" do
    subject { dummy_class.new }

    it "can perform apt-get on ubuntu hosts" do
      host = make_host( 'testhost', { :platform => 'ubuntu' } )

      expect( Beaker::Command ).to receive( :new ).with("apt-get update").once

      subject.apt_get_update( host )

    end

    it "can perform apt-get on debian hosts" do
      host = make_host( 'testhost', { :platform => 'debian' } )

      expect( Beaker::Command ).to receive( :new ).with("apt-get update").once

      subject.apt_get_update( host )

    end

    it "can perform apt-get on cumulus hosts" do
      host = make_host( 'testhost', { :platform => 'cumulus' } )

      expect( Beaker::Command ).to receive( :new ).with("apt-get update").once

      subject.apt_get_update( host )

    end

    it "does nothing on non debian/ubuntu/cumulus hosts" do
      host = make_host( 'testhost', { :platform => 'windows' } )

      expect( Beaker::Command ).to receive( :new ).never

      subject.apt_get_update( host )

    end

  end

  context "copy_file_to_remote" do
    subject { dummy_class.new }

    it "can copy a file to a remote host" do
      content = "this is the content"
      tempfilepath = "/path/to/tempfile"
      filepath = "/path/to/file"
      host = make_host( 'testhost', { :platform => 'windows' })
      tempfile = double( 'tempfile' )
      allow( tempfile ).to receive( :path ).and_return( tempfilepath )
      allow( Tempfile ).to receive( :open ).and_yield( tempfile )
      file = double( 'file' )
      allow( File ).to receive( :open ).and_yield( file )

      expect( file ).to receive( :puts ).with( content ).once
      expect( host ).to receive( :do_scp_to ).with( tempfilepath, filepath, subject.instance_variable_get( :@options ) ).once

      subject.copy_file_to_remote(host, filepath, content)

    end

  end

  context "proxy_config" do
    subject { dummy_class.new }

    it "correctly configures ubuntu hosts" do
      hosts = make_hosts( { :platform => 'ubuntu', :exit_code => 1 } )

      expect( Beaker::Command ).to receive( :new ).with( "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi" ).exactly( 3 )
      hosts.each do |host|
        expect( subject ).to receive( :copy_file_to_remote ).with( host, '/etc/apt/apt.conf', apt_cfg ).once
        expect( subject ).to receive( :apt_get_update ).with( host ).once
      end

      subject.proxy_config( hosts, options )

    end

    it "correctly configures debian hosts" do
      hosts = make_hosts( { :platform => 'debian' } )

      expect( Beaker::Command ).to receive( :new ).with( "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi" ).exactly( 3 ).times
      hosts.each do |host|
        expect( subject ).to receive( :copy_file_to_remote ).with( host, '/etc/apt/apt.conf', apt_cfg ).once
        expect( subject ).to receive( :apt_get_update ).with( host ).once
      end

      subject.proxy_config( hosts, options )

    end

    it "correctly configures cumulus hosts" do
      hosts = make_hosts( { :platform => 'cumulus' } )

      expect( Beaker::Command ).to receive( :new ).with( "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi" ).exactly( 3 ).times
      hosts.each do |host|
        expect( subject ).to receive( :copy_file_to_remote ).with( host, '/etc/apt/apt.conf', apt_cfg ).once
        expect( subject ).to receive( :apt_get_update ).with( host ).once
      end

      subject.proxy_config( hosts, options )

    end

    it "correctly configures solaris-11 hosts" do
      hosts = make_hosts( { :platform => 'solaris-11' } )

      expect( Beaker::Command ).to receive( :new ).with( "/usr/bin/pkg unset-publisher solaris || :" ).exactly( 3 ).times
      hosts.each do |host|
        expect( Beaker::Command ).to receive( :new ).with( "/usr/bin/pkg set-publisher -g %s solaris" % ips_pkg_repo ).once
      end

      subject.proxy_config( hosts, options )

    end

    it "does nothing for non ubuntu/debian/cumulus/solaris-11 hosts" do
      hosts = make_hosts( { :platform => 'windows' } )

      expect( Beaker::Command ).to receive( :new ).never

      subject.proxy_config( hosts, options )

    end
  end

  context "add_el_extras" do
    subject { dummy_class.new }

    it "add extras for el-5/6 hosts" do

      hosts = make_hosts( { :platform => Beaker::Platform.new('el-5-arch'), :exit_code => 1 }, 6 )
      hosts[0][:platform] = Beaker::Platform.new('el-6-arch')
      hosts[1][:platform] = Beaker::Platform.new('centos-6-arch')
      hosts[2][:platform] = Beaker::Platform.new('scientific-6-arch')
      hosts[3][:platform] = Beaker::Platform.new('redhat-6-arch')
      hosts[4][:platform] = Beaker::Platform.new('oracle-5-arch')

      expect( Beaker::Command ).to receive( :new ).with("rpm -qa | grep epel-release").exactly( 6 ).times
      expect( Beaker::Command ).to receive( :new ).with("rpm -i http://mirrors.kernel.org/fedora-epel/6/i386/epel-release-6-8.noarch.rpm").exactly( 4 ).times
      expect( Beaker::Command ).to receive( :new ).with("rpm -i http://mirrors.kernel.org/fedora-epel/5/i386/epel-release-5-4.noarch.rpm").exactly( 2 ).times
      expect( Beaker::Command ).to receive( :new ).with("sed -i -e 's;#baseurl.*$;baseurl=http://mirrors\\.kernel\\.org/fedora\\-epel/6/$basearch;' /etc/yum.repos.d/epel.repo").exactly( 4 ).times
      expect( Beaker::Command ).to receive( :new ).with("sed -i -e 's;#baseurl.*$;baseurl=http://mirrors\\.kernel\\.org/fedora\\-epel/5/$basearch;' /etc/yum.repos.d/epel.repo").exactly( 2 ).times
      expect( Beaker::Command ).to receive( :new ).with("sed -i -e '/mirrorlist/d' /etc/yum.repos.d/epel.repo").exactly( 6 ).times
      expect( Beaker::Command ).to receive( :new ).with("yum clean all && yum makecache").exactly( 6 ).times

      subject.add_el_extras( hosts, options )

    end

    it "should do nothing for non el-5/6 hosts" do
      hosts = make_hosts( { :platform => Beaker::Platform.new('windows-version-arch') } )

      expect( Beaker::Command ).to receive( :new ).never

      subject.add_el_extras( hosts, options )

    end
  end

  context "sync_root_keys" do
    subject { dummy_class.new }

    it "can sync keys on a solaris/eos host" do
      @platform = 'solaris'

      expect( Beaker::Command ).to receive( :new ).with( sync_cmd % "bash" ).exactly( 3 ).times

      subject.sync_root_keys( hosts, options )

    end

    it "can sync keys on a non-solaris host" do

      expect( Beaker::Command ).to receive( :new ).with( sync_cmd % "env PATH=/usr/gnu/bin:$PATH bash" ).exactly( 3 ).times

      subject.sync_root_keys( hosts, options )

    end

  end

  context "validate_host" do
    subject { dummy_class.new }

    it "can validate unix hosts" do

      hosts.each do |host|
        unix_only_pkgs.each do |pkg|
          expect( host ).to receive( :check_for_package ).with( pkg ).once.and_return( false )
          expect( host ).to receive( :install_package ).with( pkg ).once
        end
      end

      subject.validate_host(hosts, options)

    end

    it "can validate windows hosts" do
      @platform = 'windows'

      hosts.each do |host|
        windows_pkgs.each do |pkg|
          expect( host ).to receive( :check_for_package ).with( pkg ).once.and_return( false )
          expect( host ).to receive( :install_package ).with( pkg ).once
        end
      end

      subject.validate_host(hosts, options)

    end

    it "can validate SLES hosts" do
      @platform = 'sles-13.1-x64'

      hosts.each do |host|
        sles_only_pkgs.each do |pkg|
          expect( host ).to receive( :check_for_package).with( pkg ).once.and_return( false )
          expect( host ).to receive( :install_package ).with( pkg ).once
        end

      end

      subject.validate_host(hosts, options)

    end
  end

  context 'get_domain_name' do
    subject { dummy_class.new }

    it "can find the domain for a host" do
      host = make_host('name', { :stdout => "domain labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" } )

      expect( Beaker::Command ).to receive( :new ).with( "cat /etc/resolv.conf" ).once

      expect( subject.get_domain_name( host ) ).to be === "labs.lan"

    end

    it "can find the search for a host" do
      host = make_host('name', { :stdout => "search labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" } )

      expect( Beaker::Command ).to receive( :new ).with( "cat /etc/resolv.conf" ).once

      expect( subject.get_domain_name( host ) ).to be === "labs.lan"

    end
  end

  context "get_ip" do
    subject { dummy_class.new }

    it "can exec the get_ip command" do
      host = make_host('name', { :stdout => "192.168.2.130\n" } )

      expect( Beaker::Command ).to receive( :new ).with( "ip a|awk '/global/{print$2}' | cut -d/ -f1 | head -1" ).once

      expect( subject.get_ip( host ) ).to be === "192.168.2.130"

    end

  end

  context "set_etc_hosts" do
    subject { dummy_class.new }

    it "can set the /etc/hosts string on a host" do
      host = make_host('name', {})
      etc_hosts = "127.0.0.1  localhost\n192.168.2.130 pe-ubuntu-lucid\n192.168.2.128 pe-centos6\n192.168.2.131 pe-debian6"

      expect( Beaker::Command ).to receive( :new ).with( "echo '#{etc_hosts}' > /etc/hosts" ).once
      expect( host ).to receive( :exec ).once

      subject.set_etc_hosts(host, etc_hosts)
    end

  end

  context "package_proxy" do

    subject { dummy_class.new }
    proxyurl = "http://192.168.2.100:3128"

    it "can set proxy config on a debian/ubuntu/cumulus host" do
      host = make_host('name', { :platform => 'cumulus' } )

      expect( Beaker::Command ).to receive( :new ).with( "echo 'Acquire::http::Proxy \"#{proxyurl}/\";' >> /etc/apt/apt.conf.d/10proxy" ).once
      expect( host ).to receive( :exec ).once

      subject.package_proxy(host, options.merge( {'package_proxy' => proxyurl}) )
    end

    it "can set proxy config on a centos host" do
      host = make_host('name', { :platform => 'centos' } )

      expect( Beaker::Command ).to receive( :new ).with( "echo 'proxy=#{proxyurl}/' >> /etc/yum.conf" ).once
      expect( host ).to receive( :exec ).once

      subject.package_proxy(host, options.merge( {'package_proxy' => proxyurl}) )
    end

  end

  context "set_env" do
    subject { dummy_class.new }

    it "can set the environment on a windows host" do
      commands = [
        "echo '\nPermitUserEnvironment yes' >> /etc/sshd_config",
        "cygrunsrv -E sshd",
        "cygrunsrv -S sshd"
      ]
      set_env_helper('windows', commands)
    end

    it "can set the environment on an OS X host" do
      commands = [
        "echo '\nPermitUserEnvironment yes' >> /etc/sshd_config",
        "launchctl unload /System/Library/LaunchDaemons/ssh.plist",
        "launchctl load /System/Library/LaunchDaemons/ssh.plist"
      ]
      set_env_helper('osx', commands)
    end

    it "can set the environment on an ssh-based linux host" do
      commands = [
        "echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config",
        "service ssh restart"
      ]
      set_env_helper('ubuntu', commands)
    end

    it "can set the environment on an sshd-based linux host" do
      commands = [
          "echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config",
          "/sbin/service sshd restart"
      ]
      set_env_helper('eos', commands)
    end

    it "can set the environment on an sles host" do
      commands = [
        "echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config",
        "rcsshd restart"
      ]
      set_env_helper('sles', commands)
    end

    it "can set the environment on a solaris host" do
      commands = [
        "echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config",
        "svcadm restart svc:/network/ssh:default"
      ]
      set_env_helper('solaris', commands)
    end

    it "can set the environment on an aix host" do
      commands = [
        "echo '\nPermitUserEnvironment yes' >> /etc/ssh/sshd_config",
        "stopsrc -g ssh",
        "startsrc -g ssh"
      ]
      set_env_helper('aix', commands)
    end

    def set_env_helper(platform_name, host_specific_commands_array)
      host = make_host('name', {
          :platform     => platform_name,
          :ssh_env_file => 'ssh_env_file'
      } )
      opts = {
          :env1_key => :env1_value,
          :env2_key => :env2_value
      }

      expect( subject ).to receive( :construct_env ).and_return( opts )
      host_specific_commands_array.each do |command|
        expect( Beaker::Command ).to receive( :new ).with( command ).once
      end

      expect( Beaker::Command ).to receive( :new ).with( "mkdir -p #{Pathname.new(host[:ssh_env_file]).dirname}" ).once
      expect( Beaker::Command ).to receive( :new ).with( "chmod 0600 #{Pathname.new(host[:ssh_env_file]).dirname}" ).once
      expect( Beaker::Command ).to receive( :new ).with( "touch #{host[:ssh_env_file]}" ).once
      expect( host ).to receive( :add_env_var ).with( 'RUBYLIB', '$RUBYLIB' ).once
      expect( host ).to receive( :add_env_var ).with( 'PATH', '$PATH' ).once
      opts.each_pair do |key, value|
        expect( host ).to receive( :add_env_var ).with( key, value ).once
      end
      expect( host ).to receive( :add_env_var ).with( 'CYGWIN', 'nodosfilewarning' ).once if platform_name =~ /windows/
      expect( host ).to receive( :exec ).exactly( host_specific_commands_array.length + 3 ).times

      subject.set_env(host, options.merge( opts ))
    end

  end

end
