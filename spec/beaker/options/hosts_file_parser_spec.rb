require "spec_helper"

module Beaker
  module Options
    describe HostsFileParser do

      let(:parser)      {HostsFileParser}
      let(:filepath)    {File.join(File.expand_path(File.dirname(__FILE__)), "data", "hosts.cfg")}

      it "can correctly read a host file" do
        FakeFS.deactivate!
        config = parser.parse_hosts_file(filepath)
        expect(config).to be === {:HOSTS=>{:"pe-ubuntu-lucid"=>{:roles=>["agent", "dashboard", "database", "master"], :vmname=>"pe-ubuntu-lucid", :platform=>"ubuntu-10.04-i386", :snapshot=>"clean-w-keys", :hypervisor=>"fusion"}, :"pe-centos6"=>{:roles=>["agent"], :vmname=>"pe-centos6", :platform=>"el-6-i386", :hypervisor=>"fusion", :snapshot=>"clean-w-keys"}}, :nfs_server=>"none", :consoleport=>443}
      end

      it "can merge CONFIG section into overall hash" do
        FakeFS.deactivate!
        config = parser.parse_hosts_file(filepath)
        expect(config['CONFIG']).to be === nil
        expect(config['consoleport']).to be === 443
      end

      it "returns empty configuration when no file provided" do
        FakeFS.deactivate!
        expect(parser.parse_hosts_file()).to be === { :HOSTS => {} }
      end

      it "raises an error on no file found" do
        FakeFS.deactivate!
        expect{parser.parse_hosts_file("not a valid path")}.to raise_error(ArgumentError)
      end

      it "raises an error on bad yaml file" do
        FakeFS.deactivate!
        allow( YAML ).to receive(:load_file) { raise Psych::SyntaxError }
        allow( File ).to receive(:exists?).and_return(true)
        expect { parser.parse_hosts_file("not a valid path") }.to raise_error(ArgumentError)
      end

    end
  end
end
