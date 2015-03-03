module Windows::File
  include Beaker::CommandFactory

  def tmpfile(name)
    execute("cygpath -m $(mktemp -t #{name}.XXXXXX)")
  end

  def tmpdir(name)
    execute("cygpath -m $(mktemp -td #{name}.XXXXXX)")
  end

  def path_split(paths)
    paths.split(';')
  end

  def file_exist?(path)
    result = exec(Beaker::Command.new("test -e #{path}"), :acceptable_exit_codes => [0, 1])
    result.exit_code == 0
  end
end
