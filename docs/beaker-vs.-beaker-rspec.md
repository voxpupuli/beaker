## How they relate

beaker is an acceptance testing program that is written Ruby.  beaker-rspec is a combination of the [beaker DSL](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL) (domain specific language) with [RSpec](http://rspec.info/) (a spec test format) and [Serverspec](http://serverspec.org/) (an extension to RSpec that provides many useful matchers).

![beaker vs. beaker-rspec (venn)](http://anodelman.github.io/shared/img/beaker_vs_beaker_rspec.jpg)

## beaker
* can provision and configure test hosts
* tests are just Ruby files
* tests are considered to have passed if they execute all the way through without errors/exceptions
* tests can also use asserts to explicitly enforce a state
* tests written in Ruby with Beaker data specific language extensions

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
* uses [RSpec](http://rspec.info/) and [Serverspec](http://serverspec.org/)
* can provision and configure test hosts
* tests are considered to have passed when explicit asserts succeed
* tests written in Rspec format, with Beaker data specific language extensions and Serverspec matchers

### An example beaker-rspec test ###
    require 'spec_helper_acceptance'
    case fact('osfamily')
    when 'FreeBSD'
      line = '0.freebsd.pool.ntp.org maxpoll 9 iburst'
    when 'Debian'
      line = '0.debian.pool.ntp.org iburst'
    when 'RedHat'
      line = '0.centos.pool.ntp.org'
    when 'Suse'
      line = '0.opensuse.pool.ntp.org'
    when 'Gentoo'
      line = '0.gentoo.pool.ntp.org'
    when 'Linux'
      case fact('operatingsystem')
      when 'ArchLinux'
        line = '0.pool.ntp.org'
      when 'Gentoo'
        line = '0.gentoo.pool.ntp.org'
      end
    when 'Solaris'
      line = '0.pool.ntp.org'
    when 'AIX'
       line = '0.debian.pool.ntp.org iburst'
    end
    if (fact('osfamily') == 'Solaris')
      config = '/etc/inet/ntp.conf'
    else
      config = '/etc/ntp.conf'
    end
    describe 'ntp::config class', :unless => UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
      it 'sets up ntp.conf' do
        apply_manifest(%{
          class { 'ntp': }
        }, :catch_failures => true)
      end
      describe file("#{config}") do
        it { should be_file }
        its(:content) { should match line }
      end
    end

## How to choose?

* beaker-rspec is intended for use as a module testing tool.  
* beaker is used for all other testing (puppet, puppetDB, Puppet Enterprise, etc).
