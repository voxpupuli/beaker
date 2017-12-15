module Unix::Exec
  include Beaker::CommandFactory

  def reboot
    if self['platform'] =~ /solaris/
      exec(Beaker::Command.new("reboot"), :expect_connection_failure => true)
    else
      exec(Beaker::Command.new("/sbin/shutdown -r now"), :expect_connection_failure => true)
    end
    sleep(10) #if we attempt a reconnect too quickly we end up blocking ¯\_(ツ)_/¯
  end

  def echo(msg, abs=true)
    (abs ? '/bin/echo' : 'echo') + " #{msg}"
  end

  def touch(file, abs=true)
    (abs ? '/bin/touch' : 'touch') + " #{file}"
  end

  def path
    '/bin:/usr/bin'
  end

  def get_ip
    if self['platform'].include?('solaris') || self['platform'].include?('osx')
      execute("ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1").strip
    else
      execute("ip a | awk '/global/{print$2}' | cut -d/ -f1 | #{self['hypervisor'] == 'vagrant' ? 'tail' : 'head'} -1").strip
    end
  end

  # Create the provided directory structure on the host
  # @param [String] dir The directory structure to create on the host
  # @return [Boolean] True, if directory construction succeeded, otherwise False
  def mkdir_p dir
    cmd = "mkdir -p #{dir}"
    result = exec(Beaker::Command.new(cmd), :acceptable_exit_codes => [0, 1])
    result.exit_code == 0
  end

  # Recursively remove the path provided
  # @param [String] path The path to remove
  def rm_rf path
    execute("rm -rf #{path}")
  end

  # Move the origin to destination. The destination is removed prior to moving.
  # @param [String] orig The origin path
  # @param [String] dest the destination path
  # @param [Boolean] rm Remove the destination prior to move
  def mv orig, dest, rm=true
    rm_rf dest unless !rm
    execute("mv #{orig} #{dest}")
  end

  # Attempt to ping the provided target hostname
  # @param [String] target The hostname to ping
  # @param [Integer] attempts Amount of times to attempt ping before giving up
  # @return [Boolean] true of ping successful, overwise false
  def ping target, attempts=5
    try = 0
    while try < attempts do
      result = exec(Beaker::Command.new("ping -c 1 #{target}"), :accept_all_exit_codes => true)
      if result.exit_code == 0
        return true
      end
      try+=1
    end
    result.exit_code == 0
  end

  # Converts the provided environment file to a new shell script in /etc/profile.d, then sources that file.
  # This is for sles and debian based hosts.
  # @param [String] env_file The ssh environment file to read from
  def mirror_env_to_profile_d env_file
    if self[:platform] =~ /sles-|debian/
      @logger.debug("mirroring environment to /etc/profile.d on sles platform host")
      cur_env = exec(Beaker::Command.new("cat #{env_file}")).stdout
      shell_env = ''
      cur_env.each_line do |env_line|
        shell_env << "export #{env_line}"
      end
      #here doc it over
      exec(Beaker::Command.new("cat << EOF > #{self[:profile_d_env_file]}\n#{shell_env}EOF"))
      #set permissions
      exec(Beaker::Command.new("chmod +x #{self[:profile_d_env_file]}"))
      #keep it current
      exec(Beaker::Command.new("source #{self[:profile_d_env_file]}"))
    else
      #noop
      @logger.debug("will not mirror environment to /etc/profile.d on non-sles/debian platform host")
    end
  end

  #Add the provided key/val to the current ssh environment
  #@param [String] key The key to add the value to
  #@param [String] val The value for the key
  #@example
  #  host.add_env_var('PATH', '/usr/bin:PATH')
  def add_env_var key, val
    key = key.to_s
    env_file = self[:ssh_env_file]
    escaped_val = Regexp.escape(val).gsub('/', '\/').gsub(';', '\;')
    #see if the key/value pair already exists
    if exec(Beaker::Command.new("grep ^#{key}=.*#{escaped_val} #{env_file}"), :accept_all_exit_codes => true ).exit_code == 0
      return #nothing to do here, key value pair already exists
    #see if the key already exists
    elsif exec(Beaker::Command.new("grep ^#{key}= #{env_file}"), :accept_all_exit_codes => true ).exit_code == 0
      exec(Beaker::SedCommand.new(self['platform'], "s/^#{key}=/#{key}=#{escaped_val}:/", env_file))
    else
      exec(Beaker::Command.new("echo \"#{key}=#{val}\" >> #{env_file}"))
    end
    #update the profile.d to current state
    #match it to the contents of ssh_env_file
    mirror_env_to_profile_d(env_file)
  end

  #Delete the provided key/val from the current ssh environment
  #@param [String] key The key to delete the value from
  #@param [String] val The value to delete for the key
  #@example
  #  host.delete_env_var('PATH', '/usr/bin:PATH')
  def delete_env_var key, val
    key = key.to_s
    env_file = self[:ssh_env_file]
    val = Regexp.escape(val).gsub('/', '\/').gsub(';', '\;')
    #if the key only has that single value remove the entire line
    exec(Beaker::SedCommand.new(self['platform'], "/#{key}=#{val}$/d", env_file))
    #value in middle of list
    exec(Beaker::SedCommand.new(self['platform'], "s/#{key}=\\(.*\\)[;:]#{val}/#{key}=\\1/", env_file))
    #value in start of list
    exec(Beaker::SedCommand.new(self['platform'], "s/#{key}=#{val}[;:]/#{key}=/", env_file))
    #update the profile.d to current state
    #match it to the contents of ssh_env_file
    mirror_env_to_profile_d(env_file)
  end

  #Return the value of a specific env var
  #@param [String] key The key to look for
  #@example
  #  host.get_env_var('path')
  def get_env_var key
    key = key.to_s
    exec(Beaker::Command.new("env | grep ^#{key}="), :accept_all_exit_codes => true).stdout.chomp
  end

  #Delete the environment variable from the current ssh environment
  #@param [String] key The key to delete
  #@example
  #  host.clear_env_var('PATH')
  def clear_env_var key
    key = key.to_s
    env_file = self[:ssh_env_file]
    #remove entire line
    exec(Beaker::SedCommand.new(self['platform'], "/^#{key}=.*$/d", env_file))
    #update the profile.d to current state
    #match it to the contents of ssh_env_file
    mirror_env_to_profile_d(env_file)
  end

  # Restarts the SSH service.
  #
  # @return [Result] result of restarting the SSH service
  def ssh_service_restart
    case self['platform']
    when /debian|ubuntu|cumulus|huaweios/
      exec(Beaker::Command.new("service ssh restart"))
    when /el-7|centos-7|redhat-7|oracle-7|scientific-7|eos-7|fedora-(1[4-9]|2[0-9])|archlinux-/
      exec(Beaker::Command.new("systemctl restart sshd.service"))
    when /el-|centos|fedora|redhat|oracle|scientific|eos/
      exec(Beaker::Command.new("/sbin/service sshd restart"))
    when /sles/
      exec(Beaker::Command.new("rcsshd restart"))
    when /solaris/
      exec(Beaker::Command.new("svcadm restart svc:/network/ssh:default"))
    when /(free|open)bsd/
      exec(Beaker::Command.new("sudo /etc/rc.d/sshd restart"))
    else
      raise ArgumentError, "Unsupported Platform: '#{self['platform']}'"
    end
  end

  # Sets the PermitUserEnvironment setting & restarts the SSH service.
  #
  # @api private
  # @return [Result] result of the command restarting the SSH service
  #   (from {#ssh_service_restart}).
  def ssh_permit_user_environment
    case self['platform']
    when /debian|ubuntu|cumulus|huaweios|archlinux/
      directory = create_tmpdir_on(self)
      exec(Beaker::Command.new("echo 'PermitUserEnvironment yes' | cat - /etc/ssh/sshd_config > #{directory}/sshd_config.permit"))
      exec(Beaker::Command.new("mv #{directory}/sshd_config.permit /etc/ssh/sshd_config"))
    when /el-7|centos-7|redhat-7|oracle-7|scientific-7|eos-7/
      directory = create_tmpdir_on(self)
      exec(Beaker::Command.new("echo 'PermitUserEnvironment yes' | cat - /etc/ssh/sshd_config > #{directory}/sshd_config.permit"))
      exec(Beaker::Command.new("mv #{directory}/sshd_config.permit /etc/ssh/sshd_config"))
    when /el-|centos|fedora|redhat|oracle|scientific|eos/
      directory = create_tmpdir_on(self)
      exec(Beaker::Command.new("echo 'PermitUserEnvironment yes' | cat - /etc/ssh/sshd_config > #{directory}/sshd_config.permit"))
      exec(Beaker::Command.new("mv #{directory}/sshd_config.permit /etc/ssh/sshd_config"))
    when /sles/
      directory = create_tmpdir_on(self)
      exec(Beaker::Command.new("echo 'PermitUserEnvironment yes' | cat - /etc/ssh/sshd_config > #{directory}/sshd_config.permit"))
      exec(Beaker::Command.new("mv #{directory}/sshd_config.permit /etc/ssh/sshd_config"))
    when /solaris/
      # kept solaris here because refactoring it into its own Host module
      # conflicts with the solaris hypervisor that already exists
      directory = create_tmpdir_on(self)
      exec(Beaker::Command.new("echo 'PermitUserEnvironment yes' | cat - /etc/ssh/sshd_config > #{directory}/sshd_config.permit"))
      exec(Beaker::Command.new("mv #{directory}/sshd_config.permit /etc/ssh/sshd_config"))
    when /(free|open)bsd/
      exec(Beaker::Command.new("sudo perl -pi -e 's/^#?PermitUserEnvironment no/PermitUserEnvironment yes/' /etc/ssh/sshd_config"), {:pty => true} )
    else
      raise ArgumentError, "Unsupported Platform: '#{self['platform']}'"
    end

    ssh_service_restart()
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
    return '' if env.empty?
    env_array = self.environment_variable_string_pair_array( env )
    environment_string = env_array.join(' ')
    "env #{environment_string}"
  end

  def environment_variable_string_pair_array env
    env_array = []
    env.each_key do |key|
      val = env[key]
      if val.is_a?(Array)
        val = val.join(':')
      else
        val = val.to_s
      end
      # doing this for the key itself & the upcase'd version allows us to remain
      # backwards compatible
      # TODO: (Next Major Version) get rid of upcase'd version
      key_str = key.to_s
      keys = [key_str]
      keys << key_str.upcase if key_str.upcase != key_str
      keys.each do |env_key|
        env_array << "#{env_key}=\"#{val}\""
      end
    end
    env_array
  end

  # Gets the specific prepend commands as needed for this host
  #
  # @param [String] command Command to be executed
  # @param [String] user_pc List of user-specified commands to prepend
  # @param [Hash] opts optional parameters
  #
  # @return [String] Command string as needed for this host
  def prepend_commands(command = '', user_pc = '', opts = {})
    user_pc
  end

  # Fills the user SSH environment file.
  #
  # @param [Hash{String=>String}] env Environment variables to set on the system,
  #                                   in the form of a hash of String variable
  #                                   names to their corresponding String values.
  #
  # @api private
  # @return nil
  def ssh_set_user_environment(env)
    #ensure that ~/.ssh/environment exists
    ssh_env_file_dir = Pathname.new(self[:ssh_env_file]).dirname
    mkdir_p(ssh_env_file_dir)
    exec(Beaker::Command.new("chmod 0600 #{ssh_env_file_dir}"))
    exec(Beaker::Command.new("touch #{self[:ssh_env_file]}"))
    #add the constructed env vars to this host
    add_env_var('PATH', '$PATH')
    # FIXME
    if self['platform'] =~ /openbsd-(\d)\.?(\d)-(.+)/
      version = "#{$1}.#{$2}"
      arch = $3
      arch = 'amd64' if ['x64', 'x86_64'].include?(arch)
      add_env_var('PKG_PATH', "http://ftp.openbsd.org/pub/OpenBSD/#{version}/packages/#{arch}/")
    elsif self['platform'] =~ /solaris-10/
      add_env_var('PATH', '/opt/csw/bin')
    end

    #add the env var set to this test host
    env.each_pair do |var, value|
      add_env_var(var, value)
    end
  end

  # Checks if selinux is enabled
  #
  # @return [Boolean] true if selinux is enabled, false otherwise
  def selinux_enabled?()
    exec(Beaker::Command.new("sudo selinuxenabled"), :accept_all_exit_codes => true).exit_code == 0
  end

end
