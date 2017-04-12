test_name 'use the init subcommand' do

  SubcommandUtil = Beaker::Subcommands::SubcommandUtil

  def delete_root_folder_contents
    on default, 'rm -rf /root/* /root/.beaker'
    on default, 'mkdir -p /root/.ssh/'
    scp_to default, "#{ENV['HOME']}/.ssh/id_rsa-acceptance", "/root/.ssh/id_rsa"
  end

  step 'ensure beaker init writes YAML configuration files to disk' do
    delete_root_folder_contents
    on(default, 'beaker init')
    subcommand_options = on(default, "cat #{SubcommandUtil::SUBCOMMAND_OPTIONS}").stdout
    subcommand_state = on(default, "cat #{SubcommandUtil::SUBCOMMAND_STATE}").stdout
    assert(YAML.parse(subcommand_options).to_ruby.class == Hash)
    assert(YAML.parse(subcommand_state).to_ruby.class == Hash)
  end

  step 'ensure beaker init saves beaker-run arguments to the subcommand_options.yaml' do
    delete_root_folder_contents
    on(default, 'beaker init --log-level verbose')
    subcommand_options = on(default, "cat #{SubcommandUtil::SUBCOMMAND_OPTIONS}").stdout
    hash = YAML.parse(subcommand_options).to_ruby
    assert_equal('verbose', hash['log_level'])
  end
end
