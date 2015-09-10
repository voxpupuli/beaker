# NOTE: Currently scp failures throw a Net::SCP::Error exception in SSH connection
# close, which ends up not being caught properly, and which ultimately results
# in a RuntimeError. The SSH Connection is left in an unusable state and all
# later remote commands will hang indefinitely.
#
# TODO: fix via: https://tickets.puppetlabs.com/browse/BKR-464
def test_scp_error_on_close?
  !!ENV["BEAKER_TEST_SCP_ERROR_ON_CLOSE"]
end

# NOTE: currently there is an issue with the tmpdir_on helper on cygwin
# platforms:  the `chown` command always fails with an error about not
# recognizing the Administrator:Administrator user/group.  Until this is fixed,
# we add this shim that delegates to a non-`chown`-executing version for the
# purposes of our test setup.
#
# TODO: fix via: https://tickets.puppetlabs.com/browse/BKR-496
def tmpdir_on(hosts, path_prefix = '', user=nil)
  first_host = Array(hosts).first

  return create_tmpdir_on(hosts, path_prefix, user) unless \
    first_host.is_cygwin? or first_host.platform =~ /osx/

  block_on hosts do | host |
    # use default user logged into this host
    if not user
      user = host['user']
    end

    if defined? host.tmpdir
      # NOTE: here we skip the `chown` call:
      host.tmpdir(path_prefix)
    else
      raise "Host platform not supported by `tmpdir_on`."
    end
  end
end

# Returns the absolute path where file fixtures are located.
def fixture_path
  @fixture_path ||=
    File.expand_path(File.join(__FILE__, '..', '..', '..', 'fixtures', 'files'))
end

# Returns the contents of a named fixture file, to be found in `fixture_path`.
def fixture_contents(fixture)
  fixture_file = File.join(fixture_path, "#{fixture}.txt")
  File.read(fixture_file)
end

# Create a file on `host` in the `remote_path` with file name `filename`,
# containing the contents of the fixture file named `fixture`.  Returns
# the full remote path to the created file.
def create_remote_file_from_fixture(fixture, host, remote_path, filename)
  full_filename = File.join(remote_path, filename)
  contents = fixture_contents fixture
  create_remote_file host, full_filename, contents
  [ full_filename, contents ]
end

# Create a file locally, in the `local_path`, with file name `filename`,
# containing the contents of the fixture file named `fixture`; optionally
# setting the file permissions to `perms`. Returns the full path to the created
# file, and the file contents.
def create_local_file_from_fixture(fixture, local_path, filename, perms = nil)
  full_filename = File.join(local_path, filename)
  contents = fixture_contents fixture

  File.open(full_filename, "w") do |local_file|
    local_file.puts contents
  end
  FileUtils.chmod perms, full_filename if perms

  [ full_filename, contents ]
end
