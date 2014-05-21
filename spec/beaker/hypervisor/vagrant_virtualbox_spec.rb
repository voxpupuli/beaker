require 'spec_helper'

describe Beaker::VagrantVirtualbox do
  let( :options ) { make_opts.merge({ 'logger' => double().as_null_object }) }
  let( :vagrant ) { Beaker::VagrantVirtualbox.new( @hosts, options ) }

  before :each do
    @hosts = make_hosts()
    @hosts.each do |host|
      host_prev_name = host['user']
      vagrant.should_receive( :set_ssh_config ).with( host, 'vagrant' ).once
      vagrant.should_receive( :copy_ssh_to_root ).with( host, options ).once
      vagrant.should_receive( :set_ssh_config ).with( host, host_prev_name ).once
    end
    vagrant.should_receive( :hack_etc_hosts ).with( @hosts, options ).once
  end

  describe "provisioning" do
    it 'should use the virtualbox provider' do
      FakeFS.activate!
      vagrant.should_receive( :vagrant_cmd ).with( "up --provider virtualbox" ).once
      vagrant.provision
    end
  end
end
