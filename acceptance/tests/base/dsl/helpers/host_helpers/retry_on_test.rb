require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #retry_on" do
  step "#retry_on CURRENTLY fails with a RuntimeError if command does not pass after all retries" do
    # NOTE: would have expected this to fail with Beaker::Hosts::CommandFailure

    remote_tmpdir = default.tmpdir()
    remote_script_file = File.join(remote_tmpdir, "test.sh")
    create_remote_file_from_fixture("retry_script", default, remote_tmpdir, "test.sh")

    assert_raises RuntimeError do
      retry_on default, "bash #{remote_script_file} #{remote_tmpdir} 10", { :max_retries => 2, :retry_interval => 0.1 }
    end
  end

  step "#retry_on succeeds if command passes before retries are exhausted" do
    remote_tmpdir = default.tmpdir()
    remote_script_file = File.join(remote_tmpdir, "test.sh")
    create_remote_file_from_fixture("retry_script", default, remote_tmpdir, "test.sh")

    result = retry_on default, "bash #{remote_script_file} #{remote_tmpdir} 2", { :max_retries => 4, :retry_interval => 0.1 }
    assert_equal 0, result.exit_code
    assert_equal "", result.stdout
  end

  step "#retry_on CURRENTLY fails when provided a host array" do
    # NOTE: would expect this to work across hosts, or be better documented and
    #       to raise Beaker::Host::CommandFailure

    remote_tmpdir = default.tmpdir()
    remote_script_file = File.join(remote_tmpdir, "test.sh")

    hosts.each do |host|
      on host, "mkdir -p #{remote_tmpdir}"
      create_remote_file_from_fixture("retry_script", host, remote_tmpdir, "test.sh")
    end

    assert_raises NoMethodError do
      retry_on hosts, "bash #{remote_script_file} #{remote_tmpdir} 2", { :max_retries => 4, :retry_interval => 0.1 }
    end
  end
end
