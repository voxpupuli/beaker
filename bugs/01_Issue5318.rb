# Accepts hash of parsed config file as arg
class Issue5318
  attr_accessor :config, :fail_flag
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    master=""
    agent=""
    usr_home=ENV['HOME']

    @config.each_key do|host|
      @config[host]['roles'].each do|role|
        if /master/ =~ role then        # If the host is puppet master
          master=host
        elsif /agent/ =~ role then      # If the host is puppet agent
          agent=host
        end
      end # /role
    end

		master_run = RemoteExec.new(master)  # get remote exec obj to master
		agent_run = RemoteExec.new(agent)    # get remote exec obj to master
		test_name="Issue5318 - step 1"
		# 1: create site.pp file on Master
		BeginTest.new(master, test_name)
		result = master_run.do_remote('echo notify{\"issue5318 original\":} > /etc/puppetlabs/puppet/manifests/site.pp')
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

		# 2: invoke puppet agent -t
		config_ver_org=""
		test_name="Issue5318 - step 2"
		BeginTest.new(agent, test_name)
		result = agent_run.do_remote("puppet agent --test --server #{master}")
		config_ver_org = $1 if /Applying configuration version \'(\d+)\'/ =~ result.stdout
		puts "ORG VER match #{config_ver_org}"
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

		# 3: modify site.pp on Masster
		test_name="Issue5318 - step 3"
		BeginTest.new(master, test_name)
		result = master_run.do_remote('echo notify{\"issue5318 modified\":} > /etc/puppetlabs/puppet/manifests/site.pp')
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

		# 4: invoke puppet agent -t again
		config_ver_mod=""
		test_name="Issue5318 - step 4"
		BeginTest.new(agent, test_name)
		result = agent_run.do_remote("puppet agent --test --server #{master}")
		config_ver_mod = $1 if /Applying configuration version \'(\d+)\'/ =~ result.stdout
		puts "MOD VER match #{config_ver_mod}"
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

    msg=""
		test_name="Issue5318 - Compare Config Versions on Agent"
		BeginTest.new(agent, test_name)
    if ( config_ver_org == config_ver_mod ) then 
      msg="Agent did not receive updated config"
      @fail_flag+=1
    elsif
      msg="Agent received updated config"
    end
    ChkResult.new(host, test_name, msg, nil, @fail_flag)
  end
end
