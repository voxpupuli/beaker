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

      # This is hairy and because of legacy code it will take a bit more
      # work to disentangle all of the things that are being passed into
      # this catchall param.
      #
      def facter(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        options['ENV'] ||= {}
        options[:cmdexe] = true
        Command.new('facter', args, options )
      end

      # This is hairy and because of legacy code it will take a bit more
      # work to disentangle all of the things that are being passed into
      # this catchall param.
      #
      def cfacter(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        options['ENV'] ||= {}
        options[:cmdexe] = true
        Command.new('cfacter', args, options )
      end

      # This is hairy and because of legacy code it will take a bit more
      # work to disentangle all of the things that are being passed into
      # this catchall param.
      #
      def hiera(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        options['ENV'] ||= {}
        options[:cmdexe] = true
        Command.new('hiera', args, options )
      end

      # @param [String] command_string A string of to be interpolated
      #                                within the context of a host in
      #                                question
      # @example Usage
      # @!visibility private
      def host_command(command_string)
        HostCommand.new(command_string)
      end

      # This is hairy and because of legacy code it will take a bit more
      # work to disentangle all of the things that are being passed into
      # this catchall param.
      #
      def puppet(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        options['ENV'] ||= {}
        options[:cmdexe] = true
        # we assume that an invocation with `puppet()` will have it's first argument
        # a face or sub command
        cmd = "puppet #{args.shift}"
        Command.new( cmd, args, options )
      end

      # @!visibility private
      def puppet_resource(*args)
        puppet( 'resource', *args )
      end

      # @!visibility private
      def puppet_doc(*args)
        puppet( 'doc', *args )
      end

      # @!visibility private
      def puppet_kick(*args)
        puppet( 'kick', *args )
      end

      # @!visibility private
      def puppet_cert(*args)
        puppet( 'cert', *args )
      end

      # @!visibility private
      def puppet_apply(*args)
        puppet( 'apply', *args )
      end

      # @!visibility private
      def puppet_master(*args)
        puppet( 'master', *args )
      end

      # @!visibility private
      def puppet_agent(*args)
        puppet( 'agent', *args )
      end

      # @!visibility private
      def puppet_filebucket(*args)
        puppet( 'filebucket', *args )
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
        ps_opts.each do |k, v|
          if v.eql?('') or v.nil?
            ps_args << "-#{k}"
          elsif k.eql?('EncodedCommand') && v
            encoded = true
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
        if(defined?(cmd.encode))
          cmd = cmd.encode('ASCII-8BIT')
          cmd = Base64.strict_encode64(cmd)
        else
          cmd = Base64.encode64(cmd).chomp
        end
        cmd
      end

    end
  end
end
