$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'lib'))

require 'helpers/test_helper'

test_name "dsl::helpers::host_helpers test configuration validation" do
  step "Validate hosts configuration" do
    assert (hosts.size > 1),
      "dsl::helpers::host_helpers acceptance tests require at least two hosts"

    agents = select_hosts(:roles => "agent")
    assert (agents.size > 1),
      "dsl::helpers::host_helpers acceptance tests require at least two hosts with the :agent role"

    assert default,
      "dsl::helpers::host_helpers acceptance tests require a default host"
  end
end
