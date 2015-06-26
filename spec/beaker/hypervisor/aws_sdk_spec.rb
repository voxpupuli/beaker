require 'spec_helper'

module Beaker
  describe AwsSdk do
    let( :options ) { make_opts.merge({ 'logger' => double().as_null_object }) }
    let(:aws) {
      # Mock out the call to load_fog_credentials
      allow_any_instance_of( Beaker::AwsSdk ).to receive(:load_fog_credentials).and_return(fog_file_contents)

      # This is needed because the EC2 api looks up a local endpoints.json file
      FakeFS.deactivate!
      aws = Beaker::AwsSdk.new(@hosts, options)
      FakeFS.activate!

      aws
    }
    let(:amispec) {{
      "centos-5-x86-64-west" => {
        :image => {:pe => "ami-sekrit1"},
        :region => "us-west-2",
      },
      "centos-6-x86-64-west" => {
        :image => {:pe => "ami-sekrit2"},
        :region => "us-west-2",
      },
      "centos-7-x86-64-west" => {
        :image => {:pe => "ami-sekrit3"},
        :region => "us-west-2",
      },
      "ubuntu-12.04-amd64-west" => {
        :image => {:pe => "ami-sekrit4"},
        :region => "us-west-2"
      },
    }}

    before :each do
      @hosts = make_hosts({:snapshot => :pe}, 5)
      @hosts[0][:platform] = "centos-5-x86-64-west"
      @hosts[1][:platform] = "centos-6-x86-64-west"
      @hosts[2][:platform] = "centos-7-x86-64-west"
      @hosts[3][:platform] = "ubuntu-12.04-amd64-west"
      @hosts[3][:user] = "ubuntu"
      @hosts[4][:platform] = 'f5-host'
      @hosts[4][:user] = 'notroot'
    end

    describe '#provision' do
      before :each do
        expect(aws).to receive(:launch_all_nodes)
        expect(aws).to receive(:add_tags)
        expect(aws).to receive(:populate_dns)
        expect(aws).to receive(:enable_root_on_hosts)
        expect(aws).to receive(:set_hostnames)
        expect(aws).to receive(:configure_hosts)
      end

      it 'should step through provisioning' do
        aws.provision
      end

      it 'should return nil' do
        expect(aws.provision).to be_nil
      end
    end

    describe '#kill_instances' do
      let( :ec2_instance ) { double('ec2_instance', :nil? => false, :exists? => true, :id => "ec2", :terminate => nil) }
      let( :vpc_instance ) { double('vpc_instance', :nil? => false, :exists? => true, :id => "vpc", :terminate => nil) }
      let( :nil_instance ) { double('vpc_instance', :nil? => true, :exists? => true, :id => "nil", :terminate => nil) }
      let( :unreal_instance ) { double('vpc_instance', :nil? => false, :exists? => false, :id => "unreal", :terminate => nil) }

      it 'should return nil' do
        instance_set = [ec2_instance, vpc_instance, nil_instance, unreal_instance]
        expect(aws.kill_instances(instance_set)).to be_nil
      end
  
      it 'cleanly handles an empty instance list' do
        instance_set = []
        expect(aws.kill_instances(instance_set)).to be_nil
      end
  
      context 'in general use' do
        it 'terminates each running instance' do
          instance_set = [ec2_instance, vpc_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:terminate).once
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end
  
        it 'verifies instances are not nil' do
          instance_set = [ec2_instance, vpc_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:nil?)
            expect(instance).to receive(:terminate).once
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end
  
        it 'verifies instances exist in AWS' do
          instance_set = [ec2_instance, vpc_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:exists?)
            expect(instance).to receive(:terminate).once
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end
      end

      context 'for a single running instance' do
        it 'terminates the running instance' do
          instance_set = [ec2_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:terminate).once
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end
  
        it 'verifies instance is not nil' do
          instance_set = [ec2_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:nil?)
            expect(instance).to receive(:terminate).once
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end
  
        it 'verifies instance exists in AWS' do
          instance_set = [ec2_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:exists?)
            expect(instance).to receive(:terminate).once
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end
      end

      context 'when an instance does not exist' do
        it 'does not call terminate' do
          instance_set = [unreal_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:terminate).exactly(0).times
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end

        it 'verifies instance does not exist' do
          instance_set = [unreal_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:exists?).once
            expect(instance).to receive(:terminate).exactly(0).times
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end
      end

      context 'when an instance is nil' do
        it 'does not call terminate' do
          instance_set = [nil_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:terminate).exactly(0).times
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end

        it 'verifies instance is nil' do
          instance_set = [nil_instance]
          instance_set.each do |instance|
            expect(instance).to receive(:nil?).once
            expect(instance).to receive(:terminate).exactly(0).times
          end
          expect(aws.kill_instances(instance_set)).to be_nil
        end
      end

    end

    describe '#cleanup' do
      subject { aws.cleanup }
      let( :ec2_instance ) { double('ec2_instance', :nil? => false, :exists? => true, :terminate => nil, :id => 'id') }

      context 'with a list of hosts' do
        before :each do
          @hosts.each {|host| host['instance'] = ec2_instance}
        end

        it { is_expected.to be_nil }

        it 'kills instances' do
          expect(aws).to receive(:kill_instances).once
          is_expected.to be_nil
        end
      end

      context 'with an empty host list' do
        before :each do
          @hosts = []
        end

        it { is_expected.to be_nil }

        it 'kills instances' do
          expect(aws).to receive(:kill_instances).once
          is_expected.to be_nil
        end
      end
    end

    describe '#instance_by_id' do
      subject { aws.instance_by_id('my_id') }
      it { is_expected.to be_instance_of(AWS::EC2::Instance) }
    end

    describe '#instances', :wip do
    end

    describe '#vpc_by_id', :wip do
    end

    describe '#vpcs', :wip do
    end

    describe '#security_group_by_id', :wip do
    end

    describe '#security_groups', :wip do
    end

    describe '#kill_zombies', :wip do
    end

    describe '#kill_zombie_volumes', :wip do
    end

    describe '#create_instance', :wip do
    end

    describe '#launch_nodes_on_some_subnet', :wip do
    end

    describe '#launch_all_nodes', :wip do
    end

    describe '#wait_for_status', :wip do
    end

    describe '#add_tags', :wip do
    end

    describe '#populate_dns' do
      let( :vpc_instance ) { {ip_address: nil, private_ip_address: "vpc_private_ip", dns_name: "vpc_dns_name"} }
      let( :ec2_instance ) { {ip_address: "ec2_public_ip", private_ip_address: "ec2_private_ip", dns_name: "ec2_dns_name"} }

      context 'on a public EC2 instance' do
        before :each do
          @hosts.each {|host| host['instance'] = make_instance ec2_instance}
        end

        it 'sets host ip to instance.ip_address' do
          aws.populate_dns();
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['ip']).to eql(ec2_instance[:ip_address])
          end
        end

        it 'sets host private_ip to instance.private_ip_address' do
          aws.populate_dns();
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['private_ip']).to eql(ec2_instance[:private_ip_address])
          end
        end

        it 'sets host dns_name to instance.dns_name' do
          aws.populate_dns();
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['dns_name']).to eql(ec2_instance[:dns_name])
          end
        end
      end

      context 'on a VPC based instance' do
        before :each do
          @hosts.each {|host| host['instance'] = make_instance vpc_instance}
        end

        it 'sets host ip to instance.private_ip_address' do
          aws.populate_dns();
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['ip']).to eql(vpc_instance[:private_ip_address])
          end
        end

        it 'sets host private_ip to instance.private_ip_address' do
          aws.populate_dns();
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['private_ip']).to eql(vpc_instance[:private_ip_address])
          end
        end

        it 'sets host dns_name to instance.dns_name' do
          aws.populate_dns();
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['dns_name']).to eql(vpc_instance[:dns_name])
          end
        end
      end
    end

    describe '#configure_hosts', :wip do
    end

    describe '#enable_root_on_hosts' do
      context 'enabling root shall be called once for the ubuntu machine' do
        it "should enable root once" do
          expect( aws ).to receive(:copy_ssh_to_root).with( @hosts[3], options ).once()
          expect( aws ).to receive(:enable_root_login).with( @hosts[3], options).once()
          aws.enable_root_on_hosts();
        end
      end

      it 'enables root once on the f5 host through its code path' do
        expect( aws ).to receive(:enable_root_f5).with( @hosts[4] ).once()
        aws.enable_root_on_hosts()
      end
    end

    describe '#enable_root_f5' do
      it 'creates a password on the host' do
        f5_host = @hosts[4]
        result_mock = Beaker::Result.new(f5_host, '')
        result_mock.exit_code = 0
        allow( f5_host ).to receive( :exec ).and_return(result_mock)
        allow( aws ).to receive( :backoff_sleep )
        sha_mock = Object.new
        allow( Digest::SHA256 ).to receive( :new ).and_return(sha_mock)
        expect( sha_mock ).to receive( :hexdigest ).once()
        aws.enable_root_f5(f5_host)
      end

      it 'tries 10x before failing correctly' do
        f5_host = @hosts[4]
        result_mock = Beaker::Result.new(f5_host, '')
        result_mock.exit_code = 2
        allow( f5_host ).to receive( :exec ).and_return(result_mock)
        expect( aws ).to receive( :backoff_sleep ).exactly(9).times
        expect{ aws.enable_root_f5(f5_host) }.to raise_error( RuntimeError, /unable/ )
      end
    end

    describe '#set_hostnames', :wip do
    end

    describe '#backoff_sleep' do
      it "should call sleep 1024 times at attempt 10" do
        expect_any_instance_of( Object ).to receive(:sleep).with(1024)
        aws.backoff_sleep(10)
      end
    end

    context '#public_key' do
      it "retrieves contents from local ~/.ssh/ssh_rsa.pub file" do
        # Stub calls to file read/exists
        allow(File).to receive(:exists?).with(/id_rsa.pub/) { true }
        allow(File).to receive(:read).with(/id_rsa.pub/) { "foobar" }

        # Should return contents of allow( previously ).to receivebed id_rsa.pub
        expect(aws.public_key).to eq("foobar")
      end

      it "should return an error if the files do not exist" do
        expect { aws.public_key }.to raise_error(RuntimeError, /Expected either/)
      end
    end

    describe '#key_name' do
      it 'returns a key name from the local hostname' do
        # Mock out the hostname and local user calls
        expect( Socket ).to receive(:gethostname) { "foobar" }
        expect( aws ).to receive(:local_user) { "bob" }

        # Should match the expected composite key name
        expect(aws.key_name).to eq("Beaker-bob-foobar")
      end
    end

    describe '#local_user', :wip do
    end

    describe '#ensure_key_pair', :wip do
    end

    describe '#group_id' do
      it 'should return a predicatable group_id from a port list' do
        expect(aws.group_id([22, 1024])).to eq("Beaker-2799478787")
      end

      it 'should return a predicatable group_id from an empty list' do
        expect { aws.group_id([]) }.to raise_error(ArgumentError, "Ports list cannot be nil or empty")
      end
    end

    describe '#ensure_group', :wip do
    end

    describe '#create_group', :wip do
    end

    describe '#load_fog_credentials', :wip do
    end

  end
end
