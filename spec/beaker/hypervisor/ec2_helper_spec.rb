require 'spec_helper'
require 'beaker/hypervisor/ec2_helper'

describe Beaker::EC2Helper do
  context ".amiports" do
    let(:ec2) { Beaker::EC2Helper }

    let(:master_host)  do
      opts = { :snapshot => :pe, :roles => ['master'], :additional_ports => 9999 }
      make_host('master', opts)
    end

    let(:database_host)  do
      opts = { :snapshot => :pe, :roles => ['database'], :additional_ports => [1111, 5432] }
      make_host('database', opts)
    end

    let(:dashboard_host)  do
      opts = { :snapshot => :pe, :roles => ['dashboard'], :additional_ports => 2003 }
      make_host('dashboard', opts)
    end

    let(:all_in_one_host)  do
      opts = { :snapshot => :pe, :roles => ['master', 'database', 'dashboard']}
      make_host('all_in_one', opts)
    end

    it "can set ports for database host" do
      expect(ec2.amiports(database_host)).to be === [22, 61613, 8139, 5432, 8080, 8081, 1111]
    end

    it "can set ports for master host" do
      expect(ec2.amiports(master_host)).to be === [22, 61613, 8139, 8140, 8142, 9999]
    end

    it "can set ports for dashboard host" do
      expect(ec2.amiports(dashboard_host)).to be === [22, 61613, 8139, 443, 4433, 4435, 2003]
    end

    it "can set ports for combined master/database/dashboard host" do
      expect(ec2.amiports(all_in_one_host)).to be === [22, 61613, 8139, 5432, 8080, 8081, 8140, 8142, 443, 4433, 4435]
    end
  end
end
