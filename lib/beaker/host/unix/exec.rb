module Unix::Exec
  include Beaker::CommandFactory

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
    if self['platform'].include? 'solaris'
      execute("ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1").strip
    else
      execute("ip a|awk '/global/{print$2}' | cut -d/ -f1 | head -1").strip
    end
  end
end
