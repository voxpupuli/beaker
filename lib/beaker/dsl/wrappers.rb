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
      # @api dsl
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
      # @api dsl
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
      # @api dsl
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
      # @api dsl
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
      # @param [Hash]     args      The commandline paramaeters to be passed to powershell
      #
      # @example Setting the contents of a file
      #     powershell("Set-Content -path 'fu.txt' -value 'fu'")
      #
      # @example Using an alternative execution policy
      #     powershell("Set-Content -path 'fu.txt' -value 'fu'", {'ExecutionPolicy' => 'Unrestricted'})
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
        ps_opts.merge!(args)

        arguments = " #{ps_opts.sort.map{|k,v| v.eql?('') ? "-#{k}" : "-#{k} #{v}" }.join(' ')} -Command \"#{command}\""
        Command.new('powershell.exe', arguments.split(' '), {})
      end
    end
  end
end
