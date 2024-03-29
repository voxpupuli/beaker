require "spec_helper"

module Beaker
  module Options
    describe OptionsFileParser do
      let(:parser) { described_class }
      let(:simple_opts) { File.join(__dir__, "data", "opts.txt") }

      it "can correctly read options from a file" do
        FakeFS.deactivate!
        expect(parser.parse_options_file(simple_opts)).to be === { :debug => true, :tests => "test.rb", :pre_suite => ["pre-suite.rb"], :post_suite => "post_suite1.rb,post_suite2.rb" }
      end

      it "raises an error on no file found" do
        FakeFS.deactivate!
        expect { parser.parse_options_file("not a valid path") }.to raise_error(ArgumentError)
      end
    end
  end
end
