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

    # Gets the path & file name for the puppet agent dev package on Windows
    #
    # @param [String] puppet_collection Name of the puppet collection to use
    # @param [String] puppet_agent_version Version of puppet agent to get
    # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
    #
    # @note Windows only uses the 'install_32' option of the opts hash at this
    #   time. Note that it will not fail if not provided, however
    #
    # @return [String, String] Path to the directory and filename of the package, respectively
    def puppet_agent_dev_package_info( puppet_collection = nil, puppet_agent_version = nil, opts = {} )
      release_path_end = 'windows'
      is_config_32 = self['ruby_arch'] == 'x86' || self['install_32'] || opts['install_32']
      should_install_64bit = self.is_x86_64? && !is_config_32
      # only install 64bit builds if
      # - we do not have install_32 set on host
      # - we do not have install_32 set globally
      arch_suffix = should_install_64bit ? '64' : '86'
      release_file = "puppet-agent-x#{arch_suffix}.msi"
      return release_path_end, release_file
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
