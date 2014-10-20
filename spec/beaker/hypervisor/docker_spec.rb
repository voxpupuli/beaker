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
      logger.stub(:debug)
      logger.stub(:info)
      logger.stub(:warn)
      logger.stub(:error)
      logger.stub(:notify)
      logger
    end

    let(:image) do
      image = double('Docker::Image')
      image.stub(:id)
      image.stub(:tag)
      image.stub(:delete)
      image
    end

    let(:container) do
      container = double('Docker::Container')
      container.stub(:id)
      container.stub(:start)
      container.stub(:json).and_return({
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
      container.stub(:stop)
      container.stub(:delete)
      container
    end

    let (:docker) { ::Beaker::Docker.new( hosts, { :logger => logger }) }

    before :each do
      # Stub out all of the docker-api gem. we should never really call it
      # from these tests
      ::Beaker::Docker.any_instance.stub(:require).with('docker')
      ::Docker.stub(:options=)
      ::Docker.stub(:logger=)
      ::Docker.stub(:validate_version!)
      ::Docker::Image.stub(:build).and_return(image)
      ::Docker::Container.stub(:create).and_return(container)
      ::Docker::Container.any_instance.stub(:start)
    end

    describe '#initialize' do
      it 'should require the docker gem' do
        ::Beaker::Docker.any_instance.should_receive(:require).with('docker').once

        docker
      end

      it 'should fail when the gem is absent' do
        ::Beaker::Docker.any_instance.stub(:require).with('docker').and_raise(LoadError)
        expect { docker }.to raise_error(LoadError)
      end

      it 'should set Docker options' do
        ::Docker.should_receive(:options=).once

        docker
      end

      it 'should check the Docker gem can work with the api' do
        ::Docker.should_receive(:validate_version!).once

        docker
      end

      it 'should hook the Beaker logger into the Docker one' do
        ::Docker.should_receive(:logger=).with(logger)

        docker
      end
    end

    describe '#provision' do
      before :each do
        docker.stub(:dockerfile_for)
      end

      it 'should call dockerfile_for with all the hosts' do
        hosts.each do |host|
          docker.should_receive(:dockerfile_for).with(host).and_return('')
        end

        docker.provision
      end

      it 'should pass the Dockerfile on to Docker::Image.create' do
        docker.stub(:dockerfile_for).and_return('special testing value')
        ::Docker::Image.should_receive(:build).with('special testing value', { :rm => true })

        docker.provision
      end

      it 'should create a container based on the Image (identified by image.id)' do
        hosts.each do |host|
          ::Docker::Container.should_receive(:create).with({
            'Image' => image.id,
            'Hostname' => host.name,
          })
        end

        docker.provision
      end

      it 'should start the container' do
        container.should_receive(:start).with({'PublishAllPorts' => true, 'Privileged' => true})

        docker.provision
      end

      context "connecting to ssh" do
        before { @docker_host = ENV['DOCKER_HOST'] }
        after { ENV['DOCKER_HOST'] = @docker_host }

        it 'should expose port 22 to beaker' do
          ENV['DOCKER_HOST'] = nil
          docker.provision

          hosts[0]['ip'].should == '127.0.1.1'
          hosts[0]['port'].should == 8022
        end

        it 'should expose port 22 to beaker when using DOCKER_HOST' do
          ENV['DOCKER_HOST'] = "tcp://192.0.2.2:2375"
          docker.provision

          hosts[0]['ip'].should == '192.0.2.2'
          hosts[0]['port'].should == 8022
        end
      end

      it 'should record the image and container for later' do
        docker.provision

        hosts[0]['docker_image'].should == image
        hosts[0]['docker_container'].should == container
      end
    end

    describe '#cleanup' do
      before :each do
        # get into a state where there's something to clean
        docker.stub(:dockerfile_for)
        docker.provision
      end

      it 'should stop the containers' do
        docker.stub( :sleep ).and_return(true)
        container.should_receive(:stop)
        docker.cleanup
      end

      it 'should delete the containers' do
        docker.stub( :sleep ).and_return(true)
        container.should_receive(:delete)
        docker.cleanup
      end

      it 'should delete the images' do
        docker.stub( :sleep ).and_return(true)
        image.should_receive(:delete)
        docker.cleanup
      end

      it 'should not delete the image if docker_preserve_image is set to true' do
        docker.stub( :sleep ).and_return(true)
        hosts.each do |host|
          host['docker_preserve_image']=true
        end
        image.should_not_receive(:delete)
        docker.cleanup
      end

      it 'should delete the image if docker_preserve_image is set to false' do
        docker.stub( :sleep ).and_return(true)
        hosts.each do |host|
          host['docker_preserve_image']=false
        end
        image.should_receive(:delete)
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

        dockerfile.should =~ /RUN special one\nRUN special two\nRUN special three/
      end

      it 'should use zypper on sles' do
        dockerfile = docker.send(:dockerfile_for, {
          'platform' => 'sles',
        })

        dockerfile.should =~ /RUN zypper -n in openssh/
      end
    end
  end
end
