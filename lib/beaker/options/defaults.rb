module Beaker
  module Options
    module Defaults

      def self.env_vars
        h = Beaker::Options::OptionsHash.new
        h.merge({
          :consoleport => ENV['consoleport'] ? ENV['consoleport'].to_i : nil,
          :type => ENV['IS_PE'] ? 'pe' : nil,
          :pe_dir => ENV['pe_dist_dir'],
          :pe_version_file => ENV['pe_version_file'],
          :pe_version_file_win => ENV['pe_version_file'],
        }.delete_if {|key, value| value.nil? or value.empty? })
      end

      def self.defaults
        h = Beaker::Options::OptionsHash.new
        h.merge({
          :hosts_file => 'sample.cfg',
          :options_file => nil,
          :type => 'pe',
          :helper => [],
          :load_path => [],
          :tests => [],
          :pre_suite => [],
          :post_suite => [],
          :provision => true,
          :preserve_hosts => false,
          :root_keys => false,
          :install => [],
          :modules => [],
          :quiet => false,
          :xml => false,
          :color => true,
          :debug => false,
          :dry_run => false,
          :fail_mode => nil,
          :timesync => false,
          :repo_proxy => false,
          :add_el_extras => false,
          :consoleport => 443,
          :pe_dir => '/opt/enterprise/dists',
          :pe_version_file => 'LATEST',
          :pe_version_file_win => 'LATEST-win',
          :dot_fog => File.join(ENV['HOME'], '.fog'),
          :ec2_yaml => 'config/image_templates/ec2.yaml',
        })
      end

      def self.ssh_defaults
        h = Beaker::Options::OptionsHash.new
        h.merge({:ssh => {
          :config                => false,
          :paranoid              => false,
          :timeout               => 300,
          :auth_methods          => ["publickey"],
          :port                  => 22,
          :forward_agent         => true,
          :keys                  => ["#{ENV['HOME']}/.ssh/id_rsa"],
          :user_known_hosts_file => "#{ENV['HOME']}/.ssh/known_hosts",
        }})
      end

    end
  end
end
