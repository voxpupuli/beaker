module PSWindows::File
  include Beaker::CommandFactory

  def tmpfile(name = '')
    result = exec(powershell('[System.IO.Path]::GetTempFileName()'))
    result.stdout.chomp()
  end

  def tmpdir(name = '')
    tmp_path = exec(powershell('[System.IO.Path]::GetTempPath()')).stdout.chomp()

    if name == ''
      name = exec(powershell('[System.IO.Path]::GetRandomFileName()')).stdout.chomp()
    end
    exec(powershell("New-Item -Path '#{tmp_path}' -Force -Name '#{name}' -ItemType 'directory'"))
    File.join(tmp_path, name)
  end

  def path_split(paths)
    paths.split(';')
  end

  def cat(path)
    exec(powershell("type #{path}"))
  end

  def file_exist?(path)
    result = exec(Beaker::Command.new("if exist #{path} echo true"), :acceptable_exit_codes => [0, 1])
    result.stdout =~ /true/
  end
end
