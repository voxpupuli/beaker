module Beaker
  module Options
    #A set of functions representing the environment variables and preset argument values to be incorporated
    #into the Beaker options Object.
    module Presets
      ENVIRONMENT = {
        :home                 => 'HOME',
        :project              => ['BEAKER_PROJECT', 'BEAKER_project'],
        :department           => ['BEAKER_DEPARTMENT', 'BEAKER_department'],
        :jenkins_build_url    => ['BEAKER_BUILD_URL', 'BUILD_URL'],
        :consoleport          => ['BEAKER_CONSOLEPORT', 'consoleport'],
        :type                 => ['BEAKER_IS_PE', 'IS_PE'],
        :pe_dir               => ['BEAKER_PE_DIR', 'pe_dist_dir'],
        :pe_version_file      => ['BEAKER_PE_VERSION_FILE', 'pe_version_file'],
        :pe_ver               => ['BEAKER_PE_VER', 'pe_ver'],
        :forge_host           => ['BEAKER_FORGE_HOST', 'forge_host'],
        :package_proxy        => ['BEAKER_PACKAGE_PROXY'],
        :release_apt_repo_url => ['BEAKER_RELEASE_APT_REPO', 'RELEASE_APT_REPO'],
        :release_yum_repo_url => ['BEAKER_RELEASE_YUM_REPO', 'RELEASE_YUM_REPO'],
        :dev_builds_url       => ['BEAKER_DEV_BUILDS_URL', 'DEV_BUILDS_URL'],

        :q_puppet_enterpriseconsole_auth_user_email => 'q_puppet_enterpriseconsole_auth_user_email',
        :q_puppet_enterpriseconsole_auth_password   => 'q_puppet_enterpriseconsole_auth_password',
        :q_puppet_enterpriseconsole_smtp_host       => 'q_puppet_enterpriseconsole_smtp_host',
        :q_puppet_enterpriseconsole_smtp_port       => 'q_puppet_enterpriseconsole_smtp_port',
        :q_puppet_enterpriseconsole_smtp_username   => 'q_puppet_enterpriseconsole_smtp_username',
        :q_puppet_enterpriseconsole_smtp_password   => 'q_puppet_enterpriseconsole_smtp_password',
        :q_puppet_enterpriseconsole_smtp_use_tls    => 'q_puppet_enterpriseconsole_smtp_use_tls',
        :q_verify_packages                          => 'q_verify_packages',
        :q_puppetdb_password                        => 'q_puppetdb_password',
      }

      def self.detect_environment_vars
        ENVIRONMENT.inject({:answers => {}}) {|memo, key_value|
          key, value = key_value[0], key_value[1]
          if key.to_s =~ /^q_/
            set_env_var = Array(value).detect {|possible_variable| ENV[possible_variable] }
            memo[:answers][key] = ENV[set_env_var] if set_env_var
          else
            set_env_var = Array(value).detect {|possible_variable| ENV[possible_variable] }
            memo[key] = ENV[set_env_var] if set_env_var
          end
          memo
        }
      end


      # Generates an OptionsHash of the environment variables of interest to Beaker
      #
      # @return [OptionsHash] The supported environment variables in an OptionsHash,
      #                       empty or nil environment variables are removed from the OptionsHash
      def self.env_vars
        h = Beaker::Options::OptionsHash.new

        found = detect_environment_vars

        found[:consoleport] &&= found[:consoleport].to_i
        found[:type] &&= 'pe'
        found[:pe_version_file_win] = found[:pe_version_file]
        found[:answers].delete_if {|key, value| value.nil? or value.empty? }
        found.delete_if {|key, value| value.nil? or value.empty? }
        #found[:answers] ||= {}

        return h.merge( found )
      end

      # Generates an OptionsHash of preset values for arguments supported by Beaker
      #
      # @return [OptionsHash] The supported arguments in an OptionsHash
      def self.presets
        h = Beaker::Options::OptionsHash.new
        h.merge({
          :project              => 'Beaker',
          :department           => ENV['USER'] || ENV['USERNAME'] || 'unknown',
          :validate             => true,
          :jenkins_build_url    => nil,
          :forge_host           => 'vulcan-acceptance.delivery.puppetlabs.net',
          :log_level            => 'verbose',
          :trace_limit          => 10,
          :"master-start-curl-retries" => 0,
          :options_file         => nil,
          :type                 => 'pe',
          :provision            => true,
          :preserve_hosts       => 'never',
          :root_keys            => false,
          :quiet                => false,
          :project_root         => File.expand_path(File.join(File.dirname(__FILE__), "../")),
          :xml_dir              => 'junit',
          :xml_file             => 'beaker_junit.xml',
          :xml_stylesheet       => 'junit.xsl',
          :log_dir              => 'log',
          :color                => true,
          :dry_run              => false,
          :timeout              => 300,
          :fail_mode            => 'slow',
          :timesync             => false,
          :repo_proxy           => false,
          :package_proxy        => false,
          :add_el_extras        => false,
          :release_apt_repo_url => "http://apt.puppetlabs.com",
          :release_yum_repo_url => "http://yum.puppetlabs.com",
          :dev_builds_url       => "http://builds.puppetlabs.lan",
          :consoleport          => 443,
          :pe_dir               => '/opt/enterprise/dists',
          :pe_version_file      => 'LATEST',
          :pe_version_file_win  => 'LATEST-win',
          :answers              => {
                                     :q_puppet_enterpriseconsole_auth_user_email => 'admin@example.com',
                                     :q_puppet_enterpriseconsole_auth_password   => '~!@#$%^*-/ aZ',
                                     :q_puppet_enterpriseconsole_smtp_port       => 25,
                                     :q_puppet_enterpriseconsole_smtp_use_tls    => 'n',
                                     :q_verify_packages                          => 'y',
                                     :q_puppetdb_password                        => '~!@#$%^*-/ aZ'
          },
          :dot_fog              => File.join(ENV['HOME'], '.fog'),
          :ec2_yaml             => 'config/image_templates/ec2.yaml',
          :help                 => false,
          :ssh                  => {
                                     :config                => false,
                                     :paranoid              => false,
                                     :timeout               => 300,
                                     :auth_methods          => ["publickey"],
                                     :port                  => 22,
                                     :forward_agent         => true,
                                     :keys                  => ["#{ENV['HOME']}/.ssh/id_rsa"],
                                     :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
          }
        })
      end

    end
  end
end
