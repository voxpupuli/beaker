ruby_version, ruby_source = ENV['RUBY_VER'], "job parameter"
unless ruby_version
  ruby_version = "2.4.1"
  ruby_source = "default"
end
test_name "Install and configure Ruby #{ruby_version} (from #{ruby_source}) on the SUT" do

  step 'Ensure that the default system is an el-based system' do
    # The pre-suite currently only supports el systems, and we should
    #fail early if the default platform is not a supported platform
    assert(default.platform.variant == 'el',
           "Expected the platform variant to be 'el', not #{default.platform.variant}")
  end

  step 'clean out current ruby and its dependencies' do
    on default, 'yum remove ruby ruby-devel -y'
  end

  # These steps install git, openssl, and wget
  step 'install development dependencies' do
    on default, 'yum groupinstall "Development Tools" -y'
    on default, 'yum install openssl-devel -y'
    on default, 'yum install wget -y'
  end

  step "download and install ruby #{ruby_version}" do
    on default, "wget http://cache.ruby-lang.org/pub/ruby/#{ruby_version[0..2]}/ruby-#{ruby_version}.tar.gz"
    on default, "tar xvfz ruby-#{ruby_version}.tar.gz"
    on default, "cd ruby-#{ruby_version};./configure"
    on default, "cd ruby-#{ruby_version};make"
    on default, "cd ruby-#{ruby_version};make install"
  end

  step 'update gem on the SUT and install bundler' do
    on default, 'gem update --system;gem install --force bundler'
  end
end
