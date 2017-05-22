require 'spec_helper'
require 'fakefs/spec_helpers'

# fake the docker-api
module Docker
  class Image
  end
  class Container
  end
end

module Beaker
  platforms = [
    "ubuntu-14.04-x86_64",
    "cumulus-2.2-x86_64",
    "fedora-22-x86_64",
    "centos-7-x86_64",
    "sles-12-x86_64"
  ]

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
      :provision => true
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
      allow( container ).to receive(:info).and_return(
        *(0..2).map { |index| { 'Names' => ["/spec-container-#{index}"] } }
      )
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
      allow( container ).to receive(:kill)
      allow( container ).to receive(:delete)
      allow( container ).to receive(:exec)
      container
    end

    let (:docker) { ::Beaker::Docker.new( hosts, options ) }
    let(:docker_options) { nil }
    let (:version) { {"ApiVersion"=>"1.18", "Arch"=>"amd64", "GitCommit"=>"4749651", "GoVersion"=>"go1.4.2", "KernelVersion"=>"3.16.0-37-generic", "Os"=>"linux", "Version"=>"1.6.0"} }

    before :each do
      # Stub out all of the docker-api gem. we should never really call it
      # from these tests
      allow_any_instance_of( ::Beaker::Docker ).to receive(:require).with('docker')
      allow( ::Docker ).to receive(:options).and_return(docker_options)
      allow( ::Docker ).to receive(:options=)
      allow( ::Docker ).to receive(:logger=)
      allow( ::Docker ).to receive(:version).and_return(version)
      allow( ::Docker::Image ).to receive(:build).and_return(image)
      allow( ::Docker::Container ).to receive(:create).and_return(container)
      allow_any_instance_of( ::Docker::Container ).to receive(:start)
    end

    describe '#initialize, failure to validate' do
      before :each do
        require 'excon'
        allow( ::Docker ).to receive(:validate_version!).and_raise(Excon::Errors::SocketError.new( StandardError.new('oops') ))
      end
      it 'should fail when docker not present' do
        expect { docker }.to raise_error(RuntimeError, /Docker instance not connectable./)
        expect { docker }.to raise_error(RuntimeError, /Check your DOCKER_HOST variable has been set/)
        expect { docker }.to raise_error(RuntimeError, /If you are on OSX or Windows, you might not have Docker Machine setup correctly/)
        expect { docker }.to raise_error(RuntimeError, /Error was: oops/)
      end
    end

    describe '#initialize' do
      before :each do
        allow( ::Docker ).to receive(:validate_version!)
      end

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
        allow( ::Docker ).to receive(:validate_version!)
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
        expect( ::Docker::Image ).to receive(:build).with('special testing value', { :rm => true, :buildargs => '{}' })

        docker.provision
      end

      it 'should pass the buildargs from ENV DOCKER_BUILDARGS on to Docker::Image.create' do
        allow( docker ).to receive(:dockerfile_for).and_return('special testing value')
        ENV['DOCKER_BUILDARGS'] = 'HTTP_PROXY=http://1.1.1.1:3128'
        expect( ::Docker::Image ).to receive(:build).with('special testing value', { :rm => true, :buildargs => "{\"HTTP_PROXY\":\"http://1.1.1.1:3128\"}" })

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

      it 'should pass the multiple buildargs from ENV DOCKER_BUILDARGS on to Docker::Image.create' do
        allow( docker ).to receive(:dockerfile_for).and_return('special testing value')
        ENV['DOCKER_BUILDARGS'] = 'HTTP_PROXY=http://1.1.1.1:3128	HTTPS_PROXY=https://1.1.1.1:3129'
        expect( ::Docker::Image ).to receive(:build).with('special testing value', { :rm => true, :buildargs => "{\"HTTP_PROXY\":\"http://1.1.1.1:3128\",\"HTTPS_PROXY\":\"https://1.1.1.1:3129\"}" })

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

      it 'should create a named container based on the Image (identified by image.id)' do
        hosts.each_with_index do |host, index|
          container_name = "spec-container-#{index}"
          host['docker_container_name'] = container_name

          expect( ::Docker::Container ).to receive(:create).with({
            'Image' => image.id,
            'Hostname' => host.name,
            'name' => container_name,
          })
        end

        docker.provision
      end


      it 'should create a container with volumes bound' do
        hosts.each_with_index do |host, index|
          host['mount_folders'] = {
            'mount1' => {
              'host_path' => '/source_folder',
              'container_path' => '/mount_point',
            },
            'mount2' => {
              'host_path' => '/another_folder',
              'container_path' => '/another_mount',
              'opts' => 'ro',
            },
            'mount3' => {
              'host_path' => '/different_folder',
              'container_path' => '/different_mount',
              'opts' => 'rw',
            },
            'mount4' => {
              'host_path' => './',
              'container_path' => '/relative_mount',
            },
            'mount5' => {
              'host_path' => 'local_folder',
              'container_path' => '/another_relative_mount',
            }
          }

          expect( ::Docker::Container ).to receive(:create).with({
            'Image' => image.id,
            'Hostname' => host.name,
            'HostConfig' => {
              'Binds' => [
                '/source_folder:/mount_point',
                '/another_folder:/another_mount:ro',
                '/different_folder:/different_mount:rw',
                "#{File.expand_path('./')}:/relative_mount",
                "#{File.expand_path('local_folder')}:/another_relative_mount",
              ]
            }
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

      it "should generate a new /etc/hosts file referencing each host" do
        ENV['DOCKER_HOST'] = nil
        docker.provision
        hosts.each do |host|
          expect( docker ).to receive( :get_domain_name ).with( host ).and_return( 'labs.lan' )
          expect( docker ).to receive( :set_etc_hosts ).with( host, "127.0.0.1\tlocalhost localhost.localdomain\n192.0.2.1\tvm1.labs.lan vm1\n192.0.2.1\tvm2.labs.lan vm2\n192.0.2.1\tvm3.labs.lan vm3\n" ).once
        end
        docker.hack_etc_hosts( hosts, options )
      end

      it 'should record the image and container for later' do
        docker.provision

        expect( hosts[0]['docker_image'] ).to be === image
        expect( hosts[0]['docker_container'] ).to be === container
      end

      context 'provision=false' do
        let(:options) {{
          :logger => logger,
          :forward_ssh_agent => true,
          :provision => false
        }}


        it 'should fix ssh' do
          hosts.each_with_index do |host, index|
            container_name = "spec-container-#{index}"
            host['docker_container_name'] = container_name

            expect( ::Docker::Container ).to receive(:all).and_return([container])
            expect(container).to receive(:exec).exactly(4).times
          end
          docker.provision
        end

        it 'should not create a container if a named one already exists' do
          hosts.each_with_index do |host, index|
            container_name = "spec-container-#{index}"
            host['docker_container_name'] = container_name

            expect( ::Docker::Container ).to receive(:all).and_return([container])
            expect( ::Docker::Container ).not_to receive(:create)
          end

          docker.provision
        end
      end
    end

    describe '#cleanup' do
      before :each do
        # get into a state where there's something to clean
        allow( ::Docker ).to receive(:validate_version!)
        allow( docker ).to receive(:dockerfile_for)
        docker.provision
      end

      it 'should stop the containers' do
        allow( docker ).to receive( :sleep ).and_return(true)
        expect( container ).to receive(:kill)
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
      FakeFS.deactivate!
      before :each do
        allow( ::Docker ).to receive(:validate_version!)
      end
      it 'should raise on an unsupported platform' do
        expect { docker.send(:dockerfile_for, {'platform' => 'a_sidewalk', 'image' => 'foobar' }) }.to raise_error(/platform a_sidewalk not yet supported/)
      end

      it 'should raise on missing image' do
        expect { docker.send(:dockerfile_for, {'platform' => 'centos-7-x86_64'})}.to raise_error(/Docker image undefined/)
      end

      it 'should set "ENV container docker"' do
        FakeFS.deactivate!
        platforms.each do |platform|
          dockerfile = docker.send(:dockerfile_for, {
            'platform' => platform,
            'image' => 'foobar',
          })
          expect( dockerfile ).to be =~ /ENV container docker/
        end
      end

      it 'should add docker_image_commands as RUN statements' do
        FakeFS.deactivate!
        platforms.each do |platform|
          dockerfile = docker.send(:dockerfile_for, {
            'platform' => platform,
            'image' => 'foobar',
            'docker_image_commands' => [
              'special one',
              'special two',
              'special three',
            ]
          })

          expect( dockerfile ).to be =~ /RUN special one\nRUN special two\nRUN special three/
        end
      end

      it 'should add docker_image_entrypoint' do
        FakeFS.deactivate!
        platforms.each do |platform|
          dockerfile = docker.send(:dockerfile_for, {
            'platform' => platform,
            'image' => 'foobar',
            'docker_image_entrypoint' => '/bin/bash'
          })

          expect( dockerfile ).to be =~ %r{ENTRYPOINT /bin/bash}
        end
      end

      it 'should use zypper on sles' do
        FakeFS.deactivate!
        dockerfile = docker.send(:dockerfile_for, {
          'platform' => 'sles-12-x86_64',
          'image' => 'foobar',
        })

        expect( dockerfile ).to be =~ /RUN zypper -n in openssh/
      end

      (22..29).to_a.each do | fedora_release |
        it "should use dnf on fedora #{fedora_release}" do
          FakeFS.deactivate!
          dockerfile = docker.send(:dockerfile_for, {
            'platform' => "fedora-#{fedora_release}-x86_64",
            'image' => 'foobar',
          })

          expect( dockerfile ).to be =~ /RUN dnf install -y sudo/
        end
      end

      it 'should use user dockerfile if specified' do
        FakeFS.deactivate!
        dockerfile = docker.send(:dockerfile_for, {
          'dockerfile' => 'README.md'
        })

        expect( dockerfile ).to be == File.read('README.md')
      end

    end
  end
end
