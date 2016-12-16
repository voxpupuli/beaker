require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #echo_on" do
  step "#echo_on echoes the supplied string on the remote host" do
    output = echo_on(default, "contents")
    assert_equal output, "contents"
  end

  step "#echo_on echoes the supplied string on all hosts when given a hosts array" do
    results = echo_on(hosts, "contents")
    assert_equal ["contents"] * hosts.size, results
  end
end
