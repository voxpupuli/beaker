module Unix::File
  include Beaker::CommandFactory

  def tmpfile(name)
    execute("mktemp -t #{name}.XXXXXX")
  end

  def tmpdir(name)
    execute("mktemp -dt #{name}.XXXXXX")
  end

  def puppet_tmpdir(name)
    dir = tmpdir(name)
    user = execute("puppet master --configprint user")
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
