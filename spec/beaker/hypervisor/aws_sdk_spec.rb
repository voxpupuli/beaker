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
      @hosts = make_hosts({:snapshot => :pe}, 4)
      @hosts[0][:platform] = "centos-5-x86-64-west"
      @hosts[1][:platform] = "centos-6-x86-64-west"
      @hosts[2][:platform] = "centos-7-x86-64-west"
      @hosts[3][:platform] = "ubuntu-12.04-amd64-west"
      @hosts[3][:user] = "ubuntu"
    end

    context 'enabling root shall be called once for the ubuntu machine' do
      it "should enable root once" do
        expect( aws ).to receive(:copy_ssh_to_root).with( @hosts[3], options ).once()
        expect( aws ).to receive(:enable_root_login).with( @hosts[3], options).once()
        aws.enable_root_on_hosts();
      end
    end

    context '#backoff_sleep' do
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

    context '#key_name' do
      it 'returns a key name from the local hostname' do
        # Mock out the hostname and local user calls
        expect( Socket ).to receive(:gethostname) { "foobar" }
        expect( aws ).to receive(:local_user) { "bob" }

        # Should match the expected composite key name
        expect(aws.key_name).to eq("Beaker-bob-foobar")
      end
    end

    context '#group_id' do
      it 'should return a predicatable group_id from a port list' do
        expect(aws.group_id([22, 1024])).to eq("Beaker-2799478787")
      end

      it 'should return a predicatable group_id from an empty list' do
        expect { aws.group_id([]) }.to raise_error(ArgumentError, "Ports list cannot be nil or empty")
      end
    end
  end
end
