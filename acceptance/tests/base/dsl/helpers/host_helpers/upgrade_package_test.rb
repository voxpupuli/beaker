require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #upgrade_package" do

  # NOTE: there does not appear to be a way to confine just to cygwin hosts
  confine_block :to, :platform => /windows/ do

    # NOTE: check_for_package on windows currently fails as follows:
    #
    #       ArgumentError: wrong number of arguments (3 for 1..2)
    #
    #       Would expect this to be documented better, and to fail with Beaker::Host::CommandFailure

    step "#upgrade_package CURRENTLY fails on windows platforms with a RuntimeError" do
      # NOTE: this is not a supported platform but would expect a Beaker::Host::CommandFailure
      assert_raises RuntimeError do
        upgrade_package default, "bash"
      end
    end
  end

  confine_block :to, :platform => /osx/ do

    step "#upgrade_package CURRENTLY fails with a RuntimeError on OS X" do
      # NOTE: documentation could be better on this method
      assert_raises RuntimeError do
        upgrade_package default, "bash"
      end
    end
  end

  confine_block :except, :platform => /windows|osx/ do
    confine_block :to, :platform => /centos|el-\d/ do

      step "#upgrade_package CURRENTLY does not fail on CentOS if unknown package is specified" do
        # NOTE: I would expect this to fail with an Beaker::Host::CommandFailure,
        #       but maybe it's because yum doesn't really care:
        #
        #       > Loaded plugins: fastestmirror
        #       > Loading mirror speeds from cached hostfile
        #       > Setting up Update Process
        #       > No package non-existent-package-name available.
        #       > No Packages marked for Update

        result = upgrade_package default, "non-existent-package-name"
        assert_match(/No Packages marked for Update/i, result)
      end
    end

    confine_block :except, :platform => /centos|el-\d/ do

      step "#upgrade_package fails if package is not already installed" do
        assert_raises Beaker::Host::CommandFailure do
          upgrade_package default, "non-existent-package-name"
        end
      end
    end

    step "#upgrade_package succeeds if package is installed" do
      # TODO: anyone have any bright ideas on how to portably install an old
      # version of a package, to really test an upgrade?

      install_package default, "rsync"
      upgrade_package default, "rsync"
      assert check_for_package(default, "rsync"), "package was not successfully installed/upgraded"
    end

    step "#upgrade_package CURRENTLY fails when given a host array" do
      # NOTE: would expect this to work across hosts, or to be better documented,
      #       if not support, should raise Beaker::Host::CommandFailure

      assert_raises NoMethodError do
        upgrade_package hosts, "rsync"
      end
    end
  end
end
