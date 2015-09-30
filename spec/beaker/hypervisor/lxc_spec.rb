require 'spec_helper'

module LXC
  class Container
  end
end

module Beaker
  describe Lxc do
    let(:hosts) { make_hosts({
                               :template => "centos:6",
                               :platform => "centos",
                               :lxc_config => {
                                 "lxc.cap.drop" => '',
                               },
                             }, 3)}

    let(:logger) do
      logger = double('logger')
      allow( logger ).to receive(:debug)
      allow( logger ).to receive(:info)
      allow( logger ).to receive(:warn)
      allow( logger ).to receive(:error)
      allow( logger ).to receive(:notify)
      logger
    end

    let(:options) {{
      :logger => logger,
                   }}

    let(:container) do
      container = double('LXC::Container')
      allow( container ).to receive(:create)
      allow( container ).to receive(:start)
      allow( container ).to receive(:stop)
      allow( container ).to receive(:destroy)
      allow( container ).to receive(:set_config_item)
      allow( container ).to receive(:save_config)
      allow( container ).to receive(:attach)
      allow( container ).to receive(:ip_addresses).and_return([
                                                                '127.0.0.1'
                                                              ])
      allow( container ).to receive(:wait).and_return([
                                                        :stopped
                                                      ])
      container
    end

    let (:lxc) { ::Beaker::Lxc.new( hosts, options ) }

    before :each do
      allow_any_instance_of( ::Beaker::Lxc ).to receive(:require).with('lxc')
      allow( ::LXC::Container ).to receive(:new).and_return(container)
      allow_any_instance_of( ::LXC::Container ).to receive(:create)
      allow_any_instance_of( ::LXC::Container ).to receive(:start)
      allow_any_instance_of( ::LXC::Container ).to receive(:set_config_item)
      allow_any_instance_of( ::LXC::Container ).to receive(:save_config)
      allow_any_instance_of( ::LXC::Container ).to receive(:attach)
      allow_any_instance_of( ::LXC::Container ).to receive(:ip_addresses)
      allow_any_instance_of( ::LXC::Container ).to receive(:wait).and_return([
                                                                               :stopped
                                                                             ])
    end

    describe '#initialize' do
      it 'should require the lxc gem' do
        expect_any_instance_of( ::Beaker::Lxc ).to receive(:require).with('lxc').once

        lxc
      end

      it 'should fail when the gem is absent' do
        allow_any_instance_of( ::Beaker::Lxc ).to receive(:require).with('lxc').and_raise(LoadError)
        expect { lxc }.to raise_error(LoadError)
      end
    end

    describe '#provision' do
      it 'should create a container for each host ' do
        hosts.each do |host|
          expect( ::LXC::Container ).to receive(:new)
        end

        lxc.provision
      end

      it 'should create a container based on the template ' do
        hosts.each do |host|
          expect( container ).to receive(:create).with("download", nil, {}, 0, ["-d", "centos", "-r", "6", "-a", "amd64"])
        end

        lxc.provision
      end

      it 'should set lxc_config options ' do
        expect( container ).to receive(:set_config_item).with('lxc.cap.drop', '')

        lxc.provision
      end

      it 'should save the configuration ' do
        expect( container ).to receive(:save_config)

        lxc.provision
      end

      it 'should start the container ' do
        expect( container ).to receive(:start)

        lxc.provision
      end

      it 'should attach to the container ' do
        expect( container ).to receive(:attach).with({:wait => true})

        lxc.provision
      end

      context "connecting to ssh" do
        it 'should expose port 22 to beaker' do
          lxc.provision

          expect( hosts[0]['ip'] ).to be === '127.0.0.1'
          expect( hosts[0]['port'] ).to be ===  22
        end

        it 'should have ssh agent forwarding enabled' do
          lxc.provision

          expect( hosts[0]['ip'] ).to be === '127.0.0.1'
          expect( hosts[0]['port'] ).to be === 22
          expect( hosts[0]['ssh'][:password] ).to be === 'root'
          expect( hosts[0]['ssh'][:port] ).to be === 22
          expect( hosts[0]['ssh'][:forward_agent] ).to be === false
        end
      end
    end

    describe '#cleanup' do
      before :each do
        lxc.provision
      end

      it 'should stop the containers' do
        expect( container ).to receive(:stop)
        lxc.cleanup
      end

      it 'should wait for the container to stop ' do
        expect( container ).to receive(:wait).with("stopped", 60).and_return(:stopped)
        lxc.cleanup
      end      

      it 'should delete the containers' do
        expect( container ).to receive(:destroy)
        lxc.cleanup
      end

      it 'should not delete the container if lxc_preserve_container is set to true' do
        hosts.each do |host|
          host['lxc_preserve_container']=true
        end
        expect( container ).to_not receive(:destroy)
        lxc.cleanup
      end

      it 'should delete the container if lxc_preserve_container is set to false' do
        hosts.each do |host|
          host['lxc_preserve_container']=false
        end
        expect( container ).to receive(:destroy)
        lxc.cleanup
      end

    end
  end
end
