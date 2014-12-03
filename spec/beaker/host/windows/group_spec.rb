require 'spec_helper'

module Beaker
  describe Windows::Group do
    class WindowsGroupTest
      include Windows::Group
    end

    let(:instance) { WindowsGroupTest.new }
    let(:result) { double(:result, :stdout => group_list_output) }
    let(:group_list_output) do <<-EOS


Name=Foo


Name=Bar6


      EOS
    end

    def add_group(group_name)
      group_list_output << <<-EOS
Name=#{group_name}


      EOS
    end

    before(:each) do
      expect( instance ).to receive(:execute).with(/wmic group where/).and_yield(result)
    end

    it "gets a group_list" do
      expect(instance.group_list).to eql(["Foo", "Bar6"])
    end

    it "gets groups with spaces" do
      add_group("With Spaces")
      expect(instance.group_list).to eql(["Foo", "Bar6", "With Spaces"])
    end


    it "gets groups with dashes" do
      add_group("With-Dashes")
      expect(instance.group_list).to eql(["Foo", "Bar6", "With-Dashes"])
    end

    it "gets groups with underscores" do
      add_group("With_Underscores")
      expect(instance.group_list).to eql(["Foo", "Bar6", "With_Underscores"])
    end
  end
end
