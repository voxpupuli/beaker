require 'spec_helper'

module Beaker
  module Utils
    describe Validator do
      let( :logger ) { double( 'logger' ).as_null_object }
      let( :defaults ) { Beaker::Options::OptionsHash.new.merge( { :logger => logger} ) }
      let( :options ) { @options ? defaults.merge( @options ) : defaults}

      let( :validator ) { Beaker::Utils::Validator }

      let( :vms ) { ['vm1', 'vm2', 'vm3'] }
      let( :snaps )  { ['snapshot1', 'snapshot2', 'snapshot3'] }
      let( :roles_def ) { [ ['agent'], ['master', 'dashboard', 'agent', 'database'], ['agent'] ] }

      let( :pkgs ) { Beaker::Utils::Validator::PACKAGES }
      let( :unix_only_pkgs ) { Beaker::Utils::Validator::UNIX_PACKAGES }

      def make_host name, snap, roles, platform
        opts = Beaker::Options::OptionsHash.new.merge( { :logger => logger, 'HOSTS' => { name => { 'platform' => platform, :snapshot => snap, :roles => roles } } } )
        Host.create( name, opts )
      end

      def make_hosts names, snaps, roles_def, platform = 'unix'
        hosts = []
        names.zip(snaps, roles_def).each do |vm, snap, roles|
          hosts << make_host( vm, snap, roles, platform )
        end
        hosts
      end

      before :each do
        result = mock( 'result' )
        result.stub( :stdout ).and_return( "" )
        result.stub( :exit_code ).and_return( 0 )
        Host.any_instance.stub( :exec ) do
          result  
        end
      end

      context "can validate the SUTs" do

        it "can validate unix hosts" do
          @hosts = make_hosts( vms, snaps, roles_def )

          @hosts.each do |host|
            pkgs.each do |pkg|
              host.should_receive( :check_for_package ).with( pkg ).exactly( 1 ).times.and_return( false )
              host.should_receive( :install_package ).with( pkg ).exactly( 1 ).times
            end
            unix_only_pkgs.each do |pkg|
              host.should_receive( :check_for_package ).with( pkg ).exactly( 1 ).times.and_return( false )
              host.should_receive( :install_package ).with( pkg ).exactly( 1 ).times
            end
            
          end

          validator.validate(@hosts, logger)

        end

        it "can validate windows hosts" do
          @hosts = make_hosts( vms, snaps, roles_def, 'windows' )

          @hosts.each do |host|
            pkgs.each do |pkg|
              host.should_receive( :check_for_package ).with( pkg ).exactly( 1 ).times.and_return( false )
              host.should_receive( :install_package ).with( pkg ).exactly( 1 ).times
            end
            unix_only_pkgs.each do |pkg|
              host.should_receive( :check_for_package).with( pkg ).exactly( 0 ).times
              host.should_receive( :install_package ).with( pkg ).exactly( 0 ).times
            end
          end

          validator.validate(@hosts, logger)

        end
      end


    end
  end
end
