# NOTE: Currently scp failures throw a Net::SCP::Error exception in SSH connection
# close, which ends up not being caught properly, and which ultimately results
# in a RuntimeError. The SSH Connection is left in an unusable state and all
# later remote commands will hang indefinitely.
#
# TODO: fix via: https://tickets.puppetlabs.com/browse/BKR-464
def test_scp_error_on_close?
  !!ENV["BEAKER_TEST_SCP_ERROR_ON_CLOSE"]
end

# Returns the absolute path where file fixtures are located.
def fixture_path
  @fixture_path ||=
    File.expand_path(File.join(__FILE__, '..', '..', '..', 'fixtures', 'files'))
end

# Returns the contents of a named fixture file, to be found in `fixture_path`.
def fixture_contents(fixture)
  fixture_file = Dir.entries(fixture_path).find { |e| /^#{fixture}$|#{fixture}\.[a-z]/.match?(e) }
  File.read("#{fixture_path}/#{fixture_file}")
end

# Create a file on `host` in the `remote_path` with file name `filename`,
# containing the contents of the fixture file named `fixture`.  Returns
# the full remote path to the created file, and the file contents.
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

# Provide debugging information for tests which are known to fail intermittently
#
# issue_link - url of Jira issue documenting this intermittent test failure
# args       - Hash of debugging information (names => values) to output on a failure
# block      - block which intermittently fails
#
# Example
#
#    fails_intermittently('https://tickets.puppetlabs.com/browse/QENG-2958',
#      '@host' => @host, 'user' => user, 'expected' => expected) do
#      assert_equal expected, user
#    end
#
# Absorbs any MiniTest::Assertion from a failing test assertion in the block.
# This implies that the intermittent failure is caught and the suite will not
# go red for this failure. Intended to be used with the Jenkins Build Failure
# Analyzer (or similar), to detect these failures without failing the build.
#
# Returns the value of the yielded block.
def fails_intermittently(issue_link, args = {})
  raise ArgumentError, "provide a Jira ticket link" unless issue_link
  raise ArgumentError, "a block is required" unless block_given?
  yield
rescue MiniTest::Assertion, StandardError, SignalException # we have a test failure!
  STDERR.puts "\n\nIntermittent test failure! See: #{issue_link}"

  if args.empty?
    STDERR.puts "No further debugging information available."
  else
    STDERR.puts "Debugging information:\n"
    args.keys.sort.each do |key|
      STDERR.puts "#{key} => #{args[key].inspect}"
    end
  end
end
