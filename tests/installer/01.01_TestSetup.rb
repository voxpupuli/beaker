# Pre Test Setup stage
# SCP installer to host, Untar Installer

version=config["CONFIG"]["puppetver"]

hosts.each do |host|
  # SCP install file to host
  test_name="Pre Test Setup -- SCP install package to hosts"
  dist_tar = case config["HOSTS"][host]['platform']
    when /RHEL5-64/; "puppet-enterprise-#{version}-rhel-5-x86_64.tar"
    when /CENT5-64/; "puppet-enterprise-#{version}-centos-5-x86_64.tar"
    else fail "Unknown platform: #{config["HOSTS"][host]['platform']}"
    end
  BeginTest.new(host, test_name)
  scper = ScpFile.new(host)
  result = scper.do_scp("#{$work_dir}/tarballs/#{dist_tar}", "/root")
  @fail_flag+=result.exit_code
  result = scper.do_scp("#{$work_dir}/tarballs/answers.tar", "/root")
  @fail_flag+=result.exit_code
  result.log(test_name)

  test_name="Pre Test Setup -- Untar install package on hosts"
  # Untar install packges on host
  BeginTest.new(host, test_name)
  runner = RemoteExec.new(host)
  result = runner.do_remote("tar xf #{dist_tar}")
  @fail_flag+=result.exit_code
  result.log(test_name)
end
