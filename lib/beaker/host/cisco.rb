%w[host command_factory].each do |lib|
  require "beaker/#{lib}"
end

module Cisco
  class Host < Unix::Host
    # as the cisco hosts tend to have custom
    # ssh configuration, the presets
    # do not apply where verification of the
    # host keys is disabled
    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
                'ssh' => {
                  :verify_host_key => false,
                },
              })
    end

    # Tells you whether a host platform supports beaker's
    #   {Beaker::HostPrebuiltSteps#set_env} method
    #
    # @return [String,nil] Reason message if set_env should be skipped,
    #   nil if it should run.
    def skip_set_env?
      'Cisco does not allow SSH control through the BASH shell'
    end

    # Handles host operations needed after an SCP takes place
    #
    # @param [String] scp_file_actual File path to actual SCP'd file on host
    # @param [String] scp_file_target File path to target SCP location on host
    #
    # @return nil
    def scp_post_operations(scp_file_actual, scp_file_target)
      execute("mv #{scp_file_actual} #{scp_file_target}") if self[:platform].include?('cisco_nexus')
      nil
    end

    # Handles any changes needed in a path for SCP
    #
    # @param [String] path File path to SCP to
    #
    # @return [String] path, changed if needed due to host
    #   constraints
    def scp_path(path)
      if self[:platform].include?('cisco_nexus')
        @home_dir ||= execute('pwd')
        answer = "#{@home_dir}/#{File.basename(path)}"
        answer << '/' if /\/$/.match?(path)
        return answer
      end
      path
    end

    # Gets the repo type for the given platform
    #
    # @raise [ArgumentError] For an unknown platform
    #
    # @return [String] Type of repo (rpm|deb)
    def repo_type
      'rpm'
    end

    # Gets the config dir location for package information
    #
    # @raise [ArgumentError] For an unknown platform
    #
    # @return [String] Path to package config dir
    def package_config_dir
      '/etc/yum/repos.d/'
    end

    # Gets the specific prepend commands as needed for this host
    #
    # @param [String] command Command to be executed
    # @param [String] user_pc List of user-specified commands to prepend
    # @param [Hash] opts optional parameters
    #
    # @return [String] Command string as needed for this host
    def prepend_commands(command = '', user_pc = '', _opts = {})
      return user_pc unless command.index('vsh').nil?

      if self[:platform].include?('cisco_nexus')
        return user_pc unless command.index('ntpdate').nil?
      end

      prepend_cmds = 'source /etc/profile;'
      prepend_cmds << " sudo -E sh -c \"" if self[:user] != 'root'
      prepend_cmds << "ip netns exec #{self[:vrf]} " if self[:vrf]
      prepend_cmds << "#{user_pc} " if user_pc && !user_pc.empty?
      prepend_cmds.strip
    end

    # Gets the specific append commands as needed for this host
    #
    # @param [String] command Command to be executed
    # @param [String] user_ac List of user-specified commands to append
    # @param [Hash] opts optional parameters
    #
    # @return [String] Command string as needed for this host
    def append_commands(command = '', _user_ac = '', _opts = {})
      command.gsub('"') { '\\"' }
      # vsh commands, ntpdate or when user is root commands do not require an appended `"`
      return '"' unless /ntpdate|\/isan\/bin\/vsh/.match?(command) || self[:user] == 'root'
    end

    # Construct the environment string for this command
    #
    # @param [Hash{String=>String}] env   An optional Hash containing
    #                                     key-value pairs to be treated
    #                                     as environment variables that
    #                                     should be set for the duration
    #                                     of the puppet command.
    #
    # @return [String] Returns a string containing command line arguments that
    #                  will ensure the environment is correctly set for the
    #                  given host.
    def environment_string env
      prestring = ''
      return prestring if env.empty?

      env_array = self.environment_variable_string_pair_array(env)
      environment_string = env_array.join(' ')

      prestring << if self[:platform].include?('cisco_nexus')
                     " export"
                   else
                     " env"
                   end
      environment_string = "#{prestring} #{environment_string}"
      environment_string << ';' if prestring.include?('export')
      environment_string
    end

    # Validates that the host was setup correctly
    #
    # @return nil
    # @raise [ArgumentError] If the host is setup incorrectly,
    #   this will be raised with the appropriate message
    def validate_setup
      msg = nil
      if self[:platform].include?('cisco_nexus')
        msg = 'Cisco Nexus hosts must be provided with a :vrf value.' if !self[:vrf]
        msg = 'Cisco hosts must be provided with a :user value' if !self[:user]
      end
      if self[:platform].include?('cisco_ios_xr')
        msg = 'Cisco hosts must be provided with a :user value' if !self[:user]
      end

      return unless msg

      msg << <<-EOF
          Check https://github.com/puppetlabs/beaker/blob/master/docs/hosts/cisco.md for more info.'
      EOF
      raise ArgumentError, msg
    end
  end
end
