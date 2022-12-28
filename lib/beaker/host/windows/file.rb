module Windows::File
  include Beaker::CommandFactory

  def tmpfile(name = '')
    execute("cygpath -m $(mktemp -t #{name}.XXXXXX)")
  end

  def tmpdir(name = '')
    execute("cygpath -m $(mktemp -td #{name}.XXXXXX)")
  end

  def system_temp_path
    # under CYGWIN %TEMP% may not be set
    tmp_path = execute('ECHO %SYSTEMROOT%', :cmdexe => true)
    tmp_path.delete("\n") + '\\TEMP'
  end

  # (see {Beaker::Host::Unix::File#chown})
  # @note Cygwin's `chown` implementation does not support
  #   windows-, DOS-, or mixed-style paths, only UNIX/POSIX-style.
  #   This method simply wraps the normal Host#chown call with
  #   a call to cygpath to sanitize input.
  def chown(user, path, recursive=false)
    cygpath = execute("cygpath -u #{path}")
    super(user, cygpath, recursive)
  end

  # (see {Beaker::Host::Unix::File#chgrp})
  # @note Cygwin's `chgrp` implementation does not support
  #   windows-, DOS-, or mixed-style paths, only UNIX/POSIX-style.
  #   This method simply wraps the normal Host#chgrp call with
  #   a call to cygpath to sanitize input.
  def chgrp(group, path, recursive=false)
    cygpath = execute("cygpath -u #{path}")
    super(group, cygpath, recursive)
  end

  # Not needed on windows
  def chmod(mod, path, recursive=false); end

  # (see {Beaker::Host::Unix::File#ls_ld})
  # @note Cygwin's `ls_ld` implementation does not support
  #   windows-, DOS-, or mixed-style paths, only UNIX/POSIX-style.
  #   This method simply wraps the normal Host#ls_ld call with
  #   a call to cygpath to sanitize input.
  def ls_ld(path)
    cygpath = execute("cygpath -u #{path}")
    super(cygpath)
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
      path.gsub('\\', scp_separator)
    when :openssh
      path
    when :win32_openssh
      path.tr('\\', '/')
    else
      raise ArgumentError, "windows/file.rb:scp_path: ssh server not recognized: '#{determine_ssh_server}'"
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
