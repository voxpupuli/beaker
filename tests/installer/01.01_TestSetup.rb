# Pre Test Setup stage
# SCP installer to host, Untar Installer


hosts.each do |host|
  step "Pre Test Setup -- SCP install package to hosts"
  version = host["puppetver"]
  dist_tar = case host['platform']
    when /RHEL5-64/; "puppet-enterprise-#{version}-rhel-5-x86_64.tar"
    when /CENT5-64/; "puppet-enterprise-#{version}-centos-5-x86_64.tar"
    else fail "Unknown platform: #{host['platform']}"
    end
  scp_to host, "#{$work_dir}/tarballs/#{dist_tar}", "/root"
  scp_to host, "#{$work_dir}/tarballs/answers.tar", "/root"

  step "Pre Test Setup -- Untar install package on hosts"
  on host,"tar xf #{dist_tar}"
end
