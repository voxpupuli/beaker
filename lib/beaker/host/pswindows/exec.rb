module PSWindows::Exec
  include Beaker::CommandFactory

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
    ip = execute("for /f \"tokens=14\" %f in ('ipconfig ^| find \"IP Address\"') do @echo %f").strip
    if ip == ''
      ip = execute("for /f \"tokens=14\" %f in ('ipconfig ^| find \"IPv4 Address\"') do @echo %f").strip
    end
    if ip == ''
      ip = execute("for /f \"tokens=14\" %f in ('ipconfig ^| find \"IPv6 Address\"') do @echo %f").strip
    end
    ip
  end
end
