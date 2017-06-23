module Windows::Exec
  include Beaker::CommandFactory

  def reboot
    exec(Beaker::Command.new('shutdown /f /r /t 0 /d p:4:1 /c "Beaker::Host reboot command issued"'), :reset_connection => true)
    # rebooting on windows is sloooooow
    # give it some breathing room before attempting a reconnect
    sleep(40)
  end

  ABS_CMD = 'c:\\\\windows\\\\system32\\\\cmd.exe'
  CMD = 'cmd.exe'

  def echo(msg, abs=true)
    (abs ? ABS_CMD : CMD) + " /c echo #{msg}"
  end

  def touch(file, abs=true)
    (abs ? ABS_CMD : CMD) + " /c echo. 2> #{file}"
  end

  def path
    'c:/windows/system32;c:/windows'
  end

  def get_ip
    # when querying for an IP this way the return value can be formatted like:
    # IPAddress=
    # IPAddress={"129.168.0.1"}
    # IPAddress={"192.168.0.1","2001:db8:aaaa:bbbb:cccc:dddd:eeee:0001"}

    ips = execute("wmic nicconfig where ipenabled=true GET IPAddress /format:list")

    ip = ''
    ips.each_line do |line|
      matches = line.split('=')
      next if matches.length <= 1
      matches = matches[1].match(/^{"(.*?)"/)
      next if matches.nil? || matches.captures.nil? || matches.captures.empty?
      ip = matches.captures[0] if matches && matches.captures
      break if ip != ''
    end

    ip
  end

  # Attempt to ping the provided target hostname
  # @param [String] target The hostname to ping
  # @param [Integer] attempts Amount of times to attempt ping before giving up
  # @return [Boolean] true of ping successful, overwise false
  def ping target, attempts=5
    try = 0
    while try < attempts do
      result = exec(Beaker::Command.new("ping -n 1 #{target}"), :accept_all_exit_codes => true)
      if result.exit_code == 0
        return true
      end
      try+=1
    end
    result.exit_code == 0
  end

  # Restarts the SSH service.
  #
  # @return [Result] result of starting SSH service
  def ssh_service_restart
    command_result = nil
    # we get periodic failures to restart the service, so looping these with re-attempts
    repeat_fibonacci_style_for(5) do
      0 == exec(Beaker::Command.new("cygrunsrv -E sshd"), :acceptable_exit_codes => [0, 1] ).exit_code
    end
    repeat_fibonacci_style_for(5) do
      command_result = exec(Beaker::Command.new("cygrunsrv -S sshd"), :acceptable_exit_codes => [0, 1] )
      0 == command_result.exit_code
    end
    command_result
  end

  # Sets the PermitUserEnvironment setting & restarts the SSH service
  #
  # @api private
  # @return [Result] result of the command starting the SSH service
  #   (from {#ssh_service_restart}).
  def ssh_permit_user_environment
    exec(Beaker::Command.new("echo '\nPermitUserEnvironment yes' >> /etc/sshd_config"))
    ssh_service_restart()
  end

  # Gets the specific prepend commands as needed for this host
  #
  # @param [String] command Command to be executed
  # @param [String] user_pc List of user-specified commands to prepend
  # @param [Hash] opts optional parameters
  # @option opts [Boolean] :cmd_exe whether cmd.exe should be used
  #
  # @return [String] Command string as needed for this host
  def prepend_commands(command = '', user_pc = nil, opts = {})
    cygwin_prefix = (self.is_cygwin? and opts[:cmd_exe]) ? 'cmd.exe /c' : ''
    spacing = (user_pc && !cygwin_prefix.empty?) ? ' ' : ''
    "#{cygwin_prefix}#{spacing}#{user_pc}"
  end

  # Checks if selinux is enabled
  # selinux is not available on Windows
  #
  # @return [Boolean] false
  def selinux_enabled?()
    false
  end

  # Determine if cygwin is actually installed on the SUT. Differs from
  # is_cygwin?, which is just a type check for a Windows::Host.
  #
  # @return [Boolean]
  def cygwin_installed?
    output = exec(Beaker::Command.new('cygcheck --check-setup cygwin'), :accept_all_exit_codes => true).stdout 
    return true if output.match(/cygwin/) && output.match(/OK/)
    false
  end

end
