# It's probably better if you just don't read this file

require 'erb'
require 'yaml'

pe_test_packages = YAML.load_file('config/test_packages.yml')[:packages]

pe_dist_dir = "/tmp/puppet-enterprise-#{config['pe_ver']}-#{dashboard['platform']}"

install_test_packages_template = %Q{
#!/bin/bash
cd <%= pe_dist_dir %>
source puppet-enterprise-installer
prepare_platform
<% for package in pe_test_packages %>
enqueue_package '<%= package %>'
<% end %>
install_queued_packages
}

File.open('tmp/install_test_packages.sh', 'w') do |sh|
  sh.puts ERB.new(install_test_packages_template).result(binding)
end

scp_to dashboard, 'tmp/install_test_packages.sh', '/tmp'
on dashboard, 'bash /tmp/install_test_packages.sh'
