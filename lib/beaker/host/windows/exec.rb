module Windows::Exec
  include Beaker::CommandFactory

  def reboot
    exec(Beaker::Command.new('shutdown /r /t 0 /d p:4:1 /c "Beaker::Host reboot command issued"'), :expect_connection_failure => true)
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
end
