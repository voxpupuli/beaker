require 'minitest/test'

module Beaker
  module DSL
    # Any custom assertions for Test::Unit or minitest live here. You may
    # include them in your own testing if you wish, override them, or re-open
    # the class to register new ones for use within
    # {Beaker::TestCase}.
    #
    # You may use any test/unit assertion within your assertion. The
    # assertion below assumes access to the method #result which will
    # contain the output (according to the interface defined in
    # {Beaker::Result}). When writing your own, to make them more
    # portable and less brittle it is recommended that you pass the result
    # or direct object for asserting against into your assertion.
    #
    module Assertions
      include Minitest::Assertions

      #Why do we need this accessor?
      # https://github.com/seattlerb/minitest/blob/master/lib/minitest/assertions.rb#L8-L12
      # Protocol: Nearly everything here boils up to +assert+, which
      # expects to be able to increment an instance accessor named
      # +assertions+. This is not provided by Assertions and must be
      # provided by the thing including Assertions. See Minitest::Runnable
      # for an example.
      attr_accessor :assertions
      def assertions
        @assertions || 0
      end

      # Make assertions about the content of console output.
      #
      # By default, each line of +output+ is assumed to come from STDOUT.
      # You may specify the stream explicitly by annotating the line with a
      # stream marker. (If your line literally requires any stream marker at
      # the beginning of a line, you must prefix the line with an explicit
      # stream marker.)  The currently recognized markers are:
      #
      # * "STDOUT> "
      # * "STDERR> "
      # * "OUT> "
      # * "ERR> "
      # * "1> "
      # * "2> "
      #
      # Any leading common indentation is automatically removed from the
      # +output+ parameter.  For cases where this matters (e.g. every line
      # should be indented), you should prefix the line with an explicit
      # stream marker.
      #
      # @example Assert order of interleaved output streams
      #   !!!plain
      #   assert_output <<-CONSOLE
      #     STDOUT> 0123456789
      #     STDERR> ^- This is left aligned
      #     STDOUT>   01234567890
      #     STDERR>   ^- This is indented 2 characters.
      #   CONSOLE
      #
      # @example Assert all content went to STDOUT
      #   !!!plain
      #   assert_output <<-CONSOLE
      #     0123456789
      #     ^- This is left aligned
      #       01234567890
      #       ^- This is indented 2 characters.
      #   CONSOLE
      #
      # @param [String] exp_out The expected console output, optionally
      #                         annotated with stream markers.
      # @param [String] msg     An explanatory message about why the test
      #                         failure is relevant.
      def assert_output(exp_out, msg='Output lines did not match')
        # Remove the minimal consistent indentation from the input;
        # useful for clean HEREDOCs.
        indentation = exp_out.lines.map { |line| line[/^ */].length }.min
        cleaned_exp = exp_out.gsub(/^ {#{indentation}}/, '')

        # Divide output based on expected destination
        out, err = cleaned_exp.lines.partition do |line|
          line !~ /^((STD)?ERR|2)> /
        end
        our_out, our_err, our_output = [
          out.join, err.join, cleaned_exp
        ].map do |str|
          str.gsub(/^((STD)?(ERR|OUT)|[12])> /, '')
        end

        # Exercise assertions about output
        assert_equal our_output, (result.nil? ? '' : result.output), msg
        assert_equal our_out,    (result.nil? ? '' : result.stdout),
          'The contents of STDOUT did not match expectations'
        assert_equal our_err,    (result.nil? ? '' : result.stderr),
          'The contents of STDERR did not match expectations'
      end

      # Assert that the provided string does not match the provided regular expression, can pass optional message
      # @deprecated This is placed her for backwards compatability for tests that used Test::Unit::Assertions,
      #             http://apidock.com/ruby/Test/Unit/Assertions/assert_no_match
      #             
      def assert_no_match(regexp, string, msg=nil)
        assert_instance_of(Regexp, regexp, "The first argument to assert_no_match should be a Regexp.")
        msg = message(msg) { "<#{mu_pp(regexp)}> expected to not match\n<#{mu_pp(string)}>" }
        assert(regexp !~ string, msg)
      end

      alias_method :assert_not_match, :assert_no_match

    end
  end
end
