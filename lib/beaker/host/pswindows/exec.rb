module PSWindows::Exec
  include Beaker::CommandFactory
  include Beaker::DSL::Wrappers

  def reboot
    exec(Beaker::Command.new("shutdown /r /t 0"), :expect_connection_failure => true)
  end

  ABS_CMD = 'c:\\\\windows\\\\system32\\\\cmd.exe'
  CMD = 'cmd.exe'

  def echo(msg, abs=true)
    (abs ? ABS_CMD : CMD) + " /c echo #{msg}"
  end

  def touch(file, abs=true)
    (abs ? ABS_CMD : CMD) + " /c echo. 2> #{file}"
  end

  def rm_rf path
    execute("del /s /q #{path}")
  end

  def path
    'c:/windows/system32;c:/windows'
  end

  def get_ip
    ip = execute("for /f \"tokens=14\" %f in ('ipconfig ^| find \"IP Address\"') do @echo %f", :accept_all_exit_codes => true).strip
    if ip == ''
      ip = execute("for /f \"tokens=14\" %f in ('ipconfig ^| find \"IPv4 Address\"') do @echo %f", :accept_all_exit_codes => true).strip
    end
    if ip == ''
      ip = execute("for /f \"tokens=14\" %f in ('ipconfig ^| find \"IPv6 Address\"') do @echo %f").strip
    end
    ip
  end

  # Create the provided directory structure on the host
  # @param [String] dir The directory structure to create on the host
  # @return [Boolean] True, if directory construction succeeded, otherwise False
  def mkdir_p dir
    windows_dirstring = dir.gsub('/','\\')
    cmd = "if not exist #{windows_dirstring} (md #{windows_dirstring})"
    result = exec(Beaker::Command.new(cmd), :acceptable_exit_codes => [0, 1])
    result.exit_code == 0
  end

  #Add the provided key/val to the current ssh environment
  #@param [String] key The key to add the value to
  #@param [String] val The value for the key
  #@example
  #  host.add_env_var('PATH', '/usr/bin:PATH')
  def add_env_var key, val
    key = key.to_s.upcase
    #see if the key/value pair already exists
    cur_val = subbed_val = get_env_var(key, true)
    subbed_val = cur_val.gsub(/#{Regexp.escape(val.gsub(/'|"/, ''))}/, '')
    if cur_val.empty?
      exec(powershell("[Environment]::SetEnvironmentVariable('#{key}', '#{val}', 'Machine')"))
      self.close #refresh the state
    elsif subbed_val == cur_val #not present, add it
      exec(powershell("[Environment]::SetEnvironmentVariable('#{key}', '#{val};#{cur_val}', 'Machine')"))
      self.close #refresh the state
    end
  end

  #Delete the provided key/val from the current ssh environment
  #@param [String] key The key to delete the value from
  #@param [String] val The value to delete for the key
  #@example
  #  host.delete_env_var('PATH', '/usr/bin:PATH')
  def delete_env_var key, val
    key = key.to_s.upcase
    #get the current value of the key
    cur_val = subbed_val = get_env_var(key, true)
    subbed_val = (cur_val.split(';') - [val.gsub(/'|"/, '')]).join(';')
    if subbed_val != cur_val
      #remove the current key value
      self.clear_env_var(key)
      #set to the truncated value
      self.add_env_var(key, subbed_val)
    end
  end

  #Return the value of a specific env var
  #@param [String] key The key to look for
  #@param [Boolean] clean Remove the 'KEY=' and only return the value of the env var
  #@example
  #  host.get_env_var('path')
  def get_env_var key, clean = false
    self.close #refresh the state
    key = key.to_s.upcase
    val = exec(Beaker::Command.new("set #{key}"), :accept_all_exit_codes => true).stdout.chomp
    if val.empty?
      return ''
    else
      if clean
        val.gsub(/#{key}=/,'')
      else
        val
      end
    end
  end

  #Delete the environment variable from the current ssh environment
  #@param [String] key The key to delete
  #@example
  #  host.clear_env_var('PATH')
  def clear_env_var key
    key = key.to_s.upcase
    exec(powershell("[Environment]::SetEnvironmentVariable('#{key}', $null, 'Machine')"))
    exec(powershell("[Environment]::SetEnvironmentVariable('#{key}', $null, 'User')"))
    exec(powershell("[Environment]::SetEnvironmentVariable('#{key}', $null, 'Process')"))
    self.close #refresh the state
  end

end
