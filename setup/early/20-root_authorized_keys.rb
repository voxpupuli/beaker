# For more info: http://projects.puppetlabs.com/issues/11618

test_name "Sync root authorized_keys from github"

step "Sync root authorized_keys from github"

script = "https://raw.github.com/puppetlabs/puppetlabs-sshkeys/master/templates/scripts/manage_root_authorized_keys"
setup_root_authorized_keys = "curl -o - #{script} | bash"

# JJM This step runs on every system under test right now.  We're anticipating
# issues on Windows and maybe Solaris.  We will likely need to filter this step
# but we're deliberately taking the approach of "assume it will work, fix it
# when reality dictates otherwise"
if not options[:no_root_keys] then
  hosts.each do |host|
    on host, setup_root_authorized_keys
  end
end
