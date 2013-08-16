module Windows::File
  include Beaker::CommandFactory

  def tmpfile(name)
    execute("cygpath -m $(mktemp -t #{name}.XXXXXX)")
  end

  def tmpdir(name)
    execute("cygpath -m $(mktemp -td #{name}.XXXXXX)")
  end

  def path_split(paths)
    paths.split(';')
  end
end
