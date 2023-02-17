require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #create_remote_file" do

  def create_remote_file_with_backups host, remote_filename, contents, opts={}
    result = nil
    repeat_fibonacci_style_for(10) do
      begin
        result = create_remote_file(
          host, remote_filename, contents, opts
        ) # return of block is whether or not we're done repeating
        if result.is_a?(Rsync::Result) || result.is_a?(Beaker::Result)
          return result.success?
        end

        result.each do |individual_result| 
          next if individual_result.success?
          return false
        end
        true
      rescue Beaker::Host::CommandFailure => e
        logger.info("create_remote_file threw command failure, details: ")
        logger.info("  #{e}")
        logger.info("continuing back-off execution")
        false
      end
    end
    result
  end

  if test_scp_error_on_close?
    step "#create_remote_file fails when the remote path does not exist" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file default, "/non/existent/testfile.txt", "contents\n"
      end
    end

    step "#create_remote_file fails when the remote path does not exist, using scp" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file default, "/non/existent/testfile.txt", "contents\n", { :protocol => 'scp' }
      end
    end
  end

  step "#create_remote_file creates a remote file with the specified contents" do
    remote_tmpdir = default.tmpdir("beaker")
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file_with_backups default, remote_filename, contents

    remote_contents = on(default, "cat #{remote_filename}").stdout
    assert_equal contents, remote_contents
  end

  step "#create_remote_file creates a remote file with the specified contents, using scp" do
    remote_tmpdir = default.tmpdir("beaker")
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file_with_backups default, remote_filename, contents, { :protocol => "scp" }

    remote_contents = on(default, "cat #{remote_filename}").stdout
    assert_equal contents, remote_contents
  end

  step "#create_remote_file creates remote files on all remote hosts, when given an array" do
    remote_dir = "/tmp/beaker_remote_file_test"
    # ensure remote dir exists on all hosts
    hosts.each do |host|
      # we can't use tmpdir here, because some hosts may have different tmpdir behavior.
      host.mkdir_p(remote_dir)
    end

    remote_filename = File.join(remote_dir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file_with_backups hosts, remote_filename, contents

    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_filename}").stdout
      assert_equal contents, remote_contents
    end
  end

  step "#create_remote_file creates remote files on all remote hosts, when given an array, using scp" do
    remote_dir = "/tmp/beaker_remote_file_test"
    # ensure remote dir exists on all hosts
    hosts.each do |host|
      # we can't use tmpdir here, because some hosts may have different tmpdir behavior.
      host.mkdir_p(remote_dir)
    end

    remote_filename = File.join(remote_dir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file_with_backups hosts, remote_filename, contents, { :protocol => 'scp' }

    hosts.each do |host|
      remote_contents = on(host, "cat #{remote_filename}").stdout
      assert_equal contents, remote_contents
    end
  end


  confine_block :except, :platform => /windows/ do
    # these tests exercise the rsync backend
    # NOTE: rsync works fine on Windows as long as you use POSIX-style paths.
    # However, these tests use Host#tmpdir which outputs mixed-style paths
    # e.g. C:/cygwin64/tmp/beaker.Rp9G6L - Fix me with BKR-1503

    confine_block :except, :platform => /osx/ do
      # packages are unsupported on OSX
      step "installing rsync on hosts if needed" do
        hosts.each do |host|
          if host.check_for_package('rsync')
            host[:rsync_installed] = true
          else
            host[:rsync_installed] = false
            host.install_package "rsync"
          end
        end
      end
    end

    step "#create_remote_file fails and does not create a remote file when the remote path does not exist, using rsync" do
      assert_raises Beaker::Host::CommandFailure do
        create_remote_file default, "/non/existent/testfile.txt", "contents\n", { :protocol => 'rsync' }
      end

      assert_raises Beaker::Host::CommandFailure do
        on(default, "cat /non/existent/testfile.txt").exit_code
      end
    end

    step "#create_remote_file creates a remote file with the specified contents, using rsync" do
      remote_tmpdir = default.tmpdir("beaker")
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      create_remote_file_with_backups(
        default, remote_filename, contents, { :protocol => "rsync" }
      )

      fails_intermittently("https://tickets.puppetlabs.com/browse/BKR-612",
        "default" => default,
        "remote_tmpdir" => remote_tmpdir,
        "remote_filename" => remote_filename,
        "contents" => contents,
        "result" => result
        ) do
          remote_contents = on(default, "cat #{remote_filename}").stdout
          assert_equal contents, remote_contents
      end
    end

    step "#create_remote_file creates remote files on all remote hosts, when given an array, using rsync" do
      remote_tmpdir = "/tmp/beaker_remote_file_test"
      # ensure remote dir exists on all hosts
      hosts.each do |host|
        # we can't use tmpdir here, because some hosts may have different tmpdir behavior.
        host.mkdir_p(remote_tmpdir)
      end

      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      result = create_remote_file_with_backups(
        hosts, remote_filename, contents, { :protocol => 'rsync' }
      )

      hosts.each do |host|
        fails_intermittently("https://tickets.puppetlabs.com/browse/BKR-612",
          "host" => host,
          "remote_tmpdir" => remote_tmpdir,
          "remote_filename" => remote_filename,
          "contents" => contents,
          "result" => result
          ) do
          remote_contents = on(host, "cat #{remote_filename}").stdout
          assert_equal contents, remote_contents
        end
      end
    end

    confine_block :except, :platform => /osx/ do
      # packages are unsupported on OSX
      step "uninstalling rsync on hosts if needed" do
        hosts.each do |host|
          if !host[:rsync_installed]
            # rsync wasn't installed on #{host} when we started, so we should clean up after ourselves
            rsync_package = "rsync"
            # solaris-10 uses OpenCSW pkgutil, which prepends "CSW" to its provided packages
            # TODO: fix this with BKR-1502
            rsync_package = "CSWrsync" if host['platform'].include?('solaris-10')
            host.uninstall_package rsync_package
          end
          host.delete(:rsync_installed)
        end
      end
    end
  end

  step "#create_remote_file' does not create a remote file when an unknown protocol is specified" do
    remote_tmpdir = default.tmpdir("beaker")
    remote_filename = File.join(remote_tmpdir, "testfile.txt")
    contents = fixture_contents("simple_text_file")

    create_remote_file default, remote_filename, contents, { :protocol => 'unknown' }

    assert_raises Beaker::Host::CommandFailure do
      on(default, "cat #{remote_filename}").exit_code
    end
  end

  # NOTE: there does not appear to be a way to confine just to cygwin hosts
  confine_block :to, :platform => /windows/ do
    # NOTE: rsync works fine on Windows as long as you use POSIX-style paths.
    # Fix me with BKR-1503
    step "#create_remote_file CURRENTLY fails on #{default['platform']}, using rsync" do
      remote_tmpdir = default.tmpdir("beaker")
      remote_filename = File.join(remote_tmpdir, "testfile.txt")
      contents = fixture_contents("simple_text_file")

      assert_raises Beaker::Host::CommandFailure do
        create_remote_file default, remote_filename, contents, { :protocol => "rsync" }
      end

      assert_raises Beaker::Host::CommandFailure do
        on(default, "cat #{remote_filename}").stdout
      end
    end
  end
end
