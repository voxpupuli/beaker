require 'spec_helper'

module Beaker
  module Utils
    describe NTPControl do
      let( :logger ) { double( 'logger' ).as_null_object }
      let( :defaults ) { Beaker::Options::OptionsHash.new.merge( { :logger => logger} ) }
      let( :options ) { @options ? defaults.merge( @options ) : defaults}

      let( :apt_cfg ) { Beaker::Utils::RepoControl::APT_CFG }
      let( :ips_pkg_repo ) { Beaker::Utils::RepoControl::IPS_PKG_REPO }

      let( :repo_control ) { Beaker::Utils::RepoControl.new( options, @hosts) }
      let( :vms ) { ['vm1', 'vm2', 'vm3'] }
      let( :snaps )  { ['snapshot1', 'snapshot2', 'snapshot3'] }

      def make_host name, snap, platform
        opts = Beaker::Options::OptionsHash.new.merge( { :logger => logger, 'HOSTS' => { name => { 'platform' => platform, :snapshot => snap } } } )
        Host.create( name, opts )
      end

      def make_hosts names, snaps, platform = 'unix'
        hosts = []
        names.zip(snaps).each do |vm, snap|
          hosts << make_host( vm, snap, platform )
        end
        hosts
      end

      before :each do
        result = mock( 'result' )
        result.stub( :stdio ).and_return( "success" )
        result.stub( :exit_code ).and_return( 1 )
        Host.any_instance.stub( :exec ) do
          result  
        end
      end

      context "epel_info_for!" do
        
        it "can return the correct url for an el-6 host" do
          host = make_host( 'el-6-host', 'snap', 'el-6-platform')

          expect( repo_control.epel_info_for!( host )).to be === "http://mirror.itc.virginia.edu/fedora-epel/6/i386/epel-release-6-8.noarch.rpm"
        end

        it "can return the correct url for an el-5 host" do
          host = make_host( 'el-5-host', 'snap', 'el-5-platform')

          expect( repo_control.epel_info_for!( host )).to be === "http://archive.linux.duke.edu/pub/epel/5/i386/epel-release-5-4.noarch.rpm"

        end

        it "raises an error on non el-5/6 host" do
          host = make_host( 'el-4-host', 'snap', 'el-4-platform')

          expect{ repo_control.epel_info_for!( host )}.to raise_error

        end

      end

      context "apt_get_update" do

        it "can perform apt-get on ubuntu hosts" do
          host = make_host( 'ubuntuhost', 'snap', 'ubuntu' )

          Command.should_receive( :new ).with("apt-get -y -f -m update").exactly( 1 ).times

          repo_control.apt_get_update( host )

        end

        it "can perform apt-get on debian hosts" do
          host = make_host( 'debianhost', 'snap', 'debian' )

          Command.should_receive( :new ).with("apt-get -y -f -m update").exactly( 1 ).times

          repo_control.apt_get_update( host )

        end

        it "does nothing on non debian/ubuntu hosts" do
          host = make_host( 'windowshost', 'snap', 'windows' )

          Command.should_receive( :new ).exactly( 0 ).times

          repo_control.apt_get_update( host )

        end

      end

      context "copy_file_to_remote" do

        it "can copy a file to a remote host" do
          content = "this is the content"
          tempfilepath = "/path/to/tempfile"
          filepath = "/path/to/file"
          host = make_host( "host", "snap", "windows")
          tempfile = mock( 'tempfile' )
          tempfile.stub( :path ).and_return( tempfilepath )
          Tempfile.stub( :open ).and_yield( tempfile )
          file = mock( 'file' )
          File.stub( :open ).and_yield( file )

          file.should_receive( :puts ).with( content ).exactly( 1 ).times
          host.should_receive( :do_scp_to ).with( tempfilepath, filepath, options ).exactly( 1 ).times

          repo_control.copy_file_to_remote(host, filepath, content)

        end


      end

      context "proxy_config" do
        
        it "correctly configures ubuntu hosts" do
          @hosts = make_hosts( vms, snaps, 'ubuntu' )

          Command.should_receive( :new ).with( "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi" ).exactly( 3 ).times
          @hosts.each do |host|
            repo_control.should_receive( :copy_file_to_remote ).with( host, '/etc/apt/apt.conf', apt_cfg ).exactly( 1 ).times
            repo_control.should_receive( :apt_get_update ).with( host ).exactly( 1 ).times
          end

          repo_control.proxy_config

        end

        it "correctly configures debian hosts" do
          @hosts = make_hosts( vms, snaps, 'debian' )

          Command.should_receive( :new ).with( "if test -f /etc/apt/apt.conf; then mv /etc/apt/apt.conf /etc/apt/apt.conf.bk; fi" ).exactly( 3 ).times
          @hosts.each do |host|
            repo_control.should_receive( :copy_file_to_remote ).with( host, '/etc/apt/apt.conf', apt_cfg ).exactly( 1 ).times
            repo_control.should_receive( :apt_get_update ).with( host ).exactly( 1 ).times
          end

          repo_control.proxy_config

        end

        it "correctly configures solaris-11 hosts" do
          @hosts = make_hosts( vms, snaps, 'solaris-11' )

          Command.should_receive( :new ).with( "/usr/bin/pkg unset-publisher solaris || :" ).exactly( 3 ).times
          @hosts.each do |host|
            Command.should_receive( :new ).with( "/usr/bin/pkg set-publisher -g %s solaris" % ips_pkg_repo ).exactly( 1 ).times
          end

          repo_control.proxy_config

        end

        it "does nothing for non ubuntu/debian/solaris-11 hosts" do
          @hosts = make_hosts( vms, snaps, 'windows' )
          
          Command.should_receive( :new ).exactly( 0 ).times

          repo_control.proxy_config

        end
      end

      context "add_el_extras" do

        it "add extras for el-5/6 hosts" do
          @hosts = make_hosts( vms, snaps, 'el-5' )
          @hosts[0][:platform] = 'el-6' 
          url = "http://el_extras_url"

          repo_control.stub( :epel_info_for! ).and_return( url )

          Command.should_receive( :new ).with("rpm -qa | grep epel-release").exactly( 3 ).times
          Command.should_receive( :new ).with("rpm -i #{url}").exactly( 3 ).times
          Command.should_receive( :new ).with("yum clean all && yum makecache").exactly( 3 ).times

          repo_control.add_el_extras

        end

        it "should do nothing for non el-5/6 hosts" do
          @hosts = make_hosts( vms, snaps, 'windows' )

          Command.should_receive( :new ).exactly( 0 ).times

          repo_control.add_el_extras

        end
      end

    end

  end
end
