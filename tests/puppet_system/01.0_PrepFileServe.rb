# Accepts hash of parsed config file as arg
class PrepFileServe
  attr_accessor :config, :fail_flag
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    @fail_flag=0

    master="foo"
    file_count=10  # Default files to create

    @config["HOSTS"].each_key do|host|
      @config["HOSTS"][host]['roles'].each do |role|
        #master=host if /master/ =~ role  # Host is a puppet master
        if /master/ =~ role then
          master=host
        end
      end
    end

    # parse config file for file count
    @config["CONFIG"].each_key do|cfg|
      if cfg =~ /filecount/ then							#if the config hash key is filecount
        file_count = @config["CONFIG"][cfg]		#then filecount value is num of files to create
      end
    end
    puts "Creating #{file_count} files"

    initpp="/etc/puppetlabs/puppet/modules/puppet_system_test/manifests"
    # Write new class to init.pp
    prep_initpp(master, "file", "#{initpp}")

		# Create test files/dir on Puppet Master
		test_name="Prep For File and Dir servering tests"
		master_run = RemoteExec.new(master)  # get remote exec obj to master
    BeginTest.new(master, test_name)
    result = master_run.do_remote("/ptest/bin/make_files.sh /etc/puppetlabs/puppet/modules/puppet_system_test/files #{file_count}")
    ChkResult.new(master, test_name, result.stdout, result.stderr, result.exit_code)
    @fail_flag+=result.exit_code

  end
end
