Beaker uses arguments and settings from a variety of sources to determine how your test run is executed.

*  [Environment Variables](Argument-Processing-and-Precedence.md#environment-variables)
* [Host/Config File Options](Argument-Processing-and-Precedence.md#host-file-options)
* [ARGV](Argument-Processing-and-Precedence.md#argv-or-provided-arguments-array)
  * [Supported Command Line Arguments](Argument-Processing-and-Precedence.md#supported-command-line-arguments)
* [Options File Values](Argument-Processing-and-Precedence.md#options-file-values)
  * [Example Options File](Argument-Processing-and-Precedence.md#example-options-file)
* [Default Values](Argument-Processing-and-Precedence.md#default-values)
  * [Beaker Default Values](Argument-Processing-and-Precedence.md#beaker-default-values)
* [Priority of Settings](Argument-Processing-and-Precedence.md#priority-of-settings)


## Environment Variables
###Supported Environment Variables:
```
        BEAKER VARIABLE NAME  => ENVIRONMENT VARIABLE NAME
        :home                 => 'HOME',
        :project              => ['BEAKER_PROJECT', 'BEAKER_project'],
        :department           => ['BEAKER_DEPARTMENT', 'BEAKER_department'],
        :jenkins_build_url    => ['BEAKER_BUILD_URL', 'BUILD_URL'],
        :created_by           => ['BEAKER_CREATED_BY'],
        :consoleport          => ['BEAKER_CONSOLEPORT', 'consoleport'],
        :is_pe                => ['BEAKER_IS_PE', 'IS_PE'],
        :pe_dir               => ['BEAKER_PE_DIR', 'pe_dist_dir'],
        :pe_version_file      => ['BEAKER_PE_VERSION_FILE', 'pe_version_file'],
        :pe_ver               => ['BEAKER_PE_VER', 'pe_ver'],
        :forge_host           => ['BEAKER_FORGE_HOST', 'forge_host'],
        :package_proxy        => ['BEAKER_PACKAGE_PROXY'],
        :release_apt_repo_url => ['BEAKER_RELEASE_APT_REPO', 'RELEASE_APT_REPO'],
        :release_yum_repo_url => ['BEAKER_RELEASE_YUM_REPO', 'RELEASE_YUM_REPO'],
        :dev_builds_url       => ['BEAKER_DEV_BUILDS_URL', 'DEV_BUILDS_URL'],
        :vbguest_plugin       => ['BEAKER_VB_GUEST_PLUGIN', 'BEAKER_vb_guest_plugin'],
        :answers              => [/\Aq_*'/],
```
## Host File Options
Any values included for an individual host in a host file.
```
HOSTS:
  pe-ubuntu-lucid:
    roles:
      - agent
      - dashboard
      - database
      - master
    vmname : pe-ubuntu-lucid
    platform: ubuntu-10.04-i386
    snapshot : clean-w-keys
    hypervisor : fusion
```
`roles`, `vmname`, `platform`, `snapshot` and `hypervisor` are all options set for the host `pe-ubuntu-lucid`.  Any additional values can be included on a per-host basis by adding arbitrary key-value pairs.

## `CONFIG` section of Hosts File
```
HOSTS:
  pe-ubuntu-lucid:
    roles:
      - agent
      - dashboard
      - database
      - master
    vmname : pe-ubuntu-lucid
    platform: ubuntu-10.04-i386
    snapshot : clean-w-keys
    hypervisor : fusion
CONFIG:
  nfs_server: none
  consoleport: 443
  pe_dir: http://path/to/pe/builds
```
`nfs_server`, `consoleport`, `pe_dir` are examples of `CONFIG` section arguments.  The values of these will be rolled up into each host defined, thus `host[pe_dir]` is valid.

## ARGV or Provided Arguments Array
```
$ beaker --debug --tests acceptance/tests/base/host.rb --hosts configs/fusion/winfusion.cfg
```
`--debug`, `--tests acceptance/tests/base/host.rb` and `--hosts configs/fusion/winfusion.cfg` are the provided command line values for this test run.

###Supported Command Line Arguments:
```
$ beaker --help
Usage: beaker [options...]
    -h, --hosts FILE                 Use host configuration FILE
                                     (default sample.cfg)
    -o, --options-file FILE          Read options from FILE
                                     This should evaluate to a ruby hash.
                                     CLI optons are given precedence.
        --type TYPE                  one of git, foss, or pe
                                     used to determine underlying path structure of puppet install
                                     (default pe)
        --helper PATH/TO/SCRIPT      Ruby file evaluated prior to tests
                                     (a la spec_helper)
        --load-path /PATH/TO/DIR,/ADDITIONAL/DIR/PATHS
                                     Add paths to LOAD_PATH
    -t /PATH/TO/DIR,/ADDITIONA/DIR/PATHS,/PATH/TO/FILE.rb,
        --tests                      Execute tests from paths and files
        --pre-suite /PRE-SUITE/DIR/PATH,/ADDITIONAL/DIR/PATHS,/PATH/TO/FILE.rb
                                     Path to project specific steps to be run BEFORE testing
        --post-suite /POST-SUITE/DIR/PATH,/OPTIONAL/ADDITONAL/DIR/PATHS,/PATH/TO/FILE.rb
                                     Path to project specific steps to be run AFTER testing
        --[no-]provision             Do not provision vm images before testing
                                     (default: true)
        --[no-]configure             Do not configure vm images before testing
                                     (default: true)
        --preserve-hosts [MODE]      How should SUTs be treated post test
                                     Possible values:
                                     always (keep SUTs alive)
                                     onfail (keep SUTs alive if failures occur during testing)
                                     onpass (keep SUTs alive if no failures occur during testing)
                                     never (cleanup SUTs - shutdown and destroy any changes made during testing)
                                     (default: never)
        --root-keys                  Install puppetlabs pubkeys for superuser
                                     (default: false)
        --keyfile /PATH/TO/SSH/KEY   Specify alternate SSH key
                                     (default: ~/.ssh/id_rsa)
        --timeout TIMEOUT            (vCloud only) Specify a provisioning timeout (in seconds)
                                     (default: 300)
    -i, --install URI                Install a project repo/app on the SUTs
                                     Provide full git URI or use short form KEYWORD/name
                                     supported keywords: PUPPET, FACTER, HIERA, HIERA-PUPPET
    -m, --modules URI                Select puppet module git install URI
    -q, --[no-]quiet                 Do not log output to STDOUT
                                     (default: false)
        --[no-]color                 Do not display color in log output
                                     (default: true)
        --log-level LEVEL            Log level
                                     Supported LEVEL keywords:
                                     trace   : all messages, full stack trace of errors, file copy details
                                     debug   : all messages, plus full stack trace of errors
                                     verbose : all messages
                                     info    : info messages, notifications and warnings
                                     notify  : notifications and warnings
                                     warn    : warnings only
                                     (default: info)
    -d, --[no-]dry-run               Report what would happen on targets
                                     (default: false)
        --fail-mode [MODE]           How should the harness react to errors/failures
                                     Possible values:
                                     fast (skip all subsequent tests)
                                     slow (attempt to continue run post test failure)
                                     stop (DEPRECATED, please use fast)
                                     (default: slow)
        --[no-]ntp                   Sync time on SUTs before testing
                                     (default: false)
        --repo-proxy                 Proxy packaging repositories on ubuntu, debian, cumulus and solaris-11
                                     (default: false)
        --add-el-extras              Add Extra Packages for Enterprise Linux (EPEL) repository to el-* hosts
                                     (default: false)
        --package-proxy URL          Set proxy url for package managers (yum and apt)
        --[no-]validate              Validate that SUTs are correctly provisioned before running tests
                                     (default: true)
        --version                    Report currently running version of beaker
        --parse-only                 Display beaker parsed options and exit
        --help                       Display this screen
    -c, --config FILE                DEPRECATED, use --hosts
        --[no-]debug                 DEPRECATED, use --log-level
    -x, --[no-]xml                   DEPRECATED - JUnit XML now generated by default
        --collect-perf-data          Use sysstat on linux hosts to collect performance and load data
```

## Options File Values
```
$ beaker --options-file additional_options.rb
```
The additional options file is provided with `--options-file /path/to/file.rb`.  The file itself must contain a properly formatted Ruby hash.  You can override any beaker internal option variable in the options file hash, but you have to associate the new value with the correct, internal key name.

### Example Options File
```
{
  :hosts_file => 'hosts.cfg',
  :ssh => {
    :keys => ["/Users/anode/.ssh/id_rsa-acceptance"],
  },
  :timeout => 1200,
  :log_level => 'debug',
  :fail_mode => 'slow',
  :tests => [
'tests/agent/agent_disable_lockfile.rb',
'tests/agent/fallback_to_cached_catalog.rb',
],
  :forge_host => 'api-forge-aio01-petest.puppetlabs.com',
  'service-wait' => true,
  'xml' => true,
}
```
## Default Values
Values already included in Beaker as defaults for required arguments.
### Beaker Default Values
```
{
          :project                => 'Beaker',
          :department             => 'unknown',
          :created_by             => ENV['USER'] || ENV['USERNAME'] || 'unknown',
          :openstack_api_key      => ENV['OS_PASSWORD'],
          :openstack_username     => ENV['OS_USERNAME'],
          :openstack_auth_url     => "#{ENV['OS_AUTH_URL']}/tokens",
          :openstack_tenant       => ENV['OS_TENANT_NAME'],
          :jenkins_build_url      => nil,
          :validate               => true,
          :configure              => true,
          :log_level              => 'info',
          :trace_limit            => 10,
          :"master-start-curl-retries"  => 120,
          :masterless             => false,
          :options_file           => nil,
          :type                   => 'pe',
          :provision              => true,
          :preserve_hosts         => 'never',
          :root_keys              => false,
          :quiet                  => false,
          :project_root           => File.expand_path(File.join(File.dirname(__FILE__), "../")),
          :xml_dir                => 'junit',
          :xml_file               => 'beaker_junit.xml',
          :xml_stylesheet         => 'junit.xsl',
          :log_dir                => 'log',
          :log_sut_event          => 'sut.log',
          :color                  => true,
          :dry_run                => false,
          :timeout                => 300,
          :fail_mode              => 'slow',
          :accept_all_exit_codes  => false,
          :timesync               => false,
          :disable_iptables       => false,
          :set_env                => true,
          :repo_proxy             => false,
          :package_proxy          => false,
          :add_el_extras          => false,
          :release_apt_repo_url   => "http://apt.puppetlabs.com",
          :release_yum_repo_url   => "http://yum.puppetlabs.com",
          :dev_builds_url         => "http://builds.delivery.puppetlabs.net",
          :epel_url               => "http://mirrors.kernel.org/fedora-epel",
          :epel_arch              => "i386",
          :epel_6_pkg             => "epel-release-6-8.noarch.rpm",
          :epel_5_pkg             => "epel-release-5-4.noarch.rpm",
          :consoleport            => 443,
          :pe_dir                 => '/opt/enterprise/dists',
          :pe_version_file        => 'LATEST',
          :pe_version_file_win    => 'LATEST-win',
          :host_env               => {},
          :ssh_env_file           => '~/.ssh/environment',
          :profile_d_env_file     => '/etc/profile.d/beaker_env.sh',
          :answers                => {
                                     :q_puppet_enterpriseconsole_auth_user_email    => 'admin@example.com',
                                     :q_puppet_enterpriseconsole_auth_password      => '~!@#$%^*-/ aZ',
                                     :q_puppet_enterpriseconsole_smtp_port          => 25,
                                     :q_puppet_enterpriseconsole_smtp_use_tls       => 'n',
                                     :q_verify_packages                             => 'y',
                                     :q_puppetdb_password                           => '~!@#$%^*-/ aZ',
                                     :q_puppetmaster_enterpriseconsole_port         => 443,
                                     :q_puppet_enterpriseconsole_auth_database_name => 'console_auth',
                                     :q_puppet_enterpriseconsole_auth_database_user => 'mYu7hu3r',
                                     :q_puppet_enterpriseconsole_database_name      => 'console',
                                     :q_puppet_enterpriseconsole_database_user      => 'mYc0nS03u3r',
                                     :q_database_root_password                      => '=ZYdjiP3jCwV5eo9s1MBd',
                                     :q_database_root_user                          => 'pe-postgres',
                                     :q_database_export_dir                         => '/tmp',
                                     :q_puppetdb_database_name                      => 'pe-puppetdb',
                                     :q_puppetdb_database_user                      => 'mYpdBu3r',
                                     :q_database_port                               => 5432,
                                     :q_puppetdb_port                               => 8081,
                                     :q_classifier_database_user                    => 'DFGhjlkj',
                                     :q_database_name                               => 'pe-classifier',
                                     :q_classifier_database_password                => '~!@#$%^*-/ aZ',
                                     :q_activity_database_user                      => 'adsfglkj',
                                     :q_activity_database_name                      => 'pe-activity',
                                     :q_activity_database_password                  => '~!@#$%^*-/ aZ',
                                     :q_rbac_database_user                          => 'RbhNBklm',
                                     :q_rbac_database_name                          => 'pe-rbac',
                                     :q_rbac_database_password                      => '~!@#$%^*-/ aZ',
                                     :q_install_update_server                       => 'y',
          },
          :dot_fog                => File.join(ENV['HOME'], '.fog'),
          :ec2_yaml               => 'config/image_templates/ec2.yaml',
          :help                   => false,
          :collect_perf_data      => false,
          :ssh                    => {
                                     :config                => false,
                                     :paranoid              => false,
                                     :timeout               => 300,
                                     :auth_methods          => ["publickey"],
                                     :port                  => 22,
                                     :forward_agent         => true,
                                     :keys                  => ["#{ENV['HOME']}/.ssh/id_rsa"],
                                     :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
          }
        }
```

## Priority of Settings
Order of priority is as follows (from highest to lowest):
  1. Environment variables are given top priority
  1. Host/Config file options
  1. `CONFIG` section of the hosts file
  1. ARGV or Provided Arguments Array
  1. Options file values
  1. Default or Preset values are given the lowest priority

### Examples
  1.  If `BEAKER_PE_DIR` environment variable then any and all `pe_dir` settings in the host file, options file and beaker defaults are ignored
  1.  In this case, the `pe_dir` for `pe-ubuntu-lucid` will be `http://ubuntu/path`, while the `pe_dir` for `pe-centos6` will be `https://CONFIG/path`.
```
HOSTS:
  pe-ubuntu-lucid:
    roles:
      - agent
      - dashboard
      - database
      - master
    vmname : pe-ubuntu-lucid
    platform: ubuntu-10.04-i386
    snapshot : clean-w-keys
    hypervisor : fusion
    pe_dir : http://ubuntu/path
  pe-centos6:
    roles:
      - agent
    vmname : pe-centos6
    platform: el-6-i386
    hypervisor : fusion
    snapshot: clean-w-keys
CONFIG:
  nfs_server: none
  consoleport: 443
  pe_dir: https://CONFIG/path
```
