require 'beaker/runner/native/test_suite'
require 'beaker/runner/mini_test/test_suite'

module Beaker
  class TestSuite
    def self.runner(runner)
      case runner
      when "beaker"
        ::Beaker::Runner::Native::TestSuite
      when "minitest"
        ::Beaker::Runner::MiniTest::TestSuite
      else
        nil
      end
    end
  end
end
