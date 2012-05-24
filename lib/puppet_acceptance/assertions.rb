require 'test/unit/assertions'

module PuppetAcceptance
  module Assertions
    include Test::Unit::Assertions

    # Make assertions about the content of console output.
    #
    # By default, each line of +output+ is assumed to come from STDOUT.  You may
    # specify the stream explicitly by annotating the line with a stream marker.
    # (If your line literally requires any stream marker at the beginning of a
    # line, you must prefix the line with an explicit stream marker.)  The
    # currently recognized markers are:
    #
    # * "STDOUT> "
    # * "STDERR> "
    # * "OUT> "
    # * "ERR> "
    # * "1> "
    # * "2> "
    #
    # Any leading common indentation is automatically removed from the +output+
    # parameter.  For cases where this matters (e.g. every line should be
    # indented), you should prefix the line with an explicit stream marker.
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
    # @param [String] output The expected console output, optionally annotated
    #                        with stream markers.
    # @param [String] msg An explanatory message about why the test failure is
    #                     relevant.
    def assert_output(output, msg='Output lines did not match')
      # Remove the minimal consistent indentation from the input; useful for clean HEREDOCs.
      indentation = output.lines.map { |line| line[/^ */].length }.min
      output = output.gsub(/^ {#{indentation}}/, '')

      # Divide output based on expected destination
      out, err = output.lines.partition { |line| line !~ /^((STD)?ERR|2)> / }
      out, err, output = [out.join, err.join, output].map do |str|
        str.gsub(/^((STD)?(ERR|OUT)|[12])> /, '')
      end

      # Exercise assertions about output
      assert_equal output, (result.nil? ? '' : result.output), msg
      assert_equal out,    (result.nil? ? '' : result.stdout), 'The contents of STDOUT did not match expectations'
      assert_equal err,    (result.nil? ? '' : result.stderr), 'The contents of STDERR did not match expectations'
    end
  end
end
