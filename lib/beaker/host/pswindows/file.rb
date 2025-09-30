module PSWindows::File
  include Beaker::CommandFactory

  def tmpfile(name = '', extension = nil)
    tmp_path = exec(powershell('[System.IO.Path]::GetTempPath()')).stdout.chomp
    
    if name.empty?
      base_name = exec(powershell('[System.IO.Path]::GetRandomFileName()')).stdout.chomp
    else
      base_name = name
    end

    if extension
      # Remove existing extension if present and add the new one
      base_name = base_name.sub(/\.[^.]+$/, '')
      final_name = "#{base_name}.#{extension}"
    else
      final_name = base_name
    end
    file_path = File.join(tmp_path, final_name)
    
    exec(powershell("New-Item -Path '#{file_path}' -ItemType 'file' -Force"))
    file_path
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
