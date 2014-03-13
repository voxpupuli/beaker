require 'spec_helper'

module Beaker
  module Utils
    describe NTPControl do
      let( :ntpserver )   { Beaker::Utils::NTPControl::NTPSERVER }
      let( :ntp_control ) { Beaker::Utils::NTPControl.new( make_opts, @hosts) }

      it "can sync time on unix hosts" do
        @hosts = make_hosts( { :platform => 'unix' } )

        Command.should_receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 3 ).times

        ntp_control.timesync

      end

      it "can retry on failure on unix hosts" do
        @hosts = make_hosts( { :platform => 'unix', :exit_code => [1, 0] } )
        ntp_control.stub( :sleep ).and_return(true)

        Command.should_receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 6 ).times

        ntp_control.timesync
      end

      it "eventually gives up and raises an error when unix hosts can't be synched" do
        @hosts = make_hosts( { :platform => 'unix', :exit_code => 1 } )
        ntp_control.stub( :sleep ).and_return(true)

        Command.should_receive( :new ).with("ntpdate -t 20 #{ntpserver}").exactly( 5 ).times

        expect{ ntp_control.timesync }.to raise_error
      end

      it "can sync time on solaris-10 hosts" do
        @hosts = make_hosts( { :platform => 'solaris-10' } )

        Command.should_receive( :new ).with("sleep 10 && ntpdate -w #{ntpserver}").exactly( 3 ).times

        ntp_control.timesync

      end

      it "can sync time on windows hosts" do
        @hosts = make_hosts( { :platform => 'windows' } )

        Command.should_receive( :new ).with("w32tm /register").exactly( 3 ).times
        Command.should_receive( :new ).with("net start w32time").exactly( 3 ).times
        Command.should_receive( :new ).with("w32tm /config /manualpeerlist:#{ntpserver} /syncfromflags:manual /update").exactly( 3 ).times
        Command.should_receive( :new ).with("w32tm /resync").exactly( 3 ).times

        ntp_control.timesync

      end

      it "can sync time on Sles hosts" do
        @hosts = make_hosts( { :platform => 'sles-13.1-x64' } )

        Command.should_receive( :new ).with("sntp #{ntpserver}").exactly( 3 ).times

        ntp_control.timesync

      end
    

    end

  end
end
