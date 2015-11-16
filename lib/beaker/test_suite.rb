require 'beaker/runner/native/test_suite'

module Beaker
  class TestSuite < ::Beaker::Runner::Native::TestSuite
    def self.runner(runner)
      case runner
      when "beaker"
        Beaker::Runner::Native::TestSuite
      else
        nil
      end
    end
  end
end
