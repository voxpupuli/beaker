require 'spec_helper'
require 'beaker/hypervisor/ec2_helper'

describe Beaker::EC2Helper do
  context ".amiports" do
    let(:ec2) { Beaker::EC2Helper }
    it "can set ports for database host" do
      expect(ec2.amiports(["database"])).to be === [22, 61613, 8139, 8080, 8081]
    end

    it "can set ports for master host" do
      expect(ec2.amiports(["master"])).to be === [22, 61613, 8139, 8140]
    end

    it "can set ports for dashboard host" do
      expect(ec2.amiports(["dashboard"])).to be === [22, 61613, 8139, 443]
    end

    it "can set ports for combined master/database/dashboard host" do
      expect(ec2.amiports(["dashboard", "master", "database"])).to be === [22, 61613, 8139, 8080, 8081, 8140, 443]
    end
  end
end
