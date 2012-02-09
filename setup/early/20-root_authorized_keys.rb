# For more info: http://projects.puppetlabs.com/issues/11618
test_name "Sync root authorized_keys from github"

# JJM This step runs on every system under test right now.  We're anticipating
# issues on Windows and maybe Solaris.  We will likely need to filter this step
# but we're deliberately taking the approach of "assume it will work, fix it
# when reality dictates otherwise"
if options[:root_keys] then
  script = "https://raw.github.com/puppetlabs/puppetlabs-sshkeys/master/templates/scripts/manage_root_authorized_keys"
  setup_root_authorized_keys = "curl -o - #{script} | bash"
  step "Sync root authorized_keys from github"
  hosts.each do |host|
    # Allow all exit code, as this operation is unlikely to cause problems if it fails.
    on(host, setup_root_authorized_keys, :acceptable_exit_codes => (0..255))
  end
else
  skip_test "Not syncing root authorized_keys from github"  
end
