require 'spec_helper'

module Beaker
  describe Windows::Group do
    class WindowsGroupTest
      include Windows::Group
    end

    let(:instance) { WindowsGroupTest.new }

    context "Group list" do
      let(:result) { double(:result, :stdout => group_list_output) }
      let(:group_list_output) do
        <<~EOS
          Foo

          Bar6


        EOS
      end

      def add_group(group_name)
        group_list_output << <<~EOS
          #{group_name}


        EOS
      end

      before do
        expect(instance).to receive(:execute).with(/Win32_Group/).and_yield(result)
      end

      it "gets a group_list" do
        expect(instance.group_list).to eql(%w[Foo Bar6])
      end

      it "gets groups with spaces" do
        add_group("With Spaces")
        expect(instance.group_list).to eql(["Foo", "Bar6", "With Spaces"])
      end

      it "gets groups with dashes" do
        add_group("With-Dashes")
        expect(instance.group_list).to eql(%w[Foo Bar6 With-Dashes])
      end

      it "gets groups with underscores" do
        add_group("With_Underscores")
        expect(instance.group_list).to eql(%w[Foo Bar6 With_Underscores])
      end
    end

    context "Group list using powershell" do
      let(:group_list_using_powershell_output) do
        <<~EOS
          Foo1
          Bar5
        EOS
      end

      let(:result1) { double(:result1, :stdout => group_list_using_powershell_output) }

      it "gets a group_list using powershell" do
        expect(instance).to receive(:execute).with(/powershell.exe "Get-LocalGroup | Select-Object -ExpandProperty Name/).and_yield(result1)
        expect(instance.group_list_using_powershell).to eql(%w[Foo1 Bar5])
      end
    end
  end
end
