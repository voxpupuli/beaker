module PSWindows::File
  include Beaker::CommandFactory

  def tmpfile(name)
    execute("echo C:\\Windows\\Temp\\#{name}.%RANDOM%")
  end

  def tmpdir(name)
    # generate name
    tmpdirname = execute("echo C:\\Windows\\Temp\\#{name}.%RANDOM%")
    # created named dir
    execute("md #{tmpdirname}")
    tmpdirname
  end

  def path_split(paths)
    paths.split(';')
  end

  def file_exist?(path)
    result = exec(Beaker::Command.new("if exist #{path} echo true"), :acceptable_exit_codes => [0, 1])
    result.stdout =~ /true/
  end
end
