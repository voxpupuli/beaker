require 'spec_helper'

module Beaker
  describe AwsSdk do
    let( :options ) { make_opts.merge({ 'logger' => double().as_null_object, 'timestamp' => Time.now }) }
    let(:aws) {
      # Mock out the call to load_fog_credentials
      allow_any_instance_of( Beaker::AwsSdk ).
        to receive(:load_fog_credentials).
        and_return({
          :access_key => fog_file_contents[:default][:aws_access_key_id],
          :secret_key => fog_file_contents[:default][:aws_secret_access_key],
        })


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
      @hosts = make_hosts({:snapshot => :pe}, 6)
      @hosts[0][:platform] = "centos-5-x86-64-west"
      @hosts[1][:platform] = "centos-6-x86-64-west"
      @hosts[2][:platform] = "centos-7-x86-64-west"
      @hosts[3][:platform] = "ubuntu-12.04-amd64-west"
      @hosts[3][:user] = "ubuntu"
      @hosts[4][:platform] = 'f5-host'
      @hosts[4][:user] = 'notroot'
      @hosts[5][:platform] = 'netscaler-host'

      ENV['AWS_ACCESS_KEY'] = nil
      ENV['AWS_SECRET_ACCESS_KEY'] = nil
    end

    context 'loading credentials' do

      it 'from .fog file' do
        creds = aws.load_fog_credentials
        expect( creds[:access_key] ).to eq("IMANACCESSKEY")
        expect( creds[:secret_key] ).to eq("supersekritkey")
      end


      it 'from environment variables' do
        ENV['AWS_ACCESS_KEY_ID'] = "IMANACCESSKEY"
        ENV['AWS_SECRET_ACCESS_KEY'] = "supersekritkey"

        creds = aws.load_env_credentials
        expect( creds[:access_key] ).to eq("IMANACCESSKEY")
        expect( creds[:secret_key] ).to eq("supersekritkey")
      end
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
        allow( aws ).to receive( :wait_for_status_netdev )
        aws.provision
      end

      it 'should return nil' do
        allow( aws ).to receive( :wait_for_status_netdev )
        expect(aws.provision).to be_nil
      end
    end

    describe '#kill_instances' do
      let( :ec2_instance ) { double('ec2_instance', :nil? => false, :exists? => true, :id => "ec2", :terminate => nil) }
      let( :vpc_instance ) { double('vpc_instance', :nil? => false, :exists? => true, :id => "vpc", :terminate => nil) }
      let( :nil_instance ) { double('vpc_instance', :nil? => true, :exists? => true, :id => "nil", :terminate => nil) }
      let( :unreal_instance ) { double('vpc_instance', :nil? => false, :exists? => false, :id => "unreal", :terminate => nil) }
      subject(:kill_instances) { aws.kill_instances(instance_set) }

      it 'should return nil' do
        instance_set = [ec2_instance, vpc_instance, nil_instance, unreal_instance]
        expect(aws.kill_instances(instance_set)).to be_nil
      end

      it 'cleanly handles an empty instance list' do
        instance_set = []
        expect(aws.kill_instances(instance_set)).to be_nil
      end

      context 'in general use' do
        let( :instance_set ) { [ec2_instance, vpc_instance] }

        it 'terminates each running instance' do
          instance_set.each do |instance|
            expect(instance).to receive(:terminate).once
          end
          expect(kill_instances).to be_nil
        end

        it 'verifies instances are not nil' do
          instance_set.each do |instance|
            expect(instance).to receive(:nil?)
            allow(instance).to receive(:terminate).once
          end
          expect(kill_instances).to be_nil
        end

        it 'verifies instances exist in AWS' do
          instance_set.each do |instance|
            expect(instance).to receive(:exists?)
            allow(instance).to receive(:terminate).once
          end
          expect(kill_instances).to be_nil
        end
      end

      context 'for a single running instance' do
        let( :instance_set ) { [ec2_instance] }

        it 'terminates the running instance' do
          instance_set.each do |instance|
            expect(instance).to receive(:terminate).once
          end
          expect(kill_instances).to be_nil
        end

        it 'verifies instance is not nil' do
          instance_set.each do |instance|
            expect(instance).to receive(:nil?)
            allow(instance).to receive(:terminate).once
          end
          expect(kill_instances).to be_nil
        end

        it 'verifies instance exists in AWS' do
          instance_set.each do |instance|
            expect(instance).to receive(:exists?)
            allow(instance).to receive(:terminate).once
          end
          expect(kill_instances).to be_nil
        end
      end

      context 'when an instance does not exist' do
        let( :instance_set ) { [unreal_instance] }

        it 'does not call terminate' do
          instance_set.each do |instance|
            expect(instance).to receive(:terminate).exactly(0).times
          end
          expect(kill_instances).to be_nil
        end

        it 'verifies instance does not exist' do
          instance_set.each do |instance|
            expect(instance).to receive(:exists?).once
            allow(instance).to receive(:terminate).exactly(0).times
          end
          expect(kill_instances).to be_nil
        end
      end

      context 'when an instance is nil' do
        let( :instance_set ) { [nil_instance] }

        it 'does not call terminate' do
          instance_set.each do |instance|
            expect(instance).to receive(:terminate).exactly(0).times
          end
          expect(kill_instances).to be_nil
        end

        it 'verifies instance is nil' do
          instance_set.each do |instance|
            expect(instance).to receive(:nil?).once
            allow(instance).to receive(:terminate).exactly(0).times
          end
          expect(kill_instances).to be_nil
        end
      end

    end

    describe '#cleanup' do
      subject(:cleanup) { aws.cleanup }
      let( :ec2_instance ) { double('ec2_instance', :nil? => false, :exists? => true, :terminate => nil, :id => 'id') }

      context 'with a list of hosts' do
        before :each do
          @hosts.each {|host| host['instance'] = ec2_instance}
          expect(aws).to receive( :delete_key_pair_all_regions )
        end

        it { is_expected.to be_nil }

        it 'kills instances' do
          expect(aws).to receive(:kill_instances).once
          expect(cleanup).to be_nil
        end
      end

      context 'with an empty host list' do
        before :each do
          @hosts = []
          expect(aws).to receive( :delete_key_pair_all_regions )
        end

        it { is_expected.to be_nil }

        it 'kills instances' do
          expect(aws).to receive(:kill_instances).once
          expect(cleanup).to be_nil
        end
      end
    end

    describe '#log_instances', :wip do
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

    describe '#kill_zombies' do
      it 'calls delete_key_pair_all_regions' do
        ec2_mock = Object.new
        allow(ec2_mock).to receive( :regions ).and_return( {} )
        aws.instance_variable_set( :@ec2, ec2_mock )

        expect( aws ).to receive( :delete_key_pair_all_regions ).once

        aws.kill_zombies()
      end
    end

    describe '#kill_zombie_volumes', :wip do
    end

    describe '#create_instance', :wip do
    end

    describe '#launch_nodes_on_some_subnet', :wip do
    end

    describe '#launch_all_nodes', :wip do
    end

    describe '#wait_for_status' do
      let( :aws_instance ) { double('aws_instance', :id => "ec2", :terminate => nil) }
      let( :instance_set ) { [{:instance => aws_instance}] }
      subject(:wait_for_status) { aws.wait_for_status(:running, instance_set) }

      context 'single instance' do
        it 'behaves correctly in typical case' do
          allow(aws_instance).to receive(:status).and_return(:waiting, :waiting, :running)
          expect(aws).to receive(:backoff_sleep).exactly(3).times
          expect(wait_for_status).to eq(instance_set)
        end

        it 'executes block correctly instead of status if given one' do
          barn_value = 'did you grow up in a barn?'
          allow(aws_instance).to receive( :[] ).with( :barn ) { barn_value }
          expect(aws_instance).to receive(:status).exactly(0).times
          expect(aws).to receive(:backoff_sleep).exactly(1).times
          aws.wait_for_status(:running, instance_set) do |instance|
            expect( instance[:barn] ).to be === barn_value
            true
          end
        end
      end

      context 'with multiple instances' do
        let( :instance_set ) { [{:instance => aws_instance}, {:instance => aws_instance}] }

        it 'returns the instance set passed to it' do
          allow(aws_instance).to receive(:status).and_return(:waiting, :waiting, :running, :waiting, :waiting, :running)
          allow(aws).to receive(:backoff_sleep).exactly(6).times
          expect(wait_for_status).to eq(instance_set)
        end

        it 'calls backoff_sleep once per instance.status call' do
          allow(aws_instance).to receive(:status).and_return(:waiting, :waiting, :running, :waiting, :waiting, :running)
          expect(aws).to receive(:backoff_sleep).exactly(6).times
          expect(wait_for_status).to eq(instance_set)
        end

        it 'executes block correctly instead of status if given one' do
          barn_value = 'did you grow up in a barn?'
          not_barn_value = 'notabarn'
          allow(aws_instance).to receive( :[] ).with( :barn ).and_return(not_barn_value, barn_value, not_barn_value, barn_value)
          allow(aws_instance).to receive(:status).and_return(:waiting)
          expect(aws).to receive(:backoff_sleep).exactly(4).times
          aws.wait_for_status(:running, instance_set) do |instance|
            instance[:barn] == barn_value
          end
        end
      end

      context 'after 10 tries' do
        it 'raises RuntimeError' do
          expect(aws_instance).to receive(:status).and_return(:waiting).exactly(10).times
          expect(aws).to receive(:backoff_sleep).exactly(9).times
          expect { wait_for_status }.to raise_error('Instance never reached state running')
        end

        it 'still raises RuntimeError if given a block' do
          expect(aws_instance).to receive(:status).and_return(:waiting).exactly(10).times
          expect(aws).to receive(:backoff_sleep).exactly(9).times
          expect { wait_for_status { false } }.to raise_error('Instance never reached state running')
        end
      end

      context 'with an invalid instance' do
        it 'raises AWS::EC2::Errors::InvalidInstanceID::NotFound' do
          expect(aws_instance).to receive(:status).and_raise(AWS::EC2::Errors::InvalidInstanceID::NotFound).exactly(10).times
          allow(aws).to receive(:backoff_sleep).at_most(10).times
          expect(wait_for_status).to eq(instance_set)
        end
      end
    end

    describe '#add_tags' do
      let( :aws_instance ) { double('aws_instance', :add_tag => nil) }
      subject(:add_tags) { aws.add_tags }

      it 'returns nil' do
        @hosts.each {|host| host['instance'] = aws_instance}
        expect(add_tags).to be_nil
      end

      it 'handles a single host' do
        @hosts[0]['instance'] = aws_instance
        @hosts = [@hosts[0]]
        expect(add_tags).to be_nil
      end

      context 'with multiple hosts' do
        before :each do
          @hosts.each {|host| host['instance'] = aws_instance}
        end

        it 'handles host_tags hash on host object' do
          # set :host_tags on first host
          aws.instance_eval {
            @hosts[0][:host_tags] =  {'test_tag' => 'test_value'}
          }
          expect(aws_instance).to receive(:add_tag).with('test_tag', hash_including(:value => 'test_value')).at_least(:once)
          expect(add_tags).to be_nil
        end

        it 'adds tag for jenkins_build_url' do
          aws.instance_eval('@options[:jenkins_build_url] = "my_build_url"')
          expect(aws_instance).to receive(:add_tag).with('jenkins_build_url', hash_including(:value => 'my_build_url')).at_least(:once)
          expect(add_tags).to be_nil
        end

        it 'adds tag for Name' do
          expect(aws_instance).to receive(:add_tag).with('Name', hash_including(:value => /vm/)).at_least(@hosts.size).times
          expect(add_tags).to be_nil
        end

        it 'adds tag for department' do
          aws.instance_eval('@options[:department] = "my_department"')
          expect(aws_instance).to receive(:add_tag).with('department', hash_including(:value => 'my_department')).at_least(:once)
          expect(add_tags).to be_nil
        end

        it 'adds tag for project' do
          aws.instance_eval('@options[:project] = "my_project"')
          expect(aws_instance).to receive(:add_tag).with('project', hash_including(:value => 'my_project')).at_least(:once)
          expect(add_tags).to be_nil
        end

        it 'adds tag for created_by' do
          aws.instance_eval('@options[:created_by] = "my_created_by"')
          expect(aws_instance).to receive(:add_tag).with('created_by', hash_including(:value => 'my_created_by')).at_least(:once)
          expect(add_tags).to be_nil
        end
      end
    end

    describe '#populate_dns' do
      let( :vpc_instance ) { {ip_address: nil, private_ip_address: "vpc_private_ip", dns_name: "vpc_dns_name"} }
      let( :ec2_instance ) { {ip_address: "ec2_public_ip", private_ip_address: "ec2_private_ip", dns_name: "ec2_dns_name"} }
      subject(:populate_dns) { aws.populate_dns }

      context 'on a public EC2 instance' do
        before :each do
          @hosts.each {|host| host['instance'] = make_instance ec2_instance}
        end

        it 'sets host ip to instance.ip_address' do
          populate_dns
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['ip']).to eql(ec2_instance[:ip_address])
          end
        end

        it 'sets host private_ip to instance.private_ip_address' do
          populate_dns
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['private_ip']).to eql(ec2_instance[:private_ip_address])
          end
        end

        it 'sets host dns_name to instance.dns_name' do
          populate_dns
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
          populate_dns
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['ip']).to eql(vpc_instance[:private_ip_address])
          end
        end

        it 'sets host private_ip to instance.private_ip_address' do
          populate_dns
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['private_ip']).to eql(vpc_instance[:private_ip_address])
          end
        end

        it 'sets host dns_name to instance.dns_name' do
          populate_dns
          hosts =  aws.instance_variable_get( :@hosts )
          hosts.each do |host|
            expect(host['dns_name']).to eql(vpc_instance[:dns_name])
          end
        end
      end
    end

    describe '#etc_hosts_entry' do
      let( :host ) { @hosts[0] }
      let( :interface ) { :ip }
      subject(:etc_hosts_entry) { aws.etc_hosts_entry(host, interface) }

      it 'returns a predictable host entry' do
        expect(aws).to receive(:get_domain_name).and_return('lan')
        expect(etc_hosts_entry).to eq("ip.address.for.vm1\tvm1 vm1.lan vm1.box.tld\n")
      end

      context 'when :private_ip is requested' do
        let( :interface ) { :private_ip }
        it 'returns host entry for the private_ip' do
          host = @hosts[0]
          expect(aws).to receive(:get_domain_name).and_return('lan')
          expect(etc_hosts_entry).to eq("private.ip.for.vm1\tvm1 vm1.lan vm1.box.tld\n")
        end
      end
    end

    describe '#configure_hosts' do
      subject(:configure_hosts) { aws.configure_hosts }

      it { is_expected.to be_nil }

      context 'calls #set_etc_hosts' do
        it 'for each host (except the f5 ones)' do
          non_netdev_hosts = @hosts.select{ |h| !(h['platform'] =~ /f5|netscaler/) }
          expect(aws).to receive(:set_etc_hosts).exactly(non_netdev_hosts.size).times
          expect(configure_hosts).to be_nil
        end

        it 'with predictable host entries' do
          @hosts = [@hosts[0], @hosts[1]]
          entries = "127.0.0.1\tlocalhost localhost.localdomain\n"\
                    "private.ip.for.vm1\tvm1 vm1.lan vm1.box.tld\n"\
                    "ip.address.for.vm2\tvm2 vm2.lan vm2.box.tld\n"
          allow(aws).to receive(:get_domain_name).and_return('lan')
          expect(aws).to receive(:set_etc_hosts).with(@hosts[0], entries)
          expect(aws).to receive(:set_etc_hosts).with(@hosts[1], anything)
          expect(configure_hosts).to be_nil
        end
      end
    end

    describe '#enable_root_on_hosts' do
      context 'enabling root shall be called once for the ubuntu machine' do
        it "should enable root once" do
          allow(aws).to receive(:enable_root_netscaler)
          expect( aws ).to receive(:copy_ssh_to_root).with( @hosts[3], options ).once()
          expect( aws ).to receive(:enable_root_login).with( @hosts[3], options).once()
          aws.enable_root_on_hosts();
        end
      end

      it 'enables root once on the f5 host through its code path' do
        allow(aws).to receive(:enable_root_netscaler)
        expect( aws ).to receive(:enable_root_f5).with( @hosts[4] ).once()
        aws.enable_root_on_hosts()
      end
    end

    describe '#enable_root_f5' do
      let( :f5_host ) { @hosts[4] }
      subject(:enable_root_f5) { aws.enable_root_f5(f5_host) }

      it 'creates a password on the host' do
        result_mock = Beaker::Result.new(f5_host, '')
        result_mock.exit_code = 0
        allow( f5_host ).to receive( :exec ).and_return(result_mock)
        allow( aws ).to receive( :backoff_sleep )
        sha_mock = Object.new
        allow( Digest::SHA256 ).to receive( :new ).and_return(sha_mock)
        expect( sha_mock ).to receive( :hexdigest ).once()
        enable_root_f5
      end

      it 'tries 10x before failing correctly' do
        result_mock = Beaker::Result.new(f5_host, '')
        result_mock.exit_code = 2
        allow( f5_host ).to receive( :exec ).and_return(result_mock)
        expect( aws ).to receive( :backoff_sleep ).exactly(9).times
        expect{ enable_root_f5 }.to raise_error( RuntimeError, /unable/ )
      end
    end

    describe '#enable_root_netscaler' do
      let( :ns_host ) { @hosts[5] }
      subject(:enable_root_netscaler) { aws.enable_root_netscaler(ns_host) }

      it 'set password to instance id of the host' do
        instance_mock = Object.new
        allow( instance_mock ).to receive(:id).and_return("i-842018")
        ns_host["instance"]=instance_mock
        enable_root_netscaler
        expect(ns_host['ssh'][:password]).to eql("i-842018")
      end
    end

    describe '#set_hostnames' do
      subject(:set_hostnames) { aws.set_hostnames }
      it 'returns @hosts' do
        expect(set_hostnames).to eq(@hosts)
      end

      context 'for each host' do
        it 'calls exec' do
          @hosts.each do |host|
            expect(host).to receive(:exec).once unless host['platform'] =~ /netscaler/
          end
          expect(set_hostnames).to eq(@hosts)
        end

        it 'passes a Command instance to exec' do
          @hosts.each do |host|
            expect(host).to receive(:exec).with( instance_of(Beaker::Command) ).once unless host['platform'] =~ /netscaler/
          end
          expect(set_hostnames).to eq(@hosts)
        end

        it 'sets the the vmhostname to the dns_name for each host' do
          expect(set_hostnames).to eq(@hosts)
          @hosts.each do |host|
            expect(host[:vmhostname]).to eq(host[:dns_name])
            expect(host[:vmhostname]).to eq(host.hostname)
          end
        end

        it 'sets the the vmhostname to the beaker config name for each host' do
          options[:use_beaker_hostnames] = true
	  @hosts.each do |host|
            host[:name] = "prettyponyprincess"
	  end
          expect(set_hostnames).to eq(@hosts)
          @hosts.each do |host|
            puts host[:name]
            expect(host[:vmhostname]).to eq(host[:name])
            expect(host[:vmhostname]).to eq(host.hostname)
          end
        end

      end
    end

    describe '#backoff_sleep' do
      it "should call sleep 1024 times at attempt 10" do
        expect_any_instance_of( Object ).to receive(:sleep).with(1024)
        aws.backoff_sleep(10)
      end
    end

    describe '#public_key' do
      subject(:public_key) { aws.public_key }

      it "retrieves contents from local ~/.ssh/id_rsa.pub file" do
        # Stub calls to file read/exists
        key_value = 'foobar_Rsa'
        allow(File).to receive(:exists?).with(/id_dsa.pub/) { false }
        allow(File).to receive(:exists?).with(/id_rsa.pub/) { true }
        allow(File).to receive(:read).with(/id_rsa.pub/) { key_value }

        # Should return contents of allow( previously ).to receivebed id_rsa.pub
        expect(public_key).to be === key_value
      end

      it "retrieves contents from local ~/.ssh/id_dsa.pub file" do
        # Stub calls to file read/exists
        key_value = 'foobar_Dsa'
        allow(File).to receive(:exists?).with(/id_rsa.pub/) { false }
        allow(File).to receive(:exists?).with(/id_dsa.pub/) { true }
        allow(File).to receive(:read).with(/id_dsa.pub/) { key_value }

        expect(public_key).to be === key_value
      end

      it "should return an error if the files do not exist" do
        expect { public_key }.to raise_error(RuntimeError, /Expected to find a public key/)
      end

      it "uses options-provided keys" do
        opts = aws.instance_variable_get( :@options )
        opts[:ssh][:keys] = ['fake_key1', 'fake_key2']
        aws.instance_variable_set( :@options, opts )

        key_value = 'foobar_Custom2'
        allow(File).to receive(:exists?).with(anything) { false }
        allow(File).to receive(:exists?).with(/fake_key2/) { true }
        allow(File).to receive(:read).with(/fake_key2/) { key_value }

        expect(public_key).to be === key_value
      end
    end

    describe '#key_name' do
      it 'returns a key name from the local hostname' do
        # Mock out the hostname and local user calls
        expect( Socket ).to receive(:gethostname) { "foobar" }
        expect( aws ).to receive(:local_user) { "bob" }

        # Should match the expected composite key name
        expect(aws.key_name).to match(/^Beaker-bob-foobar-/)
      end

      it 'uses the generated random string from :aws_keyname_modifier' do
        expect(aws.key_name).to match(/#{options[:aws_keyname_modifier]}/)
      end

      it 'uses nanosecond time value to make key name collision harder' do
        options[:timestamp] = Time.now
        nanosecond_value = options[:timestamp].strftime("%N")
        expect(aws.key_name).to match(/#{nanosecond_value}/)
      end
    end

    describe '#local_user' do
      it 'returns ENV["USER"]' do
        stub_const('ENV', ENV.to_hash.merge('USER' => 'SuperUser'))
        expect(aws.local_user).to eq("SuperUser")
      end
    end

    describe '#ensure_key_pair' do
      let( :region ) { double('region', :name => 'test_region_name') }
      subject(:ensure_key_pair) { aws.ensure_key_pair(region) }
      let( :key_name ) { "Beaker-rspec-SUT" }

      it 'deletes the given keypair, then recreates it' do
        allow( aws ).to receive( :key_name ).and_return(key_name)

        expect( aws ).to receive( :delete_key_pair ).with( region, key_name).once.ordered
        expect( aws ).to receive( :create_new_key_pair ).with( region, key_name).once.ordered
        ensure_key_pair
      end
    end

    describe '#delete_key_pair_all_regions' do
      it 'calls delete_key_pair over all regions' do
        key_name = 'kname_test1538'
        allow(aws).to receive( :key_name ).and_return(key_name)
        regions = []
        regions << double('region', :key_pairs => 'pair1', :name => 'name1')
        regions << double('region', :key_pairs => 'pair2', :name => 'name2')
        ec2_mock = Object.new
        allow(ec2_mock).to receive( :regions ).and_return(regions)
        aws.instance_variable_set( :@ec2, ec2_mock )
        region_keypairs_hash_mock = {}
        region_keypairs_hash_mock[double('region')] = ['key1', 'key2', 'key3']
        region_keypairs_hash_mock[double('region')] = ['key4', 'key5', 'key6']
        allow( aws ).to receive( :my_key_pairs ).and_return( region_keypairs_hash_mock )

        region_keypairs_hash_mock.each_pair do |region, keyname_array|
          keyname_array.each do |keyname|
            expect( aws ).to receive( :delete_key_pair ).with( region, keyname )
          end
        end
        aws.delete_key_pair_all_regions
      end
    end

    describe '#my_key_pairs' do
      let( :region ) { double('region', :name => 'test_region_name') }

      it 'uses the default keyname if no filter is given' do
        default_keyname_answer = 'test_pair_6193'
        allow( aws ).to receive( :key_name ).and_return( default_keyname_answer )

        kp_mock_1 = double('keypair')
        kp_mock_2 = double('keypair')
        regions = []
        regions << double('region', :key_pairs => kp_mock_1, :name => 'name1')
        regions << double('region', :key_pairs => kp_mock_2, :name => 'name2')
        ec2_mock = Object.new
        allow( ec2_mock ).to receive( :regions ).and_return( regions )
        aws.instance_variable_set( :@ec2, ec2_mock )

        kp_mock = double('keypair')
        allow( region ).to receive( :key_pairs ).and_return( kp_mock )
        expect( kp_mock_1 ).to receive( :filter ).with( 'key-name', default_keyname_answer ).and_return( [] )
        expect( kp_mock_2 ).to receive( :filter ).with( 'key-name', default_keyname_answer ).and_return( [] )

        aws.my_key_pairs()
      end

      it 'uses the filter passed if given' do
        default_keyname_answer = 'test_pair_6194'
        allow( aws ).to receive( :key_name ).and_return( default_keyname_answer )
        name_filter = 'filter_pair_1597'
        filter_star = "#{name_filter}-*"

        kp_mock_1 = double('keypair')
        kp_mock_2 = double('keypair')
        regions = []
        regions << double('region', :key_pairs => kp_mock_1, :name => 'name1')
        regions << double('region', :key_pairs => kp_mock_2, :name => 'name2')
        ec2_mock = Object.new
        allow( ec2_mock ).to receive( :regions ).and_return( regions )
        aws.instance_variable_set( :@ec2, ec2_mock )

        kp_mock = double('keypair')
        allow( region ).to receive( :key_pairs ).and_return( kp_mock )
        expect( kp_mock_1 ).to receive( :filter ).with( 'key-name', filter_star ).and_return( [] )
        expect( kp_mock_2 ).to receive( :filter ).with( 'key-name', filter_star ).and_return( [] )

        aws.my_key_pairs(name_filter)
      end
    end

    describe '#delete_key_pair' do
      let( :region ) { double('region', :name => 'test_region_name') }

      it 'calls delete on a keypair if it exists' do
        pair_name = 'pair1'
        kp_mock = double('keypair', :exists? => true)
        expect( kp_mock ).to receive( :delete ).once
        pairs = { pair_name => kp_mock }
        allow( region ).to receive( :key_pairs ).and_return( pairs )
        aws.delete_key_pair(region, pair_name)
      end

      it 'skips delete on a keypair if it does not exist' do
        pair_name = 'pair1'
        kp_mock = double('keypair', :exists? => false)
        expect( kp_mock ).to receive( :delete ).never
        pairs = { pair_name => kp_mock }
        allow( region ).to receive( :key_pairs ).and_return( pairs )
        aws.delete_key_pair(region, pair_name)
      end
    end

    describe '#create_new_key_pair' do
      let(:region) { double('region', :name => 'test_region_name') }
      let(:ssh_string) { 'ssh_string_test_0867' }
      let(:pairs) { double('keypairs') }
      let(:pair) { double('keypair') }
      let(:pair_name) { 'pair_name_1555432' }

      before :each do
        allow(aws).to receive(:public_key).and_return(ssh_string)
        expect(pairs).to receive(:import).with(pair_name, ssh_string)
        expect(pairs).to receive(:[]).with(pair_name).and_return(pair)
        expect(region).to receive(:key_pairs).and_return(pairs).twice
      end

      it 'imports the key given from public_key' do
        expect(pair).to receive(:exists?).and_return(true)
        aws.create_new_key_pair(region, pair_name)
      end

      it 'raises an exception if subsequent keypair check is false' do
        expect(pair).to receive(:exists?).and_return(false).exactly(5).times
        expect(aws).to receive(:backoff_sleep).exactly(5).times
        expect { aws.create_new_key_pair(region, pair_name) }.
          to raise_error(RuntimeError,
            "AWS key pair #{pair_name} can not be queried, even after import")
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
      subject(:ensure_group) { aws.ensure_group(vpc, ports) }

      context 'for an existing group' do
        before :each do
          @group = double(:nil? => false)
        end

        it 'returns group from vpc lookup' do
          expect(vpc).to receive_message_chain('security_groups.filter.first').and_return(@group)
          expect(ensure_group).to eq(@group)
        end

        context 'during group lookup' do
          it 'performs group_id lookup for ports' do
            expect(aws).to receive(:group_id).with(ports)
            expect(vpc).to receive_message_chain('security_groups.filter.first').and_return(@group)
            expect(ensure_group).to eq(@group)
          end

          it 'filters on group_id' do
            expect(vpc).to receive(:security_groups).and_return(vpc)
            expect(vpc).to receive(:filter).with('group-name', 'Beaker-1521896090').and_return(vpc)
            expect(vpc).to receive(:first).and_return(@group)
            expect(ensure_group).to eq(@group)
          end
        end
      end

      context 'when group does not exist' do
        it 'creates group if group.nil?' do
          group = double(:nil? => true)
          expect(aws).to receive(:create_group).with(vpc, ports).and_return(group)
          expect(vpc).to receive_message_chain('security_groups.filter.first').and_return(group)
          expect(ensure_group).to eq(group)
        end
      end
    end

    describe '#create_group' do
      let( :rv ) { double('rv') }
      let( :ports ) { [22, 80, 8080] }
      subject(:create_group) { aws.create_group(rv, ports) }

      before :each do
        @group = double(:nil? => false)
      end

      it 'returns a newly created group' do
        allow(rv).to receive_message_chain('security_groups.create').and_return(@group)
        allow(@group).to receive(:authorize_ingress).at_least(:once)
        expect(create_group).to eq(@group)
      end

      it 'requests group_id for ports given' do
        expect(aws).to receive(:group_id).with(ports)
        allow(rv).to receive_message_chain('security_groups.create').and_return(@group)
        allow(@group).to receive(:authorize_ingress).at_least(:once)
        expect(create_group).to eq(@group)
      end

      it 'creates group with expected arguments' do
        group_name = "Beaker-1521896090"
        group_desc = "Custom Beaker security group for #{ports.to_a}"
        expect(rv).to receive_message_chain('security_groups.create')
                  .with(group_name, :description => group_desc)
                  .and_return(@group)
        allow(@group).to receive(:authorize_ingress).at_least(:once)
        expect(create_group).to eq(@group)
      end

      it 'authorizes requested ports for group' do
        expect(rv).to receive_message_chain('security_groups.create').and_return(@group)
        ports.each do |port|
          expect(@group).to receive(:authorize_ingress).with(:tcp, port).once
        end
        expect(create_group).to eq(@group)
      end
    end

    describe '#load_fog_credentials' do
      # Receive#and_call_original below allows us to test the core load_fog_credentials method
      let(:creds) { {:access_key => 'awskey', :secret_key => 'awspass'} }
      let(:dot_fog) { '.fog' }
      subject(:load_fog_credentials) { aws.load_fog_credentials(dot_fog) }

      it 'returns loaded fog credentials' do
        fog_hash = {:default => {:aws_access_key_id => 'awskey', :aws_secret_access_key => 'awspass'}}
        expect(aws).to receive(:load_fog_credentials).and_call_original
        expect(YAML).to receive(:load_file).and_return(fog_hash)
        expect(load_fog_credentials).to eq(creds)
      end

      context 'raises errors' do
        it 'if missing access_key credential' do
          fog_hash = {:default => {:aws_secret_access_key => 'awspass'}}
          err_text = "You must specify an aws_access_key_id in your .fog file (#{dot_fog}) for ec2 instances!"
          expect(aws).to receive(:load_fog_credentials).and_call_original
          expect(YAML).to receive(:load_file).and_return(fog_hash)
          expect { load_fog_credentials }.to raise_error(err_text)
        end

        it 'if missing secret_key credential' do
          dot_fog = '.fog'
          fog_hash = {:default => {:aws_access_key_id => 'awskey'}}
          err_text = "You must specify an aws_secret_access_key in your .fog file (#{dot_fog}) for ec2 instances!"
          expect(aws).to receive(:load_fog_credentials).and_call_original
          expect(YAML).to receive(:load_file).and_return(fog_hash)
          expect { load_fog_credentials }.to raise_error(err_text)
        end
      end
    end
  end
end
