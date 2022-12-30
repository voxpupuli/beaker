test_name "dsl::structure" do
  step "#confine_block runs specified block on matching hosts" do
    begin
      @in_confine = 0
      confine_block :to, :platform => default["platform"] do
        @in_confine +=1
      end

      assert_equal 1, @in_confine, "#confine_block did not run the supplied block"

    rescue Beaker::DSL::Outcomes::SkipTest => e
      fail "#confine_block raised unexpected SkipTest exception: #{e}"
    end
  end

  step "#confine_block leaves hosts array intact after running block on matching hosts" do
    begin
      @in_confine = 0
      confine_block :to, :platform => default["platform"] do
        @in_confine +=1
      end

      assert_equal 1, @in_confine, "#confine_block did not run the supplied block"
      assert_equal hosts.dup, hosts, "#confine_block did not preserve the hosts array"

    rescue Beaker::DSL::Outcomes::SkipTest => e
      fail "#confine_block raised unexpected SkipTest exception: #{e}"
    end
  end

  step "#confine_block will not run specified block on non-matching hosts" do
    begin
      @in_confine = 0
      confine_block :except, :platform => default["platform"] do
        @in_confine +=1
      end

      assert_equal 0, @in_confine, "#confine_block did not skip the supplied block"

    rescue Beaker::DSL::Outcomes::SkipTest => e
      fail "#confine_block raised unexpected SkipTest exception: #{e}"
    end
  end

  step "#confine_block leaves hosts array intact after skipping block on non-matching hosts" do
    begin
      @in_confine = 0
      confine_block :except, :platform => default["platform"] do
        @in_confine +=1
      end

      assert_equal 0, @in_confine, "#confine_block did not skip the supplied block"
      assert_equal hosts.dup, hosts, "#confine_block did not preserve the hosts array"

    rescue Beaker::DSL::Outcomes::SkipTest => e
      fail "#confine_block raised unexpected SkipTest exception: #{e}"
    end
  end

  step "#confine_block allows blocks to raise skip_test" do
    begin
      @in_confine = 0
      confine_block :to, :platform => default["platform"] do
        @in_confine +=1
        skip_test "this block raises a skip"
      end
    rescue Beaker::DSL::Outcomes::SkipTest => e
      assert_match(/this block raises a skip/, e.message, "#confine_block raised an unexpected skip_test")
      assert_equal 1, @in_confine, "#confine_block did not execute supplied block"
      assert_equal hosts.dup, hosts, "#confine_block did not preserve the hosts array"
    end
  end

  step "#confine reports correct message and skips test when criteria doesn't match on 'to'" do
    begin
      confine :to, { :platform => 'test' }

      fail "#confine did not skip test but should have."

    rescue Beaker::DSL::Outcomes::SkipTest => e
      assert_match(/No suitable hosts found with {:platform=>"test"}/, e.message, "#confine raised an unexpected skip_test")
    end
  end

  step "#confine reports correct message  and skips test when criteria doesn't match on 'except'" do
    begin
      confine :except, { :platform => default['platform'] }

      fail "#confine did not skip test but should have."

    rescue Beaker::DSL::Outcomes::SkipTest => e
      assert_match(/No suitable hosts found without {:platform=>"#{default['platform']}"}/, e.message, "#confine raised an unexpected
      # skip_test")
    end
  end
end
