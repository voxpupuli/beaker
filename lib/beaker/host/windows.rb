[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
      require "beaker/#{lib}"
end

module Windows
  # A windows host with cygwin tools installed
  class Host < Unix::Host
    [ 'user', 'group', 'exec', 'pkg', 'file' ].each do |lib|
          require "beaker/host/windows/#{lib}"
    end

    include Windows::User
    include Windows::Group
    include Windows::File
    include Windows::Exec
    include Windows::Pkg

    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'          => 'Administrator',
        'group'         => 'Administrators',
        'pathseparator' => ';',
      })
    end

    def external_copy_base
      return @external_copy_base if @external_copy_base
      @external_copy_base = execute('echo `cygpath -smF 35`/')
      @external_copy_base
    end

    # Determines which SSH Server is in use on this host
    #
    # @return [Symbol] Value for the SSH Server in use
    #   (:bitvise or :openssh at this point).
    def determine_ssh_server
      return @ssh_server if @ssh_server
      @ssh_server = :openssh
      status = execute('cmd.exe /c sc query BvSshServer', :accept_all_exit_codes => true)
      @ssh_server = :bitvise if status =~ /4  RUNNING/
      logger.debug("windows.rb:determine_ssh_server: determined ssh server: '#{@ssh_server}'")
      @ssh_server
    end

    attr_reader :scp_separator
    def initialize name, host_hash, options
      super

      @ssh_server         = nil
      @scp_separator      = '\\'
      @external_copy_base = nil
    end

  end
end
