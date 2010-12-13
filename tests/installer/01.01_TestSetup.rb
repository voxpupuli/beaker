# Pre Test Setup stage
# SCP installer to host, Untar Installer
# Accepts hash of parsed config file as arg
class TestSetup
  attr_accessor :config, :fail_flag 
  def initialize(config)
    self.config    = config
    self.fail_flag = 0

    host=""
    dist_tar=""
    version=config["CONFIG"]["puppetver"]

    test_name="Pre Test Setup -- SCP install package to hosts"
    # SCP install file to each host
    @config["HOSTS"].each_key do|host|
      dist_tar="puppet-enterprise-#{version}-rhel-5-x86_64.tar" if  ( /RHEL5-64/ =~ @config["HOSTS"][host]['platform'] )
      dist_tar="puppet-enterprise-#{version}-centos-5-x86_64.tar" if ( /CENT5-64/ =~ @config["HOSTS"][host]['platform'] )
      BeginTest.new(host, test_name)
      scper = ScpFile.new(host)
      result = scper.do_scp("#{$work_dir}/tarballs/#{dist_tar}", "/root")
      @fail_flag+=result.exit_code
      result = scper.do_scp("#{$work_dir}/tarballs/answers.tar", "/root")
      @fail_flag+=result.exit_code
      result.log(test_name)
    end

    test_name="Pre Test Setup -- Untar install package on hosts"

    # Untar install packges on each host
    @config["HOSTS"].each_key do|host|
      BeginTest.new(host, test_name)
      runner = RemoteExec.new(host)
      result = runner.do_remote("tar xf #{dist_tar}")
      @fail_flag+=result.exit_code
      result.log(test_name)
    end

  end
end
