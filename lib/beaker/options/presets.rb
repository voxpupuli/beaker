module Beaker
  module Options
    # A class representing the environment variables and preset argument values to be incorporated
    # into the Beaker options Object.
    class Presets
      # This is a constant that describes the variables we want to collect
      # from the environment. The keys correspond to the keys in
      # `presets` (flattened) The values are an optional array of
      # environment variable names to look for. The array structure allows
      # us to define multiple environment variables for the same
      # configuration value. They are checked in the order they are arrayed
      # so that preferred and "fallback" values work as expected.
      #
      # 'JOB_NAME' and 'BUILD_URL' envs are supplied by Jenkins
      # https://wiki.jenkins-ci.org/display/JENKINS/Building+a+software+project
      ENVIRONMENT_SPEC = {
        :home => 'HOME',
        :project => %w[BEAKER_PROJECT BEAKER_project JOB_NAME],
        :department => %w[BEAKER_DEPARTMENT BEAKER_department],
        :jenkins_build_url => %w[BEAKER_BUILD_URL BUILD_URL],
        :created_by => ['BEAKER_CREATED_BY'],
        :consoleport => %w[BEAKER_CONSOLEPORT consoleport],
        :is_pe => %w[BEAKER_IS_PE IS_PE],
        :pe_dir => %w[BEAKER_PE_DIR pe_dist_dir],
        :puppet_agent_version => ['BEAKER_PUPPET_AGENT_VERSION'],
        :puppet_agent_sha => ['BEAKER_PUPPET_AGENT_SHA'],
        :puppet_collection => ['BEAKER_PUPPET_COLLECTION'],
        :pe_version_file => %w[BEAKER_PE_VERSION_FILE pe_version_file],
        :pe_ver => %w[BEAKER_PE_VER pe_ver],
        :forge_host => %w[BEAKER_FORGE_HOST forge_host],
        :package_proxy => ['BEAKER_PACKAGE_PROXY'],
        :release_apt_repo_url => %w[BEAKER_RELEASE_APT_REPO RELEASE_APT_REPO],
        :release_yum_repo_url => %w[BEAKER_RELEASE_YUM_REPO RELEASE_YUM_REPO],
        :dev_builds_url => %w[BEAKER_DEV_BUILDS_URL DEV_BUILDS_URL],
        :vbguest_plugin => %w[BEAKER_VB_GUEST_PLUGIN BEAKER_vb_guest_plugin],
        :test_tag_and => %w[BEAKER_TAG BEAKER_TEST_TAG_AND],
        :test_tag_or => ['BEAKER_TEST_TAG_OR'],
        :test_tag_exclude => %w[BEAKER_EXCLUDE_TAG BEAKER_TEST_TAG_EXCLUDE],
        :run_in_parallel => ['BEAKER_RUN_IN_PARALLEL'],
      }

      # Select all environment variables whose name matches provided regex
      # @return [Hash] Hash of environment variables
      def select_env_by_regex regex
        envs = Beaker::Options::OptionsHash.new
        ENV.each_pair do |k, v|
          envs[k] = v if /#{regex}/.match?(k.to_s)
        end
        envs
      end

      # Takes an environment_spec and searches the processes environment variables accordingly
      #
      # @param [Hash{Symbol=>Array,String}] env_var_spec  the spec of what env vars to search for
      #
      # @return [Hash] Found environment values
      def collect_env_vars(env_var_spec)
        env_var_spec.each_with_object({}) do |key_value, memo|
          key, value = key_value[0], key_value[1]

          set_env_var = Array(value).detect { |possible_variable| ENV.fetch(possible_variable, nil) }
          memo[key] = ENV.fetch(set_env_var, nil) if set_env_var
        end
      end

      # Takes a hash where the values are found environment configuration values
      # and formats them to appropriate Beaker configuration values
      #
      # @param [Hash{Symbol=>String}] found_env_vars  Environment variables to munge
      #
      # @return [Hash] Environment config values formatted appropriately
      def format_found_env_vars(found_env_vars)
        found_env_vars[:consoleport] &&= found_env_vars[:consoleport].to_i

        if found_env_vars[:is_pe]
          is_pe_val = found_env_vars[:is_pe]
          type = case is_pe_val
                 when /yes|true/ then 'pe'
                 when /no|false/ then 'foss'
                 else
                   raise "Invalid value for one of #{ENVIRONMENT_SPEC[:is_pe].join(' ,')}: #{is_pe_val}"
                 end

          found_env_vars[:type] = type
        end
        found_env_vars[:run_in_parallel] = found_env_vars[:run_in_parallel].split(',') if found_env_vars[:run_in_parallel]

        found_env_vars[:pe_version_file_win] = found_env_vars[:pe_version_file]
        found_env_vars
      end

      # Generates an OptionsHash of the environment variables of interest to Beaker
      #
      # @return [OptionsHash] The supported environment variables in an OptionsHash,
      #                       empty or nil environment variables are removed from the OptionsHash
      def calculate_env_vars
        found = Beaker::Options::OptionsHash.new
        found = found.merge(format_found_env_vars(collect_env_vars(ENVIRONMENT_SPEC)))
        found[:answers] = select_env_by_regex('\\Aq_')

        found.delete_if { |_key, value| value.nil? or value.empty? }
        found
      end

      # Return an OptionsHash of environment variables used in this run of Beaker
      #
      # @return [OptionsHash] The supported environment variables in an OptionsHash,
      #                       empty or nil environment variables are removed from the OptionsHash
      def env_vars
        @env ||= calculate_env_vars
      end

      # Generates an OptionsHash of preset values for arguments supported by Beaker
      #
      # @return [OptionsHash] The supported arguments in an OptionsHash
      def presets
        h = Beaker::Options::OptionsHash.new
        h.merge({
                  :project => 'Beaker',
                  :department => 'unknown',
                  :created_by => ENV['USER'] || ENV['USERNAME'] || 'unknown',
                  :host_tags => {},
                  :openstack_api_key => ENV.fetch('OS_PASSWORD', nil),
                  :openstack_username => ENV.fetch('OS_USERNAME', nil),
                  :openstack_auth_url => "#{ENV.fetch('OS_AUTH_URL', nil)}/tokens",
                  :openstack_tenant => ENV.fetch('OS_TENANT_NAME', nil),
                  :openstack_keyname => ENV.fetch('OS_KEYNAME', nil),
                  :openstack_network => ENV.fetch('OS_NETWORK', nil),
                  :openstack_region => ENV.fetch('OS_REGION', nil),
                  :openstack_volume_support => ENV['OS_VOLUME_SUPPORT'] || true,
                  :jenkins_build_url => nil,
                  :validate => true,
                  :configure => true,
                  :log_level => 'info',
                  :trace_limit => 10,
                  :"master-start-curl-retries" => 120,
                  :masterless => false,
                  :options_file => nil,
                  :type => 'pe',
                  :provision => true,
                  :preserve_hosts => 'never',
                  :root_keys => false,
                  :quiet => false,
                  :project_root => File.expand_path(File.join(__dir__, "../")),
                  :xml_dir => 'junit',
                  :xml_file => 'beaker_junit.xml',
                  :xml_time => 'beaker_times.xml',
                  :xml_time_enabled => false,
                  :xml_stylesheet => 'junit.xsl',
                  :default_log_prefix => 'beaker_logs',
                  :log_dir => 'log',
                  :log_sut_event => 'sut.log',
                  :color => true,
                  :dry_run => false,
                  :test_tag_and => '',
                  :test_tag_or => '',
                  :test_tag_exclude => '',
                  :timeout => 900, # 15 minutes
                  :fail_mode => 'slow',
                  :test_results_file => '',
                  :accept_all_exit_codes => false,
                  :timesync => false,
                  :set_env => true,
                  :disable_updates => true,
                  :repo_proxy => false,
                  :package_proxy => false,
                  :add_el_extras => false,
                  :consoleport => 443,
                  :pe_dir => '/opt/enterprise/dists',
                  :pe_version_file => 'LATEST',
                  :pe_version_file_win => 'LATEST-win',
                  :host_env => {},
                  :host_name_prefix => nil,
                  :ssh_env_file => '~/.ssh/environment',
                  :profile_d_env_file => '/etc/profile.d/beaker_env.sh',
                  :dot_fog => File.join(ENV.fetch('HOME', nil), '.fog'),
                  :ec2_yaml => 'config/image_templates/ec2.yaml',
                  :help => false,
                  :collect_perf_data => 'none',
                  :puppetdb_port_ssl => 8081,
                  :puppetdb_port_nonssl => 8080,
                  :puppetserver_port => 8140,
                  :nodeclassifier_port => 4433,
                  :cache_files_locally => false,
                  :aws_keyname_modifier => rand(10**10).to_s.rjust(10, '0'), # 10 digit random number string
                  :run_in_parallel => [],
                  :use_fog_credentials => true,
                  :ssh => {
                    :config => false,
                    :verify_host_key => :never,
                    :auth_methods => ["publickey"],
                    :port => 22,
                    :forward_agent => true,
                    :keys => ["#{ENV.fetch('HOME', nil)}/.ssh/id_rsa"],
                    :user_known_hosts_file => "#{ENV.fetch('HOME', nil)}/.ssh/known_hosts",
                    :keepalive => true,
                  },
                })
      end
    end
  end
end
