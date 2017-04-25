require 'base64'
module Beaker
  module DSL
    # These are wrappers to equivalent {Beaker::Command} objects
    # so that command line actions are executed within an appropriate and
    # configurable environment.
    #
    # I find most of these adapters of suspicious value and have deprecated
    # many of them.
    module Wrappers

      # @param [String] command_string A string of to be interpolated
      #                                within the context of a host in
      #                                question
      # @example Usage
      # @!visibility private
      def host_command(command_string)
        HostCommand.new(command_string)
      end

      # Returns a {Beaker::Command} object for executing powershell commands on a host
      #
      # @param [String]   command   The powershell command to execute
      # @param [Hash]     args      The commandline parameters to be passed to powershell
      #
      # @example Setting the contents of a file
      #     powershell("Set-Content -path 'fu.txt' -value 'fu'")
      #
      # @example Using an alternative execution policy
      #     powershell("Set-Content -path 'fu.txt' -value 'fu'", {'ExecutionPolicy' => 'Unrestricted'})
      #
      # @example Using an EncodedCommand (defaults to non-encoded)
      #     powershell("Set Content -path 'fu.txt', -value 'fu'", {'EncodedCommand => true})
      #
      # @example executing from a file
      #     powershell("", {'-File' => '/path/to/file'})
      #
      # @return [Command]
      def powershell(command, args={})
        ps_opts = {
          'ExecutionPolicy' => 'Bypass',
          'InputFormat'     => 'None',
          'NoLogo'          => '',
          'NoProfile'       => '',
          'NonInteractive'  => ''
        }
        encoded = false
        ps_opts.merge!(args)
        ps_args = []

        # determine if the command should be encoded
        if ps_opts.has_key?('EncodedCommand')
          v = ps_opts.delete('EncodedCommand')
          # encode the commend if v is true, nil or empty
          encoded = v || v.eql?('') || v.nil?
        end

        ps_opts.each do |k, v|
          if v.eql?('') or v.nil?
            ps_args << "-#{k}"
          else
            ps_args << "-#{k} #{v}"
          end
        end

        # may not have a command if executing a file
        if command && !command.empty?
          if encoded
            ps_args << "-EncodedCommand #{encode_command(command)}"
          else
            ps_args << "-Command #{command}"
          end
        end

        Command.new("powershell.exe", ps_args)
      end

      # Convert the provided command string to Base64
      # @param [String] cmd The command to convert to Base64
      # @return [String] The converted string
      # @api private
      def encode_command(cmd)
        cmd = cmd.chars.to_a.join("\x00").chomp
        cmd << "\x00" unless cmd[-1].eql? "\x00"
        # use strict_encode because linefeeds are not correctly handled in our model
        cmd = Base64.strict_encode64(cmd).chomp
        cmd
      end

    end
  end
end
