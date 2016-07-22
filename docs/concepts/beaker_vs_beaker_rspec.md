## How they relate

beaker is an acceptance testing framework that is written in Ruby.  beaker-rspec is a small shim that integrates the [beaker DSL](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL) (domain specific language) with [RSpec](http://rspec.info/) (a spec test format) and [Serverspec](http://serverspec.org/) (an extension to RSpec that provides many useful matchers).

![beaker vs. beaker-rspec (venn)](http://anodelman.github.io/shared/img/beaker_vs_beaker_rspec.jpg)

## beaker
* provisions and configures test hosts
* tests are just Ruby scripts
* tests pass if they execute all the way through without errors/exceptions
* tests can also use asserts to explicitly enforce a state
* tests written in Ruby with Beaker's domain specific language extensions
* tests can re-use functionality by using ruby constructs
* tests are driven by Beaker's own test runner

### An example beaker test ###
    test_name "Be able to execute multi-line commands (#9996)"
    confine :except, :platform => 'windows'
    agents.each do |agent|
      temp_file_name = agent.tmpfile('9996-multi-line-commands')
      test_manifest = <<HERE
    exec { "test exec":
          command =>  "/bin/echo '#Test' > #{temp_file_name};
                       /bin/echo 'bob' >> #{temp_file_name};"
    }
    HERE
      expected_results = <<HERE
    #Test
    bob
    HERE
      on(agent, "rm -f #{temp_file_name}")
      apply_manifest_on agent, test_manifest
      on(agent, "cat #{temp_file_name}") do
        assert_equal(expected_results, stdout, "Unexpected result for host '#{agent}'")
      end
      on(agent, "rm -f #{temp_file_name}")
    end

## beaker-rspec
* builds on [RSpec](http://rspec.info/) and [Serverspec](http://serverspec.org/)
* provisions and configures test hosts
* tests pass when all asserted expectations are fulfilled
* tests written in RSpec format, with Beaker data specific language extensions and Serverspec matchers
* tests can re-use functionality by using ruby or RSpec constructs
* tests are driven by RSpec's test runner

### An example beaker-rspec test ###
    require 'spec_helper_acceptance'

    describe 'apache class' do
      case fact('osfamily')
      when 'RedHat'
        package_name = 'httpd'
        service_name = 'httpd'
      when 'Debian'
        package_name = 'apache2'
        service_name = 'apache2'
      when 'FreeBSD'
        package_name = 'apache24'
        service_name = 'apache24'
      when 'Gentoo'
        package_name = 'www-servers/apache'
        service_name = 'apache2'
      end

      context 'default parameters' do
        it 'should work with no errors' do
          pp = <<-EOS
          class { 'apache': }
          EOS

          # Run it twice and test for idempotency
          apply_manifest(pp, :catch_failures => true)
          expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
        end

        describe package(package_name) do
          it { is_expected.to be_installed }
        end

        describe service(service_name) do
          it { is_expected.to be_enabled }
          it { is_expected.to be_running }
        end

        describe port(80) do
          it { should be_listening }
        end
      end
    end

## How to choose?

* Use the tool already in use in the project you are contributing to.
* beaker-rspec is used by many modules inside and outside of Puppet Labs for system-level and acceptance tests.
* beaker is used for all other testing within Puppet Labs (puppet, puppetDB, Puppet Enterprise, etc).
