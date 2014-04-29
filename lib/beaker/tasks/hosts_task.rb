require 'yaml'

namespace :beaker do
  namespace :hosts do
    ONE_DAY_IN_SECS = 24 * 60 * 60

    desc "Generate a config for the Latest Hosts"
    task :generate_config_for_latest_hosts  do
       gen_conf_for_latest_hosts
    end

    def gen_conf_for_latest_hosts
      preserved_config_hash = { 'HOSTS' => {} }

      config_hash = YAML.load_file('log/latest/config.yml').to_hash
      nodes = config_hash['HOSTS'].map do |node_label, hash|
        { :node_label => node_label, :platform => hash['platform'] }
      end

      pre_suite_log = File.read('log/latest/pre_suite-run.log')
      nodes.each do |node_info|
        hostname = /^(\w+) \(#{node_info[:node_label]}\)/.match(pre_suite_log)[1]
        fqdn = "#{hostname}.delivery.puppetlabs.net"
        preserved_config_hash['HOSTS'][fqdn] = {
            'roles' => ['agent'],
            'platform' => node_info[:platform],
        }
        preserved_config_hash['HOSTS'][fqdn]['roles'].unshift('master') if node_info[:node_label] =~ /master/
      end
      pp preserved_config_hash

      File.open('log/latest/preserved_config.yaml', 'w') do |config_file|
        YAML.dump(preserved_config_hash, config_file)
      end
    rescue Errno::ENOENT => e
      puts "Couldn't generate log #{e}"
    end


    desc "List preserved Configurations"
    task :list_preserved_configurations, :secs_ago do |t,args|
      list_preserved_configs args.secs_ago
    end
    def list_preserved_configs(secs_ago = ONE_DAY_IN_SECS)
      preserved = {}
      Dir.glob('log/*_*').each do |dir|
        preserved_config_path = "#{dir}/preserved_config.yaml"
        yesterday = Time.now - secs_ago.to_i
        if preserved_config = File.exists?(preserved_config_path)
          directory = File.new(dir)
          if directory.ctime > yesterday
            hosts = []
            preserved_config = YAML.load_file(preserved_config_path).to_hash
            preserved_config['HOSTS'].each do |hostname, values|
              hosts << "#{hostname}: #{values['platform']}, #{values['roles']}"
            end
            preserved[hosts] = directory.to_path
          end
        end
      end
      preserved.map { |k, v| [v, k] }.sort { |a, b| a[0] <=> b[0] }.reverse
    end

    desc "List hosts currently preserved"
    task :list_preserved_hosts, :secs_ago do |t,args|
      args.with_defaults({:secs_ago => ONE_DAY_IN_SECS})
      hosts = Set.new
      Dir.glob('log/**/pre*suite*run.log').each do |log|
        yesterday = Time.now - args.secs_ago.to_i
        File.open(log, 'r') do |file|
          if file.ctime > yesterday
            file.each_line do |line|
              matchdata = /^(\w+) \(.*?\) \d\d:\d\d:\d\d\$/.match(line.encode!('UTF-8', 'UTF-8', :invalid => :replace))
              hosts.add(matchdata[1]) if matchdata
            end
          end
        end
      end
      hosts
    end

    desc "Release hosts"
    task :release_hosts, :hosts,:secs_ago do |t,args|

      secs_ago ||= ONE_DAY_IN_SECS
      hosts ||= list_preserved_hosts(secs_ago)

      require 'beaker'
      vcloud_pooled = Beaker::VcloudPooled.new(hosts.map { |h| { 'vmhostname' => h } },
                                               :logger => Beaker::Logger.new,
                                               :dot_fog => "#{ENV['HOME']}/.fog",
                                               'pooling_api' => 'http://vcloud.delivery.puppetlabs.net',
                                               'datastore' => 'not-used',
                                               'resourcepool' => 'not-used',
                                               'folder' => 'not-used')
      vcloud_pooled.cleanup
    end

    def print_preserved(preserved)
      preserved.each_with_index do |entry, i|
        puts "##{i}: #{entry[0]}"
        entry[1].each { |h| puts "  #{h}" }
      end
    end
  end
end

