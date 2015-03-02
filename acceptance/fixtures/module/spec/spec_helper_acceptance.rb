require 'beaker-rspec'

unless ENV['RS_PROVISION'] == 'no' or ENV['BEAKER_provision'] == 'no'
  # This will install the latest available package on el and deb based
  # systems fail on windows and osx, and install via gem on other *nixes
  foss_opts = {:default_action => 'gem_install'}

  if default.is_pe?; then
    install_pe;
  else
    install_puppet(foss_opts);
  end

  hosts.each do |host|
    unless host.is_pe?
      on host, "/bin/echo '' > #{host.puppet('hiera_config')}"
    end
    on host, "mkdir -p #{host['distmoduledir']}"
  end
end

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    hosts.each do |host|
      on host, "mkdir -p #{host['distmoduledir']}/demo"
      %w(lib manifests metadata.json).each do |file|
        scp_to host, "#{proj_root}/#{file}", "#{host['distmoduledir']}/ntp"
      end
    end
  end
end
