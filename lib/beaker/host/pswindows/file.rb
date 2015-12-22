module PSWindows::File
  include Beaker::CommandFactory

  def tmpfile(name)
    result = exec(powershell('[System.IO.Path]::GetTempFileName()'))
    result.stdout.chomp()
  end

  def tmpdir(name)
    result = exec(powershell('[System.IO.Path]::GetTempPath()'))
    result.stdout.chomp()
  end

  def path_split(paths)
    paths.split(';')
  end

  def file_exist?(path)
    result = exec(Beaker::Command.new("if exist #{path} echo true"), :acceptable_exit_codes => [0, 1])
    result.stdout =~ /true/
  end
end
