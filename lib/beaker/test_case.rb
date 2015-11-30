require 'beaker/runner/native/test_case'

module Beaker
  # NOTE: This class is being preserved due to external library references
  #       directly to Beaker::TestCase. Once we break these external references
  #       (presumably via use of `Beaker::DSL.register`), this class can be
  #       removed.
  #
  # This class represents a single test case. A test case is necessarily
  # contained all in one file though may have multiple dependent examples.
  # They are executed in order (save for any teardown procs registered
  # through {Beaker::Runner::Native::Structure#teardown}) and once completed
  # the status of the TestCase is saved. Instance readers/accessors provide
  # the test case access to various details of the environment and suite
  # the test case is running within.
  #
  # See {Beaker::DSL} for more information about writing tests
  # using the DSL.
  class TestCase < Beaker::Runner::Native::TestCase
  end
end
