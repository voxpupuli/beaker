require 'spec_helper'
require 'blimpy'

module Beaker
  describe Blimper do
    let( :logger ) { double( 'logger' ).as_null_object }
    let( :defaults ) { Beaker::Options::OptionsHash.new.merge( { :logger => logger, :config => 'sample.cfg'} ) }
    let( :options ) { @options ? defaults.merge( @options ) : defaults}

    let( :blimper ) { Beaker::Blimper.new( @hosts, options ) }
    let( :vms ) { ['vm1', 'vm2', 'vm3'] }
    let( :snaps )  { ['pe', 'pe', 'pe'] }
    let( :amispec ) { { "centos-5-x86-64-west" => { :image => { :pe => "ami-sekrit1" }, :region => "us-west-2" }, 
                        "centos-6-x86-64-west" => { :image => { :pe => "ami-sekrit2" }, :region => "us-west-2" }, 
                        "centos-7-x86-64-west" => { :image => { :pe => "ami-sekrit3" }, :region => "us-west-2" } }}

    before :each do
      @hosts = make_hosts( vms, snaps )
    end

    def make_host name, snap, platform = 'unix'
      opts = Beaker::Options::OptionsHash.new.merge( { :logger => logger, 'HOSTS' => { name => { 'platform' => platform, :snapshot => snap, :roles => ['agent'] } } } )
      host = Host.create( name, opts )
      host.stub( :exec ).and_return( name )
      host
    end

    def make_hosts names, snaps
      hosts = []
      names.zip(snaps, amispec.keys).each do |vm, snap, platform|
        hosts << make_host( vm, snap, platform )
      end
      hosts
    end

    it "can provision a set of hosts" do 
      YAML.stub( :load_file ).and_return( {"AMI" => amispec} )
      blimper.stub( :get_ip ) do |host|
        host['ip']
      end
      blimper.stub( :get_domain_name ).and_return( 'domain' )
      blimper.stub( :sleep ).and_return( true )
      blimper.instance_variable_set( :@blimpy, MockBlimpy )

      @hosts.each do |host|
        blimper.should_receive( :set_etc_hosts ).with( host, "127.0.0.1\tlocalhost localhost.localdomain\nvm1.my.ip\tvm1\tvm1.domain\nvm2.my.ip\tvm2\tvm2.domain\nvm3.my.ip\tvm3\tvm3.domain\n" )
      end

      blimper.provision
    end

    it "can clean up after provisioning" do
      blimper.cleanup
    end

    context "amiports" do

      it "can set ports for database host" do
        host = make_host("database", "snap")
        host[:roles] = ["database"]
        
        expect( blimper.amiports(host) ).to be === [22, 8080, 8081]

      end

      it "can set ports for master host" do
        host = make_host("master", "snap")
        host[:roles] = ["master"]
        
        expect( blimper.amiports(host) ).to be === [22, 8140]

      end

      it "can set ports for dashboard host" do
        host = make_host("dashboard", "snap")
        host[:roles] = ["dashboard"]
        
        expect( blimper.amiports(host) ).to be === [22, 443]
      end

      it "can set ports for combined master/database/dashboard host" do
        host = make_host("combined", "snap")
        host[:roles] = ["dashboard", "master", "database"]
        
        expect( blimper.amiports(host) ).to be === [22, 8080, 8081, 8140, 443]
      end
    end


  end

end
