require 'spec_helper'
require 'beaker/hypervisor/ec2_helper'

describe Beaker::EC2Helper do
  context ".amiports" do
    let(:ec2) { Beaker::EC2Helper }
    it "can set ports for database host" do
      expect(ec2.amiports(["database"])).to be === [22, 8080, 8081]
    end

    it "can set ports for master host" do
      expect(ec2.amiports(["master"])).to be === [22, 8140]
    end

    it "can set ports for dashboard host" do
      expect(ec2.amiports(["dashboard"])).to be === [22, 443]
    end

    it "can set ports for combined master/database/dashboard host" do
      expect(ec2.amiports(["dashboard", "master", "database"])).to be === [22, 8080, 8081, 8140, 443]
    end

    it "can add arbitrary ports passed in an array" do
      expect(ec2.amiports([],[8081,443])).to be === [22, 8081, 443]
    end

    it "can handle additional ports when a role is assigned" do
      expect(ec2.amiports(["master"],[8081,443])).to be === [22, 8140, 8081, 443]
    end

    it "can handle being passed an empty array when no role assigned" do
      expect(ec2.amiports([],[])).to be === [22]
    end

    it "can handle being passed an empty array when a role is assigned" do
      expect(ec2.amiports(["master"],[])).to be === [22,8140]
    end

    it "can handle being passed nil when no role assigned" do
      expect(ec2.amiports([],nil)).to be === [22]
    end

    it "can handle being passed nil when a role is assigned" do
      expect(ec2.amiports(["master"],nil)).to be === [22,8140]
    end
  end
end
