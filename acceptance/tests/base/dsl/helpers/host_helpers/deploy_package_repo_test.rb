require "helpers/test_helper"
require "fileutils"

test_name "dsl::helpers::host_helpers #deploy_package_repo" do

  confine_block :to, :platform => /^el-4/ do

    step "#deploy_package_repo CURRENTLY does nothing and throws no error on the #{default['platform']} platform" do
      # NOTE: would expect this to fail with Beaker::Host::CommandFailure

      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        create_local_file_from_fixture("simple_text_file", local_dir, "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        assert_nil deploy_package_repo(default, local_dir, name, version)
      end
    end
  end

  confine_block :to, :platform => /fedora|centos|eos|el-[56789]/i do

    step "#deploy_package_repo pushes repo package to /etc/yum.repos.d on the remote host" do
      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        FileUtils.mkdir(File.join(local_dir, "rpm"))
        _local_filename, contents = create_local_file_from_fixture("simple_text_file", File.join(local_dir, "rpm"), "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        deploy_package_repo default, local_dir, name, version

        remote_contents = on(default, "cat /etc/yum.repos.d/#{name}.repo").stdout
        assert_equal contents, remote_contents

        # teardown
        on default, "rm /etc/yum.repos.d/#{name}.repo"
      end
    end

    step "#deploy_package_repo CURRENTLY fails with NoMethodError when passed a hosts array" do
      # NOTE: would expect this to handle host arrays, or raise Beaker::Host::CommandFailure

      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        create_local_file_from_fixture("simple_text_file", local_dir, "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        assert_raises NoMethodError do
          deploy_package_repo hosts, local_dir, name, version
        end
      end
    end
  end

  confine_block :to, :platform => /ubuntu|debian|cumulus/i do

    step "#deploy_package_repo pushes repo package to /etc/apt/sources.list.d on the remote host" do
      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        codename = default['platform'].codename

        FileUtils.mkdir(File.join(local_dir, "deb"))
        _local_filename, contents = create_local_file_from_fixture("simple_text_file", File.join(local_dir, "deb"), "pl-#{name}-#{version}-#{codename}.list")

        deploy_package_repo default, local_dir, name, version

        remote_contents = on(default, "cat /etc/apt/sources.list.d/#{name}.list").stdout
        assert_equal contents, remote_contents

        # teardown
        on default, "rm /etc/apt/sources.list.d/#{name}.list"
      end
    end

    step "#deploy_package_repo CURRENTLY fails with NoMethodError when passed a hosts array" do
      # NOTE: would expect this to handle host arrays, or raise Beaker::Host::CommandFailure

      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        codename = default['platform'].codename

        FileUtils.mkdir(File.join(local_dir, "deb"))
        create_local_file_from_fixture("simple_text_file", File.join(local_dir, "deb"), "pl-#{name}-#{version}-#{codename}.list")

        assert_raises NoMethodError do
          deploy_package_repo hosts, local_dir, name, version
        end
      end
    end
  end

  confine_block :to, :platform => /opensuse|sles/i do

    step "#deploy_package_repo updates zypper repository list on the remote host" do
      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        FileUtils.mkdir(File.join(local_dir, "rpm"))
        create_local_file_from_fixture("#{default["platform"]}.repo", File.join(local_dir, "rpm"), "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        deploy_package_repo default, local_dir, name, version

        result = on default, "zypper repos -d"
        assert_match "PE-2016.4-#{default['platform']}", result.stdout

        # teardown
        on default, "zypper rr #{default['platform']}"
      end
    end
  end

  confine_block :except, :platform => /el-\d|fedora|centos|eos|ubuntu|debian|cumulus|opensuse|sles/i do

    # OS X, windows (cygwin, powershell), solaris, etc.

    step "#deploy_package_repo CURRENTLY fails with a RuntimeError on on the #{default['platform']} platform" do
      # NOTE: would expect this to raise Beaker::Host::CommandFailure instead of RuntimeError

      Dir.mktmpdir do |local_dir|
        name = "puppet-server"
        version = "9.9.9"
        platform = default['platform']

        create_local_file_from_fixture("simple_text_file", local_dir, "pl-#{name}-#{version}-repos-pe-#{platform}.repo")

        assert_raises RuntimeError do
          deploy_package_repo default, local_dir, name, version
        end
      end
    end
  end
end
