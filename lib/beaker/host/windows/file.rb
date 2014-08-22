module Windows::File
  include Beaker::CommandFactory

  def tmpfile(name)
    cmd = case self.defaults['communicator']
    when /bitvise/
      "echo C:\\Windows\\Temp\\#{name}.XXXXXX"
    else
      "cygpath -m $(mktemp -t #{name}.XXXXXX)"
    end
    execute(cmd)
  end

  def tmpdir(name)
    cmd = case self.defaults['communicator']
    when /bitvise/
      "echo C:\\Windows\\Temp\\#{name}.XXXXXX"
    else
      "cygpath -m $(mktemp -td #{name}.XXXXXX)"
    end
    execute(cmd)
  end

  def path_split(paths)
    paths.split(';')
  end
end
