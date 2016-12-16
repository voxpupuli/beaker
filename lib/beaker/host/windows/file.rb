module Windows::File
  include Beaker::CommandFactory

  def tmpfile(name)
    execute("cygpath -m $(mktemp -t #{name}.XXXXXX)")
  end

  def tmpdir(name)
    execute("cygpath -m $(mktemp -td #{name}.XXXXXX)")
  end

  def system_temp_path
    # under CYGWIN %TEMP% may not be set
    tmp_path = execute('ECHO %SYSTEMROOT%', :cmdexe => true)
    tmp_path.gsub(/\n/, '') + '\\TEMP'
  end

  # Updates a file path for use with SCP, depending on the SSH Server
  #
  # @note This will fail with an SSH server that is not OpenSSL or BitVise.
  #
  # @param [String] path Path to be changed
  #
  # @return [String] Path updated for use by SCP
  def scp_path(path)
    case determine_ssh_server
    when :bitvise
      # swap out separators
      network_path = path.gsub('\\', scp_separator)
    when :openssh
      path
    else
      raise ArgumentError("windows/file.rb:scp_path: ssh server not recognized: '#{determine_ssh_server}'")
    end
  end

  def path_split(paths)
    paths.split(';')
  end

  def file_exist?(path)
    result = exec(Beaker::Command.new("test -e '#{path}'"), :acceptable_exit_codes => [0, 1])
    result.exit_code == 0
  end
end
