$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..', '..', 'lib'))

require 'helpers/test_helper'

test_name "dsl::helpers::host_helpers #check_for_package" do

  # NOTE: there does not appear to be a way to confine just to cygwin hosts
  confine_block :to, :platform => /windows/ do

    # NOTE: check_for_package on windows currently fails as follows:
    #
    #       ArgumentError: wrong number of arguments (3 for 1..2)
    #
    #       Would expect this to be documented better, and to fail with Beaker::Host::CommandFailure

    step "#check_for_package will return false if the specified package is not installed on the remote host" do
      result = check_for_package default, "non-existent-package-name"
      assert !result
    end

    step "#check_for_package will return true if the specified package is installed on the remote host" do
      result = check_for_package default, "bash"
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      assert_raises NoMethodError do
        check_for_package hosts, "rsync"
      end
    end
  end

  confine_block :to, :platform => /solaris/ do

    step "#check_for_package will return false if the specified package is not installed on the remote host" do
      result = check_for_package default, "non-existent-package-name"
      assert !result
    end

    step "#check_for_package will return true if the specified package is installed on the remote host" do
      result = check_for_package default, "SUNWbash"
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      assert_raises NoMethodError do
        check_for_package hosts, "rsync"
      end
    end
  end

  confine_block :except, :platform => /windows|solaris/ do

    step "#check_for_package will return false if the specified package is not installed on the remote host" do
      result = check_for_package default, "non-existent-package-name"
      assert !result
    end

    step "#check_for_package will return true if the specified package is installed on the remote host" do
      install_package default, "rsync"
      result = check_for_package default, "rsync"
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      # NOTE: would expect this to work across hosts, or to be better
      #       documented. If not supported, should raise
      #       Beaker::Host::CommandFailure

      assert_raises NoMethodError do
        check_for_package hosts, "rsync"
      end
    end
  end
end
