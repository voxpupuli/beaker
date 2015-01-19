module PSWindows::File
  include Beaker::CommandFactory

  def tmpfile(name)
    execute("echo C:\\Windows\\Temp\\#{name}.XXXXXX")
  end

  def tmpdir(name)
    execute("echo C:\\Windows\\Temp\\#{name}.XXXXXX")
  end

  def path_split(paths)
    paths.split(';')
  end
end
