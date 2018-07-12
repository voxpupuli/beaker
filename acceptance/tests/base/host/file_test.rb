test_name 'File Test' do
  # some shared setup stuff
  hosts.each do |host|
    host.user_present('testuser')
    host.group_present('testgroup')
  end

  step "#chown changes file user ownership" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpfile = host.tmpfile('beaker')
      # ensure we have a user to chown to
      host.chown('testuser', tmpfile)
      on host, "ls -l #{tmpfile}" do
        assert_match /testuser/, stdout, "Should have found testuser in `ls -l` output"
      end
    end
  end

  step "#chown changes directory user ownership" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      # ensure we have a user to chown to
      host.chgrp('testgroup', tmpdir)
      on host, "ls -ld #{tmpdir}" do
        assert_match /testgroup/, stdout, "Should have found testgroup in `ls -l` output: #{stdout}"
      end
    end
  end

  step "#chown changes directory user ownership recursively" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      on host, host.touch("#{tmpdir}/somefile.txt", false)
      host.chown('testuser', tmpdir, true)
      on host, "ls -l #{tmpdir}/somefile.txt" do
        assert_match /testuser/, stdout, "Should have found testuser in `ls -l` output for sub-file"
      end
    end
  end

  step "#chgrp changes file group ownership" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpfile = host.tmpfile('beaker')
      # ensure we have a group to chgrp to
      host.chgrp('testgroup', tmpfile)
      on host, "ls -l #{tmpfile}" do
        assert_match /testgroup/, stdout, "Should have found testgroup in `ls -l` output"
      end
    end
  end

  step "#chgrp changes directory group ownership" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      # ensure we have a group to chgrp to
      host.chgrp('testgroup', tmpdir)
      on host, "ls -ld #{tmpdir}" do
        assert_match /testgroup/, stdout, "Should have found testgroup in `ls -l` output"
      end
    end
  end

  step "#chgrp changes directory group ownership recursively" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      on host, host.touch("#{tmpdir}/somefile.txt", false)
      host.chgrp('testgroup', tmpdir, true)
      on host, "ls -l #{tmpdir}/somefile.txt" do
        assert_match /testgroup/, stdout, "Should have found testgroup in `ls -l` output for sub-file"
      end
    end
  end

  # shared teardown
  hosts.each do |host|
    host.user_absent('testuser')
    host.group_absent('testgroup')
  end
end