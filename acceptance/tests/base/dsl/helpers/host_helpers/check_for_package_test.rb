require "helpers/test_helper"

# Return the name of a platform-specific package known to be installed on a system
def known_installed_package
  case default['platform']
  when /solaris.*11/
    "shell/bash"
  when /solaris.*10/
    "SUNWbash"
  when /windows/
    "bash"
  else
    "rsync"
  end
end

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
      result = check_for_package default, known_installed_package
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      assert_raises NoMethodError do
        check_for_package hosts, known_installed_package
      end
    end
  end

  confine_block :to, :platform => /solaris/ do

    step "#check_for_package will return false if the specified package is not installed on the remote host" do
      result = check_for_package default, "non-existent-package-name"
      assert !result
    end

    step "#check_for_package will return true if the specified package is installed on the remote host" do
      result = check_for_package default, known_installed_package
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      assert_raises NoMethodError do
        check_for_package hosts, known_installed_package
      end
    end
  end

  confine_block :to, :platform => /osx/ do
    step "#check_for_package CURRENTLY fails with a RuntimeError on OS X" do
      assert_raises RuntimeError do
        check_for_package default, known_installed_package
      end
    end
  end

  confine_block :except, :platform => /windows|solaris|osx/ do

    step "#check_for_package will return false if the specified package is not installed on the remote host" do
      result = check_for_package default, "non-existent-package-name"
      assert !result
    end

    step "#check_for_package will return true if the specified package is installed on the remote host" do
      install_package default, known_installed_package
      result = check_for_package default, known_installed_package
      assert result
    end

    step "#check_for_package CURRENTLY fails if given a host array" do
      # NOTE: would expect this to work across hosts, or to be better
      #       documented. If not supported, should raise
      #       Beaker::Host::CommandFailure

      assert_raises NoMethodError do
        check_for_package hosts, known_installed_package
      end
    end
  end
end
