#Beaker for Modules
##Read the Beaker Docs

[Beaker How To](https://github.com/puppetlabs/beaker/wiki)

<a href = "http://rubydoc.info/github/puppetlabs/beaker/frames">Beaker DSL API</a>

##Understand the Difference Between beaker and beaker-rspec
[beaker vs. beaker-rspec](https://github.com/puppetlabs/beaker/wiki/beaker-vs.-beaker-rspec)

##beaker-rspec Details
###Supported ENV variables

`BEAKER_debug` - turn on extended debug logging

`BEAKER_set` - set to the name of the node file to be used during testing (exclude .yml file extension, it will be added by beaker-rspec), assumed to be in module's spec/acceptance/nodesets directory

`BEAKER_setfile` - set to the full path to a node file be used during testing (be sure to include full path and file extensions, beaker-rspec will use this path without editing/altering it in any way)

`BEAKER_destroy` - set to `no` to preserve test boxes after testing, set to `onpass` to destroy only if tests pass

`BEAKER_provision` - set to `no` to skip provisioning boxes before testing, will then assume that boxes are already provisioned and reachable

##Typical Workflow

1. Run tests with `BEAKER_destroy=no`, no setting for `BEAKER_provision`
  * beaker-rspec will use spec/acceptance/nodesets/default.yml node file
  * boxes will be newly provisioned
  * boxes will be preserved post-testing
* Run tests with `BEAKER_destroy=no` and `BEAKER_provision=no`
  * beaker-rspec will use spec/acceptance/nodesets/default.yml node file
  * boxes will be re-used from previous run
  * boxes will be preserved post-testing
* Nodes become corrupted with too many test runs/bad data and need to be refreshed then GOTO step 1
* Testing is complete and you want to clean up, run once more with `BEAKER_destroy` unset
  * you can also:

        cd .vagrant/beaker_vagrant_files/default.yml ; vagrant destroy --force

##Building your Module Testing Environment

Using puppetlabs-mysql as an example module.

###Clone the module repository of the module that you wish to test

    git clone https://github.com/puppetlabs/puppetlabs-mysql
    cd puppetlabs-mysql

###Create the spec_helper_acceptance.rb

Create example file spec_helper_acceptance.rb:
```ruby
require 'beaker-rspec'
require 'pry'

hosts.each do |host|
  # Install Puppet
  on host, install_puppet
end

RSpec.configure do |c|
  module_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module
    puppet_module_install(:source => module_root, :module_name => 'mysql')
    hosts.each do |host|
      on host, puppet('module','install','puppetlabs-stdlib'), { :acceptable_exit_codes => [0,1] }
    end
  end
end
```

Update spec_helper_acceptance.rb to reflect the module under test.  You will need to set the correct module name and add any module dependencies.  Place the file in the /spec directory (in this case puppetlabs-mysql/spec)

###Install beaker-rspec
####From Gem (preferred)

    gem install beaker-rspec pry

###Update the module's Gemfile

In module's top level directory edit the Gemfile. If there is a section that
begins `group :development, :test do`, then add it there.

```ruby
gem 'beaker-rspec', :require => false
gem 'pry',          :require => false
```

Then run

    bundle install

###Create node files

These files indicate the nodes (or hosts) that the tests will be run on.  By default, any node file called `default.yml` will be used.  You can override this using the `BEAKER_set` environment variable to indicate an alternate file.  Do not provide full path or the '.yml' file extension to `BEAKER_set`, it is assumed to be located in 'spec/acceptance/nodesets/${NAME}.yml' by beaker-rspec.  If you wish to use a completely different file location use `BEAKER_setfile` and set it to the full path (including file extension) of your hosts file.

Nodes are pulled from <a href = "https://vagrantcloud.com/puppetlabs">Puppet Labs Vagrant Boxes</a>.

Example node files can be found here:

*[Puppet Labs example Vagrant node files](Example-Vagrant-Hosts-Files.md)

Create the nodesets directory.  From module's top level directory:

    mkdir -p spec/acceptance/nodesets

Copy any nodesets that you wish to use into the nodesets directory.

###Create spec tests for your module

Spec tests are written in <a href = "http://rspec.info/">RSpec</a>.

Example spec file (mysql_account_delete_spec.rb):

```ruby
require 'spec_helper_acceptance'

describe 'mysql::server::account_security class' do
  describe 'running puppet code' do
    it 'should work with no errors' do
      pp = <<-EOS
        class { 'mysql::server': remove_default_accounts => true }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, :catch_failures => true)
      expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
    end

    describe 'accounts' do
      it 'should delete accounts' do
        shell("mysql -e 'show grants for root@127.0.0.1;'", :acceptable_exit_codes => 1)
      end

      it 'should delete databases' do
        shell("mysql -e 'show databases;' |grep test", :acceptable_exit_codes => 1)
      end
    end
  end
end
```
###Run your spec tests

From module's top level directory

    bundle exec rspec spec/acceptance
