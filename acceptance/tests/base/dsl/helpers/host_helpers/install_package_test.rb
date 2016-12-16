require "helpers/test_helper"

test_name "dsl::helpers::host_helpers #install_package" do

  # NOTE: there does not appear to be a way to confine just to cygwin hosts
  confine_block :to, :platform => /windows/ do

    # NOTE: install_package on windows currently fails as follows:
    #
    #       ArgumentError: wrong number of arguments (3 for 1..2)
    #
    #       Would expect this to be documented better, and to fail with Beaker::Host::CommandFailure

    step "#install_package CURRENTLY fails on windows platforms" do
      assert_raises ArgumentError do
        install_package default, "rsync"
      end
    end
  end

  confine_block :to, :platform => /osx/ do
    # TODO: install_package on OSX installs via a .dmg file -- how to test this?
  end

  confine_block :except, :platform => /windows|osx/ do

    step "#install_package fails if package is not known on the OS" do
      assert_raises Beaker::Host::CommandFailure do
        install_package default, "non-existent-package-name"
      end
    end

    step "#install_package installs a known package successfully" do
      result = install_package default, "rsync"
      assert check_for_package(default, "rsync"), "package was not successfully installed"
    end

    step "#install_package succeeds when installing an already-installed package" do
      result = install_package default, "rsync"
      result = install_package default, "rsync"
      assert check_for_package(default, "rsync"), "package was not successfully installed"
    end

    step "#install_package CURRENTLY fails if given a host array" do
      # NOTE: would expect this to work across hosts, or to be better
      #       documented. If not supported, should raise
      #       Beaker::Host::CommandFailure

      assert_raises NoMethodError do
        install_package hosts, "rsync"
      end
    end
  end
end
