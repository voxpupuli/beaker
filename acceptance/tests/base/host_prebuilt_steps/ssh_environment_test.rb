test_name "confirm host prebuilt steps behave correctly" do

  confine_block :except, :platform => /f5|windows/ do
    step "confirm ssh environment file existence" do
      hosts.each do |host|
        assert(host.file_exist?(host[:ssh_env_file]))
      end
    end

    step "confirm PATH env variable is set in the ssh environment file" do
      hosts.each do |host|
        assert(0 == on(host, "grep \"PATH\" #{host[:ssh_env_file]}").exit_code)
      end
    end
  end

  confine_block :to, :platform => /solaris-10/ do
    step "confirm /opt/csw/bin has been added to the path" do
      hosts.each do |host|
        assert(0 == on(host, "grep \"/opt/csw/bin\" #{host[:ssh_env_file]}").exit_code)
      end
    end
  end

  confine_block :to, :platform => /openbsd/ do
    step "confirm PKG_PATH is set in the ssh environment file" do
      hosts.each do |host|
        assert(0 == on(host, "grep \"PKG_PATH\" #{host[:ssh_env_file]}").exit_code)
      end
    end
  end
end