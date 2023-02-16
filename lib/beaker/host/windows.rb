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
      if status&.include?('4  RUNNING')
        @ssh_server = :bitvise
      else
        status = execute('cmd.exe /c sc qc sshd', :accept_all_exit_codes => true)
        if status&.include?('C:\\Windows\\System32\\OpenSSH\\sshd.exe')
          @ssh_server = :win32_openssh
        end
      end
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
