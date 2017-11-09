test_name 'Install and configure Ruby 2.2.5 on the SUT' do

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

  step 'download and install ruby 2.2.5' do
    on default, 'wget http://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.5.tar.gz'
    on default, 'tar xvfz ruby-2.2.5.tar.gz'
    on default, 'cd ruby-2.2.5;./configure'
    on default, 'cd ruby-2.2.5;make'
    on default, 'cd ruby-2.2.5;make install'
  end

  step 'update gem on the SUT and install bundler' do
    on default, 'gem update --system;gem install --force bundler'
  end
end
