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
end
