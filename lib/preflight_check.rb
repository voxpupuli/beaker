# Place to add small pre-test tasks
#

# What version of Puppet are we installing?
def puppet_version
  version=""
  parent_dir=""
  parent_dir=$1 if /^(\/\w.*)(\/\w.+)/ =~ $work_dir

  File.open("#{parent_dir}/installer/VERSION") do |file|
    while line = file.gets
      if /(\w.*)/ =~ line then
        version=$1
        puts "Found: Puppet Version #{version}"
      end
    end
  end
  return version
end


# clean up on each host
def clean_hosts(config)
  test_name="Clean Hosts"
  config["HOSTS"].each_key do|host|
    BeginTest.new(host, test_name)
    runner = RemoteExec.new(host)
    result = runner.do_remote("rpm -qa | grep puppet | xargs rpm -e; rpm -qa | grep pe- | xargs rpm -e; rm -rf puppet-enterprise*; rm -rf /etc/puppetlabs")
    ChkResult.new(host, test_name, result.stdout, result.stderr, result.exit_code)
  end
end
