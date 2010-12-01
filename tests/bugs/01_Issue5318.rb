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

    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        if /master/ =~ role then         # If the host is puppet master
          master=host
        elsif /agent/ =~ role then       # If the host is puppet agent
          agent=host
        end
      end
    end

		master_run = RemoteExec.new(master)  # get remote exec obj to master
		agent_run = RemoteExec.new(agent)    # get remote exec obj to agent

    # 0: Query master for filetimeout value
    filetimeout=0
		test_name="Issue5318 - query Puppet master for filetimeout value"
		BeginTest.new(master, test_name)
		result = master_run.do_remote("puppet --configprint all | grep filetimeout")
    if ( result.exit_code == 0 ) then
		  filetimeout = $1 if /filetimeout \= \'(\d+)\'/ =~ result.stdout
      puts "Master reported file timeout value of: #{filetimeout}"
    else 
      puts "Master file timeout value not reported!" 
    end
    ChkResult.new(master, test_name, result.stdout, result.stderr, result.exit_code)

		# 1: Add notify to site.pp file on Master
		test_name="Issue5318 - modify(1/2) site.pp file on Master"
		BeginTest.new(master, test_name)
		result = master_run.do_remote('echo notify{\"issue5318 original\":} >> /etc/puppetlabs/puppet/manifests/site.pp')
    ChkResult.new(master, test_name, result.stdout, result.stderr, result.exit_code)

		# 2: invoke puppet agent -t
		config_ver_org=""
		test_name="Issue5318 - invoke puppet agent -t"
		BeginTest.new(agent, test_name)
		result = agent_run.do_remote("puppet agent --test --server #{master}")
		config_ver_org = $1 if /Applying configuration version \'(\d+)\'/ =~ result.stdout
    ChkResult.new(agent, test_name, result.stdout, result.stderr, result.exit_code)

		# 3: 2nd modify site.pp on Masster
		test_name="Issue5318 - modify(2/2) site.pp on Master"
		BeginTest.new(master, test_name)
		result = master_run.do_remote('echo notify{\"issue5318 modified\":} >> /etc/puppetlabs/puppet/manifests/site.pp')
    ChkResult.new(master, test_name, result.stdout, result.stderr, result.exit_code)

    # sleep for filetimeout reported via master, plus 2 secs
    filetimeout+=2
    sleep filetimeout

		# 4: invoke puppet agent -t again
		config_ver_mod=""
		test_name="Issue5318 - step 4"
		BeginTest.new(agent, test_name)
		result = agent_run.do_remote("puppet agent --test --server #{master}")
		config_ver_mod = $1 if /Applying configuration version \'(\d+)\'/ =~ result.stdout
    ChkResult.new(agent, test_name, result.stdout, result.stderr, result.exit_code)

    # 5: comapre the results from steps 2 and 4
    msg=""
		test_name="Issue5318 - Compare Config Versions on Agent"
		BeginTest.new(agent, test_name)
    if ( config_ver_org == config_ver_mod ) then 
      msg="Agent did not receive updated config: ORG #{config_ver_org} MOD #{config_ver_mod}"
      @fail_flag+=1
    elsif
      msg="Agent received updated config: ORG #{config_ver_org} MOD #{config_ver_mod}"
    end
    ChkResult.new(host, test_name, msg, nil, @fail_flag)
  end
end
