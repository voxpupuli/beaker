require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #add_system32_hosts_entry" do

  confine_block :to, :platform => /windows/ do

    step "#add_system32_hosts_entry fails when run on a non-powershell platform" do
      # NOTE: would expect this to be better documented.
      if default.is_powershell?
        logger.info "Skipping failure test on powershell platforms..."
      else
        assert_raises RuntimeError do
          add_system32_hosts_entry default, { :ip => '123.45.67.89', :name => 'beaker.puppetlabs.com' }
        end
      end
    end

    step "#add_system32_hosts_entry, when run on a powershell platform, adds a host entry to system32 etc\\hosts" do
      if default.is_powershell?
        add_system32_hosts_entry default, { :ip => '123.45.67.89', :name => 'beaker.puppetlabs.com' }

        # TODO: how do we assert, via powershell, that the entry was added?
        # NOTE: see: https://github.com/puppetlabs/beaker/commit/685628f4babebe9cb4663418da6a8ff528dd32da#commitcomment-12957573

      else
        logger.info "Skipping test on non-powershell platforms..."
      end
    end

    step "#add_system32_hosts_entry CURRENTLY fails with a TypeError when given a hosts array" do
      # NOTE: would expect this to fail with Beaker::Host::CommandFailure
      assert_raises NoMethodError do
        add_system32_hosts_entry hosts, { :ip => '123.45.67.89', :name => 'beaker.puppetlabs.com' }
      end
    end
  end

  confine_block :except, :platform => /windows/ do

    step "#add_system32_hosts_entry CURRENTLY fails with RuntimeError when run on a non-windows platform" do
      # NOTE: would expect this to behave the same way it does on a windows
      #       non-powershell platform (raises Beaker::Host::CommandFailure), or
      #       as requested in the original PR:
      #       https://github.com/puppetlabs/beaker/pull/420/files#r17990622
      assert_raises RuntimeError do
        add_system32_hosts_entry default, { :ip => '123.45.67.89', :name => 'beaker.puppetlabs.com' }
      end
    end
  end
end
