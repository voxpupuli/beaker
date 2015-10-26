module Windows::Exec
  include Beaker::CommandFactory

  def reboot
    exec(Beaker::Command.new('shutdown /f /r /t 0 /d p:4:1 /c "Beaker::Host reboot command issued"'), :expect_connection_failure => true)
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
    ip = execute("ipconfig | grep -i 'IP Address' | cut -d: -f2 | head -1").strip
    if ip == ''
      ip = execute("ipconfig | grep -i 'IPv4 Address' | cut -d: -f2 | head -1").strip
    end
    if ip == ''
      ip = execute("ipconfig | grep -i 'IPv6 Address' | cut -d: -f2 | head -1").strip
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

end
