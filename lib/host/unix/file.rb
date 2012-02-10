module Unix::File
  include CommandFactory

  def tmpfile(name)
    execute("mktemp --tmpdir=#{base_tmpdir} -t #{name}.XXXXXX")
  end

  def tmpdir(name)
    execute("mktemp --tmpdir=#{base_tmpdir} -td #{name}.XXXXXX")
  end

  def path_split(paths)
    paths.split(':')
  end



  # private utility method to get the base temp dir path; the goal here is to quarantine acceptance test temp files into
  # one easily-identifiable directory that can be cleaned up easily
  def base_tmpdir()
    unless @base_tmp_dir then
      @base_tmp_dir = "#{get_system_tmpdir}/puppet-acceptance"
      mkdirs(@base_tmp_dir)
    end
    @base_tmp_dir
  end
  private :base_tmpdir

  # private utility method for determining the system tempdir
  def get_system_tmpdir()
    # hard-coded for now, but this could execute a command on the system to check environment variables, etc.
    "/tmp"
  end
  private :get_system_tmpdir

end
