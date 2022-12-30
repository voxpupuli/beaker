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
      assert_match(/testuser/, host.ls_ld(tmpfile), "Should have found testuser in `ls -ld` output")
    end
  end

  step "#chown changes directory user ownership" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      # ensure we have a user to chown to
      host.chgrp('testgroup', tmpdir)
      assert_match(/testgroup/, host.ls_ld(tmpdir), "Should have found testgroup in `ls -ld` output: #{stdout}")
    end
  end

  step "#chown changes directory user ownership recursively" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      on host, host.touch("#{tmpdir}/somefile.txt", false)
      host.chown('testuser', tmpdir, true)
      assert_match(/testuser/, host.ls_ld("#{tmpdir}/somefile.txt"), "Should have found testuser in `ls -ld` output for sub-file")
    end
  end

  step "#chgrp changes file group ownership" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpfile = host.tmpfile('beaker')
      # ensure we have a group to chgrp to
      host.chgrp('testgroup', tmpfile)
      assert_match(/testgroup/, host.ls_ld(tmpfile), "Should have found testgroup in `ls -ld` output")
    end
  end

  step "#chgrp changes directory group ownership" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      # ensure we have a group to chgrp to
      host.chgrp('testgroup', tmpdir)
      assert_match(/testgroup/, host.ls_ld(tmpdir), "Should have found testgroup in `ls -ld` output")
    end
  end

  step "#chgrp changes directory group ownership recursively" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      on host, host.touch("#{tmpdir}/somefile.txt", false)
      host.chgrp('testgroup', tmpdir, true)
      assert_match(/testgroup/, host.ls_ld("#{tmpdir}/somefile.txt"), "Should have found testgroup in `ls -ld` output for sub-file")
    end
  end

  step "#ls_ld produces output" do
    hosts.each do |host|
      # create a tmp file to mangle
      tmpdir = host.tmpdir('beaker')
      assert_match(/beaker/, host.ls_ld(tmpdir), "Should have found beaker in `ls -ld` output")
    end
  end

  # shared teardown
  hosts.each do |host|
    host.user_absent('testuser')
    host.group_absent('testgroup')
  end
end