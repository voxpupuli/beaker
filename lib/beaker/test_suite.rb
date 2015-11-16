require 'beaker/runner/beaker/test_suite'

module Beaker
  class TestSuite < ::Beaker::Runner::Beaker::TestSuite
    def self.runner(runner)
      case runner
      when "beaker"
        Beaker::Runner::Beaker::TestSuite
      else
        nil
      end
    end
  end
end
