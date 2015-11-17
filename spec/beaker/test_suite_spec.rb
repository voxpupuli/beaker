require "spec_helper"
require "beaker/test_suite"

module Beaker
  describe TestSuite do
    context "runner" do
      it "returns the native test suite class when the 'beaker' runner name is provided" do
        expect(Beaker::TestSuite.runner("beaker")).to be == Beaker::Runner::Native::TestSuite
      end

      it "returns the minitest test suite class when the 'minitest' runner name is provided" do
        expect(Beaker::TestSuite.runner("minitest")).to be == Beaker::Runner::MiniTest::TestSuite
      end

      it "returns nil when unknown runner name is provided" do
        expect(Beaker::TestSuite.runner("unknown")).to be_nil
      end
    end
  end
end
