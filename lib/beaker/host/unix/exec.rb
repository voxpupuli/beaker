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
end
