test_name "DSL::Structure::PlatformTagConfiner" do
  pstc_method_name = "#platform_specific_tag_confines"
  step "#{pstc_method_name} doesn't change hosts if there are no tags" do
    previous_hosts = hosts.dup

    platform_specific_tag_confines

    assert_equal previous_hosts, hosts, "#{pstc_method_name} changed the hosts array"
    # cleanup
    options[:platform_tag_confines_object] = nil
    options[:platform_tag_confines] = nil
    @hosts = previous_hosts
  end

  step "#{pstc_method_name} can remove hosts from a test, or be skipped if empty" do
    assert hosts.length() > 0, "#{pstc_method_name} did not have enough hosts to test"
    previous_hosts = hosts.dup

    options[:platform_tag_confines] = [
      :platform => /#{default[:platform]}/,
      :tag_reason_hash => {
        'tag1' => 'reason1'
      }
    ]

    begin
      tag( 'tag1' )
    rescue Beaker::DSL::Outcomes::SkipTest => e
      if e.message =~ /^No\ suitable\ hosts\ found$/
        # SkipTest is raised in the case when there are no hosts leftover for a test
        # after confining. It's a very common acceptance test case where all of the
        # hosts involved are of the same platform, and are thus all confined
        # away by the code being run here. In this case, the hosts object will not
        # be altered, but should be considered a pass, since the fact that SkipTest
        # is being raised confirms that a lower number of hosts are coming out of
        # the confine (0) than came in (>0, according to our pre-condition assertion)
      else
        fail "#{pstc_method_name} raised unexpected SkipTest exception: #{e}"
      end
    else
      assert hosts.length() < previous_hosts.length(), "#{pstc_method_name} did not change hosts array"
    end

    # cleanup
    options[:platform_tag_confines_object] = nil
    options[:platform_tag_confines] = nil
    @hosts = previous_hosts
  end
end