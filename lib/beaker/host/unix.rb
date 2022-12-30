[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
      require "beaker/#{lib}"
end

module Unix
  class Host < Beaker::Host
    [ 'user', 'group', 'exec', 'pkg', 'file' ].each do |lib|
          require "beaker/host/unix/#{lib}"
    end

    include Unix::User
    include Unix::Group
    include Unix::File
    include Unix::Exec
    include Unix::Pkg

    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'             => 'root',
        'group'            => 'root',
        'pathseparator'    => ':',
      })
    end

    # Determines which SSH Server is in use on this host
    #
    # @note This method is mostly a placeholder method, since only :openssh
    #   can be returned at this time. Checkout {Windows::Host#determine_ssh_server}
    #   for an example where work needs to be done to determine the answer
    #
    # @return [Symbol] Value for the SSH Server in use
    def determine_ssh_server
      :openssh
    end

    def external_copy_base
      @external_copy_base ||= begin
        if self['platform'].variant == 'solaris' && self['platform'].version == '10'
          # Solaris 10 uses / as the root user directory. Solaris 11 uses /root (like most).
          '/'
        else
          '/root'
        end
      end
    end

    # Tells you whether a host platform supports beaker's
    #   {Beaker::HostPrebuiltSteps#set_env} method
    #
    # @return [String,nil] Reason message if set_env should be skipped,
    #   nil if it should run.
    def skip_set_env?
      case self['platform'].variant
      when /^(f5|netscaler)$/
        "no puppet-agent package for network device platform '#{self['platform'].variant}'"
      else
        nil
      end
    end

    # Validates that the host was setup correctly
    #
    # @return nil
    # @raise [ArgumentError] If the host is setup incorrectly,
    #   this will be raised with the appropriate message
    def validate_setup
      nil
    end

    def initialize name, host_hash, options
      super

      @external_copy_base = nil
    end

  end
end
