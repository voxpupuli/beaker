module Beaker
  module Options
    #A set of functions representing the environment variables and preset argument values to be incorporated
    #into the Beaker options Object.
    module Presets

      # This is a constant that describes the variables we want to collect
      # from the environment. The keys correspond to the keys in
      # `self.presets` (flattened) The values are an optional array of
      # environment variable names to look for. The array structure allows
      # us to define multiple environment variables for the same
      # configuration value. They are checked in the order they are arrayed
      # so that preferred and "fallback" values work as expected.
      ENVIRONMENT_SPEC = {
        :home                 => 'HOME',
        :project              => ['BEAKER_PROJECT', 'BEAKER_project'],
        :department           => ['BEAKER_DEPARTMENT', 'BEAKER_department'],
        :jenkins_build_url    => ['BEAKER_BUILD_URL', 'BUILD_URL'],
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

      # Takes an environment_spec and searches the processes environment variables accordingly
      #
      # @param [Hash{Symbol=>Array,String}] env_var_spec  the spec of what env vars to search for
      #
      # @return [Hash] Found environment values
      def self.collect_env_vars( env_var_spec )
        env_var_spec.inject({:answers => {}}) do |memo, key_value|
          key, value = key_value[0], key_value[1]

          set_env_var = Array(value).detect {|possible_variable| ENV[possible_variable] }
          memo[key] = ENV[set_env_var] if set_env_var

          memo
        end
      end

      # Takes a hash where the values are found environment configuration values
      # and munges them to appropriate Beaker configuration values
      #
      # @param [Hash{Symbol=>String}] found_env_vars  Environment variables to munge
      #
      # @return [Hash] Environment config values munged appropriately
      def self.munge_found_env_vars( found_env_vars )
        found_env_vars[:answers] ||= {}
        found_env_vars.each_pair do |key,value|
          found_env_vars[:answers][key] = value if key.to_s =~ /q_/
        end
        found_env_vars[:consoleport] &&= found_env_vars[:consoleport].to_i
        if found_env_vars[:is_pe] == 'true' || found_env_vars[:is_pe] == 'yes'
          found_env_vars[:type] = 'pe'
        elsif found_env_vars[:is_pe] == 'false' || found_env_vars[:is_pe] == 'no'
          found_env_vars[:type] = 'foss'
        else
          found_env_vars[:type] = nil
        end
        found_env_vars[:pe_version_file_win] = found_env_vars[:pe_version_file]
        found_env_vars[:answers].delete_if {|key, value| value.nil? or value.empty? }
        found_env_vars.delete_if {|key, value| value.nil? or value.empty? }
      end


      # Generates an OptionsHash of the environment variables of interest to Beaker
      #
      # @return [OptionsHash] The supported environment variables in an OptionsHash,
      #                       empty or nil environment variables are removed from the OptionsHash
      def self.env_vars
        h = Beaker::Options::OptionsHash.new

        found = munge_found_env_vars( collect_env_vars( ENVIRONMENT_SPEC ))

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
          :"master-start-curl-retries" => 120,
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
          :collect_perf_data   => false,
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
