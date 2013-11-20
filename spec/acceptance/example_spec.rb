require 'spec_helper'

describe "ignore" do

  example "ignore" do
    hosts.each do |host|
      on host, 'echo hello'
    end
  end

  hosts.each do |node|
    describe service('ssh'), :node => node do
      it { should be_running }
      it { should be_enabled }
    end
  end
end
