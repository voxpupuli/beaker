module Unix::File
  include Beaker::CommandFactory

  def tmpfile(name)
    execute("mktemp -t #{name}.XXXXXX")
  end

  def tmpdir(name)
    execute("mktemp -dt #{name}.XXXXXX")
  end

  # Create a temporary directory owned by the Puppet user.
  #
  # @param name [String] The name of the directory.  It will be suffixed with a
  #   unique identifier to avoid conflicts.
  # @return [String] The path to the temporary directory.
  def puppet_tmpdir(name)
    dir = tmpdir(name)
    user = puppet('master')['user']
    execute("chown #{user} #{dir}")
    dir
  end

  def path_split(paths)
    paths.split(':')
  end

  def file_exist?(path)
    result = exec(Beaker::Command.new("test -e #{path}"), :acceptable_exit_codes => [0, 1])
    result.exit_code == 0
  end
end
