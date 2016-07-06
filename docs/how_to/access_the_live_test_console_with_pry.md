## What's Pry?

[Pry](http://pryrepl.org/) is a powerful Ruby editing and debugging tool.  Beaker uses Pry runtime invocation to create a developer console.

## Set it up!

Pry is included in the Beaker 1.13+ development gems and is available by default.  

Pre-1.13.0 add Pry with `gem install pry`, then add Pry to individual tests by adding `require 'pry'` as the first line in the Ruby test file.

## Invoke the Developer Console

In a Beaker test file call `binding.pry` to invoke the console.  Place it where you want access to the full, current Beaker environment.

## Example
### Example test trypry.rb
Here's a test file that exercises different ways of running commands on Beaker hosts.  At the end of the main `hosts.each` loop I've included `binding.pry` to invoke the console.

```
hosts.each do |h|
  on h, "echo hello"
  if h['platform'] =~ /windows/
    scp_to h, "beaker.gemspec", "/cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/"
  end
  on(h, "echo test block") do |result|
      puts "block result.stdout: #{result.stdout}"
      puts "block result.raw_stdout: #{result.raw_stdout}"
  end
  on(h, "echo test block, built in functions") do
      puts "built in function stdout: #{stdout}"
      puts "built in function stderr: #{stderr}"
  end

  result = on(h, "echo no block")
  puts "return var result.stdout: #{result.stdout}"
  puts "return var result.raw_stdout: #{result.raw_stdout}"

  binding.pry

end
```

### Sample output to the first `binding.pry` call:
```
$ bundle exec beaker --debug --tests tests/trypry.rb --hosts configs/fusion/winfusion.cfg --no-provi
sion
{
    "project": "Beaker",
    "department": "anode",
    "validate": true,
    "jenkins_build_url": null,
    "forge_host": "vulcan-acceptance.delivery.puppetlabs.net",
    "log_level": "debug",
    "trace_limit": 10,
    "hosts_file": "configs/fusion/winfusion.cfg",
    "options_file": null,
    "type": "pe",
    "provision": false,
    "preserve_hosts": "never",
    "root_keys": false,
    "quiet": false,
    "xml": false,
    "color": true,
    "dry_run": false,
    "timeout": 300,
    "fail_mode": "slow",
    "timesync": false,
    "repo_proxy": false,
    "add_el_extras": false,
    "add_master_entry": false,
    "consoleport": 443,
    "pe_dir": "http://neptune.puppetlabs.lan/3.2/ci-ready/",
    "pe_version_file": "LATEST",
    "pe_version_file_win": "LATEST-win",
    "dot_fog": "/Users/anode/.fog",
    "ec2_yaml": "config/image_templates/ec2.yaml",
    "help": false,
    "ssh": {
        "config": false,
        "paranoid": false,
        "timeout": 300,
        "auth_methods": [
            "publickey"
        ],
        "port": 22,
        "forward_agent": true,
        "keys": [
            "/Users/anode/.ssh/id_rsa"
        ],
        "user_known_hosts_file": "/Users/anode/.ssh/known_hosts"
    },
    "tests": [
        "tests/trypry.rb"
    ],
    "command_line": "/Users/anode/beaker/.bundle/gems/bin/beaker --debug --tests tests/trypry.rb --hosts configs/fusion/winfusion.cfg --no-provision",
    "HOSTS": {
        "pe-centos6": {
            "roles": [
                "master",
                "agent",
                "dashboard",
                "database"
            ],
            "platform": "el-6-i386",
            "snapshot": "clean-w-keys",
            "hypervisor": "fusion"
        },
        "w2k8r2": {
            "roles": [
                "agent"
            ],
            "platform": "windows-2008r2-x86_64",
            "snapshot": "clean-w-keys",
            "hypervisor": "fusion"
        },
        "w2k3r2": {
            "roles": [
                "agent"
            ],
            "platform": "windows-2003r2-x86_64",
            "hypervisor": "fusion",
            "snapshot": "clean-w-keys"
        }
    },
    "nfs_server": "none",
    "pe_ver": "3.2.2-6-gd1cae98",
    "home": "/Users/anode",
    "answers": {
        "q_puppet_enterpriseconsole_auth_user_email": "admin@example.com",
        "q_puppet_enterpriseconsole_auth_password": "~!@#$%^*-/ aZ",
        "q_puppet_enterpriseconsole_smtp_host": null,
        "q_puppet_enterpriseconsole_smtp_port": 25,
        "q_puppet_enterpriseconsole_smtp_username": null,
        "q_puppet_enterpriseconsole_smtp_password": null,
        "q_puppet_enterpriseconsole_smtp_use_tls": "n",
        "q_verify_packages": "y",
        "q_puppetdb_password": "~!@#$%^*-/ aZ"
    },
    "helper": [],
    "load_path": [],
    "pre_suite": [],
    "post_suite": [],
    "install": [],
    "modules": [],
    "logger": "#<Beaker::Logger:0x007f925a6b4218>"
}
Hypervisor for pe-centos6 is none
Hypervisor for w2k8r2 is none
Hypervisor for w2k3r2 is none
Beaker::Hypervisor, found some none boxes to create

pe-centos6 10:55:27$  which curl  
/usr/bin/curl

pe-centos6 executed in 0.14 seconds

pe-centos6 10:55:27$  which ntpdate  
/usr/sbin/ntpdate

pe-centos6 executed in 0.01 seconds

w2k8r2 10:55:27$  which curl  
/bin/curl

w2k8r2 executed in 0.42 seconds

w2k3r2 10:55:27$  which curl  
/bin/curl

w2k3r2 executed in 0.29 seconds
No tests to run for suite 'pre_suite'
Begin tests/trypry.rb

pe-centos6 10:55:28$  echo hello  
hello

pe-centos6 executed in 0.01 seconds

pe-centos6 10:55:28$  echo test block  
test block

pe-centos6 executed in 0.01 seconds
block result.stdout: test block
block result.raw_stdout: test block

pe-centos6 10:55:28$  echo test block, built in functions  
test block, built in functions

pe-centos6 executed in 0.00 seconds
built in function stdout: test block, built in functions
built in function stderr:

pe-centos6 10:55:28$  echo no block  
no block

pe-centos6 executed in 0.00 seconds
return var result.stdout: no block
return var result.raw_stdout: no block

From: /Users/anode/beaker/tests/trypry.rb @ line 19 self.run_test:

    14:
    15:   result = on(h, "echo no block")
    16:   puts "return var result.stdout: #{result.stdout}"
    17:   puts "return var result.raw_stdout: #{result.raw_stdout}"
    18:
 => 19:   binding.pry
    20:
    21: end

[1] pry(#<Beaker::TestCase>)>
```
### Using the console
At this point I have access to the console.  I have full access to Beaker hosts, the Beaker DSL and Ruby.

Here's some sample console calls:
```
[1] pry(#<Beaker::TestCase>)> hosts
=> [pe-centos6, w2k8r2, w2k3r2]
[2] pry(#<Beaker::TestCase>)> on hosts[1], 'echo hello'

w2k8r2 10:54:11$  echo hello  
hello

w2k8r2 executed in 0.07 seconds
=> #<Beaker::Result:0x007f9f6b7a3408
 @cmd=" echo hello  ",
 @exit_code=0,
 @host="w2k8r2",
 @output="hello\n",
 @raw_output="hello\n",
 @raw_stderr="",
 @raw_stdout="hello\n",
 @stderr="",
 @stdout="hello\n">
[3] pry(#<Beaker::TestCase>)> on hosts[1], 'ls /cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/'

w2k8r2 10:56:15$  ls /cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/  
Application Data
Desktop
Documents
Favorites
Microsoft
Package Cache
Start Menu
Templates
VMware
beaker.gemspec
ntuser.pol

w2k8r2 executed in 0.09 seconds
=> #<Beaker::Result:0x007f925b227898
 @cmd=
  " ls /cygdrive/c/Documents\\ and\\ Settings/All\\ Users/Application\\ Data/  ",
 @exit_code=0,
 @host="w2k8r2",
 @output=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @raw_output=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @raw_stderr="",
 @raw_stdout=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @stderr="",
 @stdout=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n">
[4] pry(#<Beaker::TestCase>)> result = on hosts[1], 'ls /cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/'

w2k8r2 10:56:34$  ls /cygdrive/c/Documents\ and\ Settings/All\ Users/Application\ Data/  
Application Data
Desktop
Documents
Favorites
Microsoft
Package Cache
Start Menu
Templates
VMware
beaker.gemspec
ntuser.pol

w2k8r2 executed in 0.08 seconds
=> #<Beaker::Result:0x007f925a387018
 @cmd=
  " ls /cygdrive/c/Documents\\ and\\ Settings/All\\ Users/Application\\ Data/  ",
 @exit_code=0,
 @host="w2k8r2",
 @output=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @raw_output=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @raw_stderr="",
 @raw_stdout=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n",
 @stderr="",
 @stdout=
  "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol\n">
[5] pry(#<Beaker::TestCase>)> result.stdout.chomp
=> "Application Data\nDesktop\nDocuments\nFavorites\nMicrosoft\nPackage Cache\nStart Menu\nTemplates\nVMware\nbeaker.gemspec\nntuser.pol"
```
### Continue regular test execution
Simply `exit` the console.
```
[6] pry(#<Beaker::TestCase>)> exit
```
