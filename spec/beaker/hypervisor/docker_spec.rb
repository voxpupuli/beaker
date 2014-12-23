require 'spec_helper'

# fake the docker-api
module Docker
  class Image
  end
  class Container
  end
end

module Beaker
  describe Docker do
    let(:hosts) { make_hosts }

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
      :forward_ssh_agent => true,
    }}

    let(:image) do
      image = double('Docker::Image')
      allow( image ).to receive(:id)
      allow( image ).to receive(:tag)
      allow( image ).to receive(:delete)
      image
    end

    let(:container) do
      container = double('Docker::Container')
      allow( container ).to receive(:id)
      allow( container ).to receive(:start)
      allow( container ).to receive(:json).and_return({
        'NetworkSettings' => {
          'IPAddress' => '192.0.2.1',
          'Ports' => {
            '22/tcp' => [
              {
                'HostIp' => '127.0.1.1',
                'HostPort' => 8022,
              },
            ],
          },
        },
      })
      allow( container ).to receive(:stop)
      allow( container ).to receive(:delete)
      container
    end

    let (:docker) { ::Beaker::Docker.new( hosts, options ) }
    let(:docker_options) { nil }

    before :each do
      # Stub out all of the docker-api gem. we should never really call it
      # from these tests
      allow_any_instance_of( ::Beaker::Docker ).to receive(:require).with('docker')
      allow( ::Docker ).to receive(:options).and_return(docker_options)
      allow( ::Docker ).to receive(:options=)
      allow( ::Docker ).to receive(:logger=)
      allow( ::Docker ).to receive(:validate_version!)
      allow( ::Docker::Image ).to receive(:build).and_return(image)
      allow( ::Docker::Container ).to receive(:create).and_return(container)
      allow_any_instance_of( ::Docker::Container ).to receive(:start)
    end

    describe '#initialize' do
      it 'should require the docker gem' do
        expect_any_instance_of( ::Beaker::Docker ).to receive(:require).with('docker').once

        docker
      end

      it 'should fail when the gem is absent' do
        allow_any_instance_of( ::Beaker::Docker ).to receive(:require).with('docker').and_raise(LoadError)
        expect { docker }.to raise_error(LoadError)
      end

      it 'should set Docker options' do
        expect( ::Docker ).to receive(:options=).with({:write_timeout => 300, :read_timeout => 300}).once

        docker
      end

      context 'when Docker options are already set' do
        let(:docker_options) {{:write_timeout => 600, :foo => :bar}}

        it 'should not override Docker options' do
          expect( ::Docker ).to receive(:options=).with({:write_timeout => 600, :read_timeout => 300, :foo => :bar}).once

          docker
        end
      end

      it 'should check the Docker gem can work with the api' do
        expect( ::Docker ).to receive(:validate_version!).once

        docker
      end

      it 'should hook the Beaker logger into the Docker one' do
        expect( ::Docker ).to receive(:logger=).with(logger)

        docker
      end
    end

    describe '#provision' do
      before :each do
        allow( docker ).to receive(:dockerfile_for)
      end

      it 'should call dockerfile_for with all the hosts' do
        hosts.each do |host|
          expect( docker ).to receive(:dockerfile_for).with(host).and_return('')
        end

        docker.provision
      end

      it 'should pass the Dockerfile on to Docker::Image.create' do
        allow( docker ).to receive(:dockerfile_for).and_return('special testing value')
        expect( ::Docker::Image ).to receive(:build).with('special testing value', { :rm => true })

        docker.provision
      end

      it 'should create a container based on the Image (identified by image.id)' do
        hosts.each do |host|
          expect( ::Docker::Container ).to receive(:create).with({
            'Image' => image.id,
            'Hostname' => host.name,
          })
        end

        docker.provision
      end

      it 'should start the container' do
        expect( container ).to receive(:start).with({'PublishAllPorts' => true, 'Privileged' => true})

        docker.provision
      end

      context "connecting to ssh" do
        before { @docker_host = ENV['DOCKER_HOST'] }
        after { ENV['DOCKER_HOST'] = @docker_host }

        it 'should expose port 22 to beaker' do
          ENV['DOCKER_HOST'] = nil
          docker.provision

          expect( hosts[0]['ip'] ).to be === '127.0.1.1'
          expect( hosts[0]['port'] ).to be ===  8022
        end

        it 'should expose port 22 to beaker when using DOCKER_HOST' do
          ENV['DOCKER_HOST'] = "tcp://192.0.2.2:2375"
          docker.provision

          expect( hosts[0]['ip'] ).to be === '192.0.2.2'
          expect( hosts[0]['port'] ).to be === 8022
        end

        it 'should have ssh agent forwarding enabled' do
          ENV['DOCKER_HOST'] = nil
          docker.provision

          expect( hosts[0]['ip'] ).to be === '127.0.1.1'
          expect( hosts[0]['port'] ).to be === 8022
          expect( hosts[0]['ssh'][:password] ).to be ===  'root'
          expect( hosts[0]['ssh'][:port] ).to be ===  8022
          expect( hosts[0]['ssh'][:forward_agent] ).to be === true
        end

      end

      it 'should record the image and container for later' do
        docker.provision

        expect( hosts[0]['docker_image'] ).to be === image
        expect( hosts[0]['docker_container'] ).to be === container
      end
    end

    describe '#cleanup' do
      before :each do
        # get into a state where there's something to clean
        allow( docker ).to receive(:dockerfile_for)
        docker.provision
      end

      it 'should stop the containers' do
        allow( docker ).to receive( :sleep ).and_return(true)
        expect( container ).to receive(:stop)
        docker.cleanup
      end

      it 'should delete the containers' do
        allow( docker ).to receive( :sleep ).and_return(true)
        expect( container ).to receive(:delete)
        docker.cleanup
      end

      it 'should delete the images' do
        allow( docker ).to receive( :sleep ).and_return(true)
        expect( image ).to receive(:delete)
        docker.cleanup
      end

      it 'should not delete the image if docker_preserve_image is set to true' do
        allow( docker ).to receive( :sleep ).and_return(true)
        hosts.each do |host|
          host['docker_preserve_image']=true
        end
        expect( image ).to_not receive(:delete)
        docker.cleanup
      end

      it 'should delete the image if docker_preserve_image is set to false' do
        allow( docker ).to receive( :sleep ).and_return(true)
        hosts.each do |host|
          host['docker_preserve_image']=false
        end
        expect( image ).to receive(:delete)
        docker.cleanup
      end

    end

    describe '#dockerfile_for' do
      it 'should raise on an unsupported platform' do
        expect { docker.send(:dockerfile_for, {'platform' => 'a_sidewalk' }) }.to raise_error(/platform a_sidewalk not yet supported on docker/)
      end

      it 'should add docker_image_commands as RUN statements' do
        dockerfile = docker.send(:dockerfile_for, {
          'platform' => 'el-',
          'docker_image_commands' => [
            'special one',
            'special two',
            'special three',
          ]
        })

        expect( dockerfile ).to be =~ /RUN special one\nRUN special two\nRUN special three/
      end

      it 'should add docker_image_entrypoint' do
        dockerfile = docker.send(:dockerfile_for, {
          'platform' => 'el-',
          'docker_image_entrypoint' => '/bin/bash'
        })

        expect( dockerfile ).to be =~ %r{ENTRYPOINT /bin/bash}
      end

      it 'should use zypper on sles' do
        dockerfile = docker.send(:dockerfile_for, {
          'platform' => 'sles',
        })

        expect( dockerfile ).to be =~ /RUN zypper -n in openssh/
      end
    end
  end
end
