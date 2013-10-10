require 'spec_helper'

module Beaker
  describe Aixer do
    let( :aixer) { Beaker::Aixer.new( @hosts, make_opts ) }

    before :each do
      @hosts = make_hosts()
      File.stub( :exists? ).and_return( true )
      YAML.stub( :load_file ).and_return( fog_file_contents )
      Host.any_instance.stub( :exec ).and_return( true )
    end

    it "can provision a set of hosts" do
      @hosts.each do |host|
        Command.should_receive( :new ).with( "cd pe-aix && rake restore:#{host.name}" ).once

      end

      aixer.provision

    end

    it "does nothing for cleanup" do
      Command.should_receive( :new ).never
      Host.should_receive( :exec ).never

      aixer.cleanup

    end


  end
end
