require 'spec_helper'

module Beaker
  describe PSWindows::Group do
    let(:instance) { Class.new { include PSWindows::Group }.new }
    let(:command) { 'cmd /c echo "" | powershell.exe "Get-LocalGroup | Select-Object -ExpandProperty Name"' }
    let(:result) { Beaker::Result.new(double.as_null_object, command) }

    describe '#group_list' do
      it 'returns the group names without blank lines' do
        result.stdout = <<~OUTPUT
          Administrators
          With Spaces

        OUTPUT
        expect(instance).to receive(:execute).with(command).and_yield(result)
        expect(instance.group_list).to eq(['Administrators', 'With Spaces'])
      end
    end
  end
end
