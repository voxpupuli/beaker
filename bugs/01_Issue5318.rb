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
    fail_flag=0


  @config.each_key do|host|
    @config[host]['roles'].each do|role|
      if /master/ =~ role then        # If the host is puppet master
        master=host
      elsif /agent/ =~ role then      # If the host is puppet agent
        agent=host
      end
    end # /role
  end

test_name="Issue5318"
# 1: create site.pp file on Master
BeginTest.new(master, test_name)
runner = RemoteExec.new(master)
result = runner.do_remote('echo notify{\"issue5318 original\":} > /etc/puppetlabs/puppet/manifests/site.pp')
@fail_flag+=result.exit_code
ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

# 2: invoke puppet agent -t
applied_config_ver=""
BeginTest.new(agent, test_name)
runner = RemoteExec.new(agent)
result = runner.do_remote("puppet agent --test --server #{master}")
puts "VER match #{applied_config_ver}"
applied_config_ver = $1 if /Applying configuration version \'(\d+)\'/ =~ result.stdout

@fail_flag+=result.exit_code
ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

# 3: modify site.pp on Masster
BeginTest.new(master, test_name)
runner = RemoteExec.new(master)
result = runner.do_remote('echo notify{\"issue5318 modified\":} > /etc/puppetlabs/puppet/manifests/site.pp')
@fail_flag+=result.exit_code
ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

# 4: invoke puppet agent -t again
BeginTest.new(agent, test_name)
runner = RemoteExec.new(agent)
result = runner.do_remote("puppet agent --test --server #{master}")
@fail_flag+=result.exit_code
ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)

end
end


