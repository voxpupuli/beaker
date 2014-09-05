require 'spec_helper'

describe Beaker do
  let( :options )        { make_opts.merge({ 'logger' => double().as_null_object }) }
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
  let( :dummy_class )    { Class.new { include Beaker::HostPrebuiltSteps
                                       include Beaker::DSL::Patterns } }

  context 'timesync' do

    subject { dummy_class.new }

    it "can sync time on unix hosts" do
      hosts = make_hosts( { :platform => 'unix' } )

      Beaker::Command.should_receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 3 ).times

      subject.timesync( hosts, options )
    end

    it "can retry on failure on unix hosts" do
      hosts = make_hosts( { :platform => 'unix', :exit_code => [1, 0] } )
      subject.stub( :sleep ).and_return(true)

      Beaker::Command.should_receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 6 ).times

      subject.timesync( hosts, options )
    end

    it "eventually gives up and raises an error when unix hosts can't be synched" do
      hosts = make_hosts( { :platform => 'unix', :exit_code => 1 } )
      subject.stub( :sleep ).and_return(true)

      Beaker::Command.should_receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 5 ).times

      expect{ subject.timesync( hosts, options ) }.to raise_error
    end

    it "can sync time on solaris-10 hosts" do
      hosts = make_hosts( { :platform => 'solaris-10' } )

      Beaker::Command.should_receive( :new ).with("sleep 10 && ntpdate -w #{ntpserver}").exactly( 3 ).times

      subject.timesync( hosts, options )

    end

    it "can sync time on windows hosts" do
      hosts = make_hosts( { :platform => 'windows' } )

      Beaker::Command.should_receive( :new ).with("w32tm /register").exactly( 3 ).times
      Beaker::Command.should_receive( :new ).with("net start w32time").exactly( 3 ).times
      Beaker::Command.should_receive( :new ).with("w32tm /config /manualpeerlist:#{ntpserver} /syncfromflags:manual /update").exactly( 3 ).times
      Beaker::Command.should_receive( :new ).with("w32tm /resync").exactly( 3 ).times

      subject.timesync( hosts, options )

    end

    it "can sync time on Sles hosts" do
      hosts = make_hosts( { :platform => 'sles-13.1-x64' } )

      Beaker::Command.should_receive( :new ).with("sntp #{ntpserver}").exactly( 3 ).times

      subject.timesync( hosts, options )

    end
  end

  context "epel_info_for!" do
    subject { dummy_class.new }
    
    it "can return the correct url for an el-6 host" do
      host = make_host( 'testhost', { :platform => 'el-6-platform' } )

      expect( subject.epel_info_for!( host )).to be === "http://mirror.itc.virginia.edu/fedora-epel/6/i386/epel-release-6-8.noarch.rpm"
    end

    it "can return the correct url for an el-5 host" do
      host = make_host( 'testhost', { :platform => 'el-5-platform' } )

      expect( subject.epel_info_for!( host )).to be === "http://archive.linux.duke.edu/pub/epel/5/i386/epel-release-5-4.noarch.rpm"

    end

    it "raises an error on non el-5/6 host" do
      host = make_host( 'testhost', { :platform => 'el-4-platform' } )

      expect{ subject.epel_info_for!( host )}.to raise_error

    end

  end

  context "apt_get_update" do
    subject { dummy_class.new }

    it "can perform apt-get on ubuntu hosts" do
      host = make_host( 'testhost', { :platform => 'ubuntu' } )

      Beaker::Command.should_receive( :new ).with("apt-get update").once

      subject.apt_get_update( host )

    end

    it "can perform apt-get on debian hosts" do
      host = make_host( 'testhost', { :platform => 'debian' } )

      Beaker::Command.should_receive( :new ).with("apt-get update").once

      subject.apt_get_update( host )

    end

    it "does nothing on non debian/ubuntu hosts" do
      host = make_host( 'testhost', { :platform => 'windows' } )

      Beaker::Command.should_receive( :new ).never

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
      tempfile.stub( :path ).and_return( tempfilepath )
      Tempfile.stub( :open ).and_yield( tempfile )
      file = double( 'file' )
      File.stub( :open ).and_yield( file )

      file.should_receive( :puts ).with( content ).once
      host.should_receive( :do_scp_to ).with( tempfilepath, filepath, subject.instance_variable_get( :@options ) ).once

      subject.copy_file_to_remote(host, filepath, content)

    end

  end

  context "proxy_config" do
    subject { dummy_class.new }
    
    it "correctly configures ubuntu hosts" do
      hosts = make_hosts( { :platform => 'ubuntu', :exit_code => 1 } )

      Beaker::Command.should_receive( :new ).with( "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi" ).exactly( 3 )
      hosts.each do |host|
        subject.should_receive( :copy_file_to_remote ).with( host, '/etc/apt/apt.conf', apt_cfg ).once
        subject.should_receive( :apt_get_update ).with( host ).once
      end

      subject.proxy_config( hosts, options )

    end

    it "correctly configures debian hosts" do
      hosts = make_hosts( { :platform => 'debian' } )

      Beaker::Command.should_receive( :new ).with( "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi" ).exactly( 3 ).times
      hosts.each do |host|
        subject.should_receive( :copy_file_to_remote ).with( host, '/etc/apt/apt.conf', apt_cfg ).once
        subject.should_receive( :apt_get_update ).with( host ).once
      end

      subject.proxy_config( hosts, options )

    end

    it "correctly configures solaris-11 hosts" do
      hosts = make_hosts( { :platform => 'solaris-11' } )

      Beaker::Command.should_receive( :new ).with( "/usr/bin/pkg unset-publisher solaris || :" ).exactly( 3 ).times
      hosts.each do |host|
        Beaker::Command.should_receive( :new ).with( "/usr/bin/pkg set-publisher -g %s solaris" % ips_pkg_repo ).once
      end

      subject.proxy_config( hosts, options )

    end

    it "does nothing for non ubuntu/debian/solaris-11 hosts" do
      hosts = make_hosts( { :platform => 'windows' } )
      
      Beaker::Command.should_receive( :new ).never

      subject.proxy_config( hosts, options )

    end
  end

  context "add_el_extras" do
    subject { dummy_class.new }

    it "add extras for el-5/6 hosts" do
      hosts = make_hosts( { :platform => 'el-5', :exit_code => 1 } )
      hosts[0][:platform] = 'el-6' 
      url = "http://el_extras_url"

      subject.stub( :epel_info_for! ).and_return( url )

      Beaker::Command.should_receive( :new ).with("rpm -qa | grep epel-release").exactly( 3 ).times
      Beaker::Command.should_receive( :new ).with("rpm -i #{url}").exactly( 3 ).times
      Beaker::Command.should_receive( :new ).with("yum clean all && yum makecache").exactly( 3 ).times

      subject.add_el_extras( hosts, options )

    end

    it "should do nothing for non el-5/6 hosts" do
      hosts = make_hosts( { :platform => 'windows' } )

      Beaker::Command.should_receive( :new ).never

      subject.add_el_extras( hosts, options )

    end
  end

  context "sync_root_keys" do
    subject { dummy_class.new }

    it "can sync keys on a solaris host" do
      @platform = 'solaris'

      Beaker::Command.should_receive( :new ).with( sync_cmd % "bash" ).exactly( 3 ).times

      subject.sync_root_keys( hosts, options )

    end

    it "can sync keys on a non-solaris host" do

      Beaker::Command.should_receive( :new ).with( sync_cmd % "env PATH=/usr/gnu/bin:$PATH bash" ).exactly( 3 ).times

      subject.sync_root_keys( hosts, options )

    end

  end

  context "validate_host" do
    subject { dummy_class.new }

    before(:each) do
      # Must reset additional_pkgs between each test as it hangs around
      #Beaker::HostPrebuiltSteps.class_variable_set(:@@additional_pkgs, [])
      Beaker::HostPrebuiltSteps.module_eval(%q{@@additional_pkgs = []})
    end

    it "can validate unix hosts" do

      hosts.each do |host|
        unix_only_pkgs.each do |pkg|
          host.should_receive( :check_for_package ).with( pkg ).once.and_return( false )
          host.should_receive( :install_package ).with( pkg ).once
        end
      end

      subject.validate_host(hosts, options)

    end

    it "can validate windows hosts" do
      @platform = 'windows'

      hosts.each do |host|
        windows_pkgs.each do |pkg|
          host.should_receive( :check_for_package ).with( pkg ).once.and_return( false )
          host.should_receive( :install_package ).with( pkg ).once
        end
      end

      subject.validate_host(hosts, options)

    end

    it "can validate SLES hosts" do
      @platform = 'sles-13.1-x64'

      hosts.each do |host|
        sles_only_pkgs.each do |pkg|
          host.should_receive( :check_for_package).with( pkg ).once.and_return( false )
          host.should_receive( :install_package ).with( pkg ).once
        end

      end

      subject.validate_host(hosts, options)

    end
  end

  context 'get_domain_name' do
    subject { dummy_class.new }

    it "can find the domain for a host" do
      host = make_host('name', { :stdout => "domain labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" } )

      Beaker::Command.should_receive( :new ).with( "cat /etc/resolv.conf" ).once

      expect( subject.get_domain_name( host ) ).to be === "labs.lan"

    end

    it "can find the search for a host" do
      host = make_host('name', { :stdout => "search labs.lan d.labs.net dc1.labs.net labs.com\nnameserver 10.16.22.10\nnameserver 10.16.22.11" } )

      Beaker::Command.should_receive( :new ).with( "cat /etc/resolv.conf" ).once

      expect( subject.get_domain_name( host ) ).to be === "labs.lan"

    end
  end

  context "get_ip" do
    subject { dummy_class.new }

    it "can exec the get_ip command" do
      host = make_host('name', { :stdout => "192.168.2.130\n" } )

      Beaker::Command.should_receive( :new ).with( "ip a|awk '/global/{print$2}' | cut -d/ -f1 | head -1" ).once

      expect( subject.get_ip( host ) ).to be === "192.168.2.130"

    end

  end

  context "set_etc_hosts" do
    subject { dummy_class.new }

    it "can set the /etc/hosts string on a host" do
      host = make_host('name', {})
      etc_hosts = "127.0.0.1  localhost\n192.168.2.130 pe-ubuntu-lucid\n192.168.2.128 pe-centos6\n192.168.2.131 pe-debian6"

      Beaker::Command.should_receive( :new ).with( "echo '#{etc_hosts}' > /etc/hosts" ).once
      host.should_receive( :exec ).once

      subject.set_etc_hosts(host, etc_hosts)
    end

  end

  context "package_proxy" do

    subject { dummy_class.new }
    proxyurl = "http://192.168.2.100:3128"

    it "can set proxy config on a debian/ubuntu host" do
      host = make_host('name', { :platform => 'ubuntu' } )

      Beaker::Command.should_receive( :new ).with( "echo 'Acquire::http::Proxy \"#{proxyurl}/\";' >> /etc/apt/apt.conf.d/10proxy" ).once
      host.should_receive( :exec ).once

      subject.package_proxy(host, options.merge( {'package_proxy' => proxyurl}) )
    end

    it "can set proxy config on a redhat/centos host" do
      host = make_host('name', { :platform => 'centos' } )

      Beaker::Command.should_receive( :new ).with( "echo 'proxy=#{proxyurl}/' >> /etc/yum.conf" ).once
      host.should_receive( :exec ).once

      subject.package_proxy(host, options.merge( {'package_proxy' => proxyurl}) )

    end

  end

end
