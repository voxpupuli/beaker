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

    describe '#instances' do
      subject { aws.instances }
      it { is_expected.to be_instance_of(AWS::EC2::InstanceCollection) }
    end

    describe '#vpc_by_id' do
      subject { aws.vpc_by_id('my_id') }
      it { is_expected.to be_instance_of(AWS::EC2::VPC) }
    end

    describe '#vpcs' do
      subject { aws.vpcs }
      it { is_expected.to be_instance_of(AWS::EC2::VPCCollection) }
    end

    describe '#security_group_by_id' do
      subject { aws.security_group_by_id('my_id') }
      it { is_expected.to be_instance_of(AWS::EC2::SecurityGroup) }
    end

    describe '#security_groups' do
      subject { aws.security_groups }
      it { is_expected.to be_instance_of(AWS::EC2::SecurityGroupCollection) }
    end

    describe '#create_instance', :wip do
    end

    describe '#launch_nodes_on_some_subnet', :wip do
    end

    describe '#launch_all_nodes', :wip do
    end

    describe '#wait_for_status' do
      let( :aws_instance ) { double('aws_instance', :id => "ec2", :terminate => nil) }
      it 'handles a single instance' do
        instance_set = [ {:instance => aws_instance} ]
        allow(aws_instance).to receive(:status).and_return(:waiting, :waiting, :running)
        expect(aws).to receive(:backoff_sleep).exactly(3).times
        expect(aws.wait_for_status(:running, instance_set)).to eq(instance_set)
      end

      context 'with multiple instances' do
        before :each do
          @instance_set = [ {:instance => aws_instance}, {:instance => aws_instance} ]
        end

        it 'returns the instance set passed to it' do
          allow(aws_instance).to receive(:status).and_return(:waiting, :waiting, :running, :waiting, :waiting, :running)
          allow(aws).to receive(:backoff_sleep).exactly(6).times
          expect(aws.wait_for_status(:running, @instance_set)).to eq(@instance_set)
        end

        it 'calls backoff_sleep once per instance.status call' do
          allow(aws_instance).to receive(:status).and_return(:waiting, :waiting, :running, :waiting, :waiting, :running)
          expect(aws).to receive(:backoff_sleep).exactly(6).times
          expect(aws.wait_for_status(:running, @instance_set)).to eq(@instance_set)
        end
      end

      context 'after 10 tries' do
        it 'raises RuntimeError' do
          instance_set = [ {:instance => aws_instance} ]
          allow(aws_instance).to receive(:status).and_return(:waiting)
          expect(aws).to receive(:backoff_sleep).exactly(9).times
          expect { aws.wait_for_status(:running, instance_set) }.to raise_error('Instance never reached state running')
        end
      end

      context 'with an invalid instance' do
        it 'raises AWS::EC2::Errors::InvalidInstanceID::NotFound' do
          instance_set = [ {:instance => aws_instance} ]
          allow(aws_instance).to receive(:status).and_raise(AWS::EC2::Errors::InvalidInstanceID::NotFound)
          allow(aws).to receive(:backoff_sleep).at_most(10).times
          expect(aws.wait_for_status(:running, instance_set)).to eq(instance_set)
        end
      end
    end

    describe '#add_tags' do
      let( :aws_instance ) { double('aws_instance', :add_tag => nil) }

      it 'returns nil' do
        @hosts.each {|host| host['instance'] = aws_instance}
        expect(aws.add_tags).to be_nil
      end

      it 'handles a single host' do
        @hosts[0]['instance'] = aws_instance
        @hosts = [@hosts[0]]
        expect(aws.add_tags).to be_nil
      end

      context 'with multiple hosts' do
        before :each do
          @hosts.each {|host| host['instance'] = aws_instance}
        end

        it 'adds tag for jenkins_build_url' do
          aws.instance_eval('@options[:jenkins_build_url] = "my_build_url"')
          expect(aws_instance).to receive(:add_tag).with('jenkins_build_url', hash_including(:value => 'my_build_url')).at_least(:once)
          expect(aws.add_tags).to be_nil
        end

        it 'adds tag for Name' do
          expect(aws_instance).to receive(:add_tag).with('Name', hash_including(:value => /vm/)).at_least(@hosts.size).times
          expect(aws.add_tags).to be_nil
        end

        it 'adds tag for department' do
          aws.instance_eval('@options[:department] = "my_department"')
          expect(aws_instance).to receive(:add_tag).with('department', hash_including(:value => 'my_department')).at_least(:once)
          expect(aws.add_tags).to be_nil
        end

        it 'adds tag for project' do
          aws.instance_eval('@options[:project] = "my_project"')
          expect(aws_instance).to receive(:add_tag).with('project', hash_including(:value => 'my_project')).at_least(:once)
          expect(aws.add_tags).to be_nil
        end

        it 'adds tag for created_by' do
          aws.instance_eval('@options[:created_by] = "my_created_by"')
          expect(aws_instance).to receive(:add_tag).with('created_by', hash_including(:value => 'my_created_by')).at_least(:once)
          expect(aws.add_tags).to be_nil
        end
      end
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

    describe '#set_hostnames' do
      it 'returns @hosts' do
        expect(aws.set_hostnames).to eq(@hosts)
      end

      context 'for each host' do
        it 'calls exec' do
          @hosts.each {|host| expect(host).to receive(:exec).once}
          expect(aws.set_hostnames).to eq(@hosts)
        end
  
        it 'passes a Command instance to exec' do
          @hosts.each do |host|
            expect(host).to receive(:exec).with( instance_of(Beaker::Command) ).once
          end
          expect(aws.set_hostnames).to eq(@hosts)
        end
      end
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

    describe '#local_user' do
      it 'returns ENV["USER"]' do
        stub_const('ENV', ENV.to_hash.merge('USER' => 'SuperUser'))
        expect(aws.local_user).to eq("SuperUser")
      end
    end

    describe '#ensure_key_pair' do
      let( :region ) { double('region') }

      context 'when a beaker keypair already exists' do
        it 'returns the keypair if available' do
          stub_const('ENV', ENV.to_hash.merge('USER' => 'rspec'))
          key_pair = double(:exists? => true, :secret => 'supersekritkey')
          key_pairs = { "Beaker-rspec-SUT" => key_pair }

          expect( region ).to receive(:key_pairs).and_return(key_pairs).once
          expect( Socket ).to receive(:gethostname).and_return("SUT")
          expect(aws.ensure_key_pair(region)).to eq(key_pair)
        end
      end

      context 'when a pre-existing keypair cannot be found' do
        let( :key_name ) { "Beaker-rspec-SUT" }
        let( :key_pair ) { double(:exists? => false) }
        let( :key_pairs ) { { key_name => key_pair } }
        let( :pubkey ) { "Beaker-rspec-SUT_secret-key" }

        before :each do
          stub_const('ENV', ENV.to_hash.merge('USER' => 'rspec'))
          expect( region ).to receive(:key_pairs).and_return(key_pairs).once
          expect( Socket ).to receive(:gethostname).and_return("SUT")
        end

        it 'imports a new key based on user pubkey' do
          allow(aws).to receive(:public_key).and_return(pubkey)
          expect( key_pairs ).to receive(:import).with(key_name, pubkey)
          expect(aws.ensure_key_pair(region))
        end

        it 'returns imported keypair' do
          allow(aws).to receive(:public_key)
          expect( key_pairs ).to receive(:import).and_return(key_pair).once
          expect(aws.ensure_key_pair(region)).to eq(key_pair)
        end
      end
    end

    describe '#group_id' do
      it 'should return a predicatable group_id from a port list' do
        expect(aws.group_id([22, 1024])).to eq("Beaker-2799478787")
      end

      it 'should return a predicatable group_id from an empty list' do
        expect { aws.group_id([]) }.to raise_error(ArgumentError, "Ports list cannot be nil or empty")
      end
    end

    describe '#ensure_group' do
      let( :vpc ) { double('vpc') }
      let( :ports ) { [22, 80, 8080] }

      context 'for an existing group' do
        before :each do
          @group = double(:nil? => false)
        end

        it 'returns group from vpc lookup' do
          expect(vpc).to receive_message_chain('security_groups.filter.first').and_return(@group)
          expect(aws.ensure_group(vpc, ports)).to eq(@group)
        end

        context 'during group lookup' do
          it 'performs group_id lookup for ports' do
            expect(aws).to receive(:group_id).with(ports)
            expect(vpc).to receive_message_chain('security_groups.filter.first').and_return(@group)
            expect(aws.ensure_group(vpc, ports)).to eq(@group)
          end

          it 'filters on group_id' do
            expect(vpc).to receive(:security_groups).and_return(vpc)
            expect(vpc).to receive(:filter).with('group-name', 'Beaker-1521896090').and_return(vpc)
            expect(vpc).to receive(:first).and_return(@group)
            expect(aws.ensure_group(vpc, ports)).to eq(@group)
          end
        end
      end

      context 'when group does not exist' do
        it 'creates group if group.nil?' do
          group = double(:nil? => true)
          expect(aws).to receive(:create_group).with(vpc, ports).and_return(group)
          expect(vpc).to receive_message_chain('security_groups.filter.first').and_return(group)
          expect(aws.ensure_group(vpc, ports)).to eq(group)
        end
      end
    end

    describe '#create_group', :wip do
      it 'returns a newly created group' do
      end

      it 'requests group_id for ports given' do
      end

      it 'authorizes requested ports for group' do
      end
    end

    describe '#load_fog_credentials', :wip do
      it 'returns fog credentials' do
      end

      context 'raises errors' do
        it 'if missing access_key credential' do
        end
  
        it 'if missing secret_key credential' do
        end
      end
    end

  end
end
