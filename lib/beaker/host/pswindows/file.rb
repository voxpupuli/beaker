module PSWindows::File
  include Beaker::CommandFactory

  def tmpfile(_name = '', extension = nil)
    if extension
      # TODO: I do not have access to Windows, but the internet suggests this
      # $newname = [System.IO.Path]::ChangeExtension($filename, "#{extension}") ; MoveItem $filename $newname
      raise NotImplementedError, 'Passing an extension is not implemented'
    end

    result = exec(powershell('[System.IO.Path]::GetTempFileName()'))
    result.stdout.chomp
  end

  def tmpdir(name = '')
    tmp_path = exec(powershell('[System.IO.Path]::GetTempPath()')).stdout.chomp

    name = exec(powershell('[System.IO.Path]::GetRandomFileName()')).stdout.chomp if name == ''
    exec(powershell("New-Item -Path '#{tmp_path}' -Force -Name '#{name}' -ItemType 'directory'"))
    File.join(tmp_path, name)
  end

  def path_split(paths)
    paths.split(';')
  end

  def cat(path)
    exec(powershell("type #{path}")).stdout
  end

  def file_exist?(path)
    result = exec(Beaker::Command.new("if exist #{path} echo true"), accept_all_exit_codes: true)
    result.stdout.strip == 'true'
  end
end
