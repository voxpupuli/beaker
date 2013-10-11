require 'spec_helper'
require 'blimpy'

module Beaker
  describe Blimper do
    let( :blimper ) { Beaker::Blimper.new( @hosts, make_opts ) }
    let( :amispec ) { { "centos-5-x86-64-west" => { :image => { :pe => "ami-sekrit1" }, :region => "us-west-2" }, 
                        "centos-6-x86-64-west" => { :image => { :pe => "ami-sekrit2" }, :region => "us-west-2" }, 
                        "centos-7-x86-64-west" => { :image => { :pe => "ami-sekrit3" }, :region => "us-west-2" } }}

    before :each do
      @hosts = make_hosts( { :snapshot => :pe })
      @hosts[0][:platform] = "centos-5-x86-64-west" 
      @hosts[1][:platform] = "centos-6-x86-64-west" 
      @hosts[2][:platform] = "centos-7-x86-64-west" 
      blimper.instance_variable_set( :@blimpy, MockBlimpy )
    end

    it "can provision a set of hosts" do 
      YAML.stub( :load_file ).and_return( {"AMI" => amispec} )
      blimper.stub( :get_ip ) do |host|
        host['ip']
      end
      blimper.stub( :get_domain_name ).and_return( 'domain' )
      blimper.stub( :sleep ).and_return( true )

      @hosts.each do |host|
        blimper.should_receive( :set_etc_hosts ).with( host, "127.0.0.1\tlocalhost localhost.localdomain\nvm1.my.ip\tvm1\tvm1.domain\nvm2.my.ip\tvm2\tvm2.domain\nvm3.my.ip\tvm3\tvm3.domain\n" )
      end

      blimper.provision
    end

    it "calls fleet.destroy on cleanup" do
      MockFleet.any_instance.should_receive( :add ).with( :aws ).exactly( @hosts.length ).times
      MockFleet.any_instance.should_receive( :destroy ).once

      blimper.cleanup
    end

    context "amiports" do

      it "can set ports for database host" do
        host = @hosts[0]
        host[ :roles ] = [ "database" ]
        
        expect( blimper.amiports(host) ).to be === [ 22, 8080, 8081 ]

      end

      it "can set ports for master host" do
        host = @hosts[0]
        host[ :roles ] = [ "master" ]
        
        expect( blimper.amiports(host) ).to be === [ 22, 8140 ]

      end

      it "can set ports for dashboard host" do
        host = @hosts[0]
        host[ :roles ] = [ "dashboard" ]
        
        expect( blimper.amiports(host) ).to be === [ 22, 443 ]
      end

      it "can set ports for combined master/database/dashboard host" do
        host = @hosts[0]
        host[ :roles ] = [ "dashboard", "master", "database" ]
        
        expect( blimper.amiports(host) ).to be === [ 22, 8080, 8081, 8140, 443 ]
      end
    end


  end

end
