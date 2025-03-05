require 'spec_helper'

class WindowsUserTest
  include Windows::User
end

describe WindowsUserTest do
  let(:host) { double.as_null_object }
  let(:result) { Beaker::Result.new(host, command) }

  describe '#user_list' do
    let(:command) { 'cmd /c echo "" | wmic useraccount where localaccount="true" get name /format:value' }

    let(:wmic_output) do
      <<~EOS
        Name=Administrator





        Name=bob foo





        Name=bob-dash





        Name=bob.foo





        Name=cyg_server








      EOS
    end

    it 'returns user names list correctly' do
      result.stdout = wmic_output
      expect(subject).to receive(:execute).with(command).and_yield(result)
      expect(subject.user_list).to be === ['Administrator', 'bob foo', 'bob-dash', 'bob.foo', 'cyg_server']
    end

    it 'yields correctly with the result object' do
      result.stdout = wmic_output
      expect(subject).to receive(:execute).and_yield(result)
      subject.user_list do |result|
        expect(result.stdout).to be === wmic_output
      end
    end
  end

  describe "#user_list_using_powershell" do
    let(:beaker_command) { instance_spy(Beaker::Command) }
    let(:command) { '-Command "Get-LocalUser | Select-Object -ExpandProperty Name"' }
    let(:user_list_using_powershell_output) do
      <<~EOS
        Administrator
        WDAGUtilityAccount
      EOS
    end

    it 'returns user names list correctly' do
      result.stdout = user_list_using_powershell_output
      allow(Beaker::Command).to receive(:new).with('powershell.exe', array_including(command)).and_return(beaker_command)

      expect(subject).to receive(:exec).with(beaker_command).and_return(result)
      expect(subject.user_list_using_powershell).to be === ["Administrator", "WDAGUtilityAccount"]
    end
  end
end
