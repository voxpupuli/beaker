module Unix::Exec
  include Beaker::CommandFactory

  def reboot
    if self['platform'] =~ /solaris/
      exec(Beaker::Command.new("reboot"), :expect_connection_failure => true)
    else
      exec(Beaker::Command.new("/sbin/shutdown -r now"), :expect_connection_failure => true)
    end
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
      execute("ip a|awk '/global/{print$2}' | cut -d/ -f1 | head -1").strip
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
    exec(Beaker::Command.new("rm -rf #{path}"))
  end

  # Converts the provided environment file to a new shell script in /etc/profile.d, then sources that file.
  # This is for sles based hosts.
  # @param [String] env_file The ssh environment file to read from
  def mirror_env_to_profile_d env_file
    if self[:platform] =~ /sles-/
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
      @logger.debug("will not mirror environment to /etc/profile.d on non-sles platform host")
    end
  end

  #Add the provided key/val to the current ssh environment
  #@param [String] key The key to add the value to
  #@param [String] val The value for the key
  #@example
  #  host.add_env_var('PATH', '/usr/bin:PATH')
  def add_env_var key, val
    key = key.to_s.upcase
    env_file = self[:ssh_env_file]
    escaped_val = Regexp.escape(val).gsub('/', '\/').gsub(';', '\;')
    #see if the key/value pair already exists
    if exec(Beaker::Command.new("grep #{key}=.*#{escaped_val} #{env_file}"), :accept_all_exit_codes => true ).exit_code == 0
      return #nothing to do here, key value pair already exists
    #see if the key already exists
    elsif exec(Beaker::Command.new("grep #{key} #{env_file}"), :accept_all_exit_codes => true ).exit_code == 0
      exec(Beaker::SedCommand.new(self['platform'], "s/#{key}=/#{key}=#{escaped_val}:/", env_file))
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
    key = key.to_s.upcase
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
    key = key.to_s.upcase
    exec(Beaker::Command.new("env | grep #{key}"), :accept_all_exit_codes => true).stdout.chomp
  end

  #Delete the environment variable from the current ssh environment
  #@param [String] key The key to delete
  #@example
  #  host.clear_env_var('PATH')
  def clear_env_var key
    key = key.to_s.upcase
    env_file = self[:ssh_env_file]
    #remove entire line
    exec(Beaker::SedCommand.new(self['platform'], "/#{key}=.*$/d", env_file))
    #update the profile.d to current state
    #match it to the contents of ssh_env_file
    mirror_env_to_profile_d(env_file)
  end

end
