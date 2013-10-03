require 'spec_helper'

module Beaker
  module Utils
    describe NTPControl do
      let( :logger ) { double( 'logger' ).as_null_object }
      let( :defaults ) { Beaker::Options::OptionsHash.new.merge( { :logger => logger} ) }
      let( :options ) { @options ? defaults.merge( @options ) : defaults}
      let( :ntpserver ) { Beaker::Utils::NTPControl::NTPSERVER }

      let( :ntp_control ) { Beaker::Utils::NTPControl.new( options, @hosts) }
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
        result.stub( :exit_code ).and_return( 0 )
        Host.any_instance.stub( :exec ) do
          result  
        end
      end

      it "can sync time on unix hosts" do
        @hosts = make_hosts( vms, snaps )

        Command.should_receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 3 ).times

        ntp_control.timesync

      end

      it "can sync time on solaris-10 hosts" do
        @hosts = make_hosts( vms, snaps, 'solaris-10' )

        Command.should_receive( :new ).with("sleep 10 && ntpdate -w #{ntpserver}").exactly( 3 ).times

        ntp_control.timesync

      end

      it "can sync time on windows hosts" do
        @hosts = make_hosts( vms, snaps, 'windows' )

        Command.should_receive( :new ).with("w32tm /register").exactly( 3 ).times
        Command.should_receive( :new ).with("net start w32time").exactly( 3 ).times
        Command.should_receive( :new ).with("w32tm /config /manualpeerlist:#{ntpserver} /syncfromflags:manual /update").exactly( 3 ).times
        Command.should_receive( :new ).with("w32tm /resync").exactly( 3 ).times

        ntp_control.timesync

      end

    end

  end
end
