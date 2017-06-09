test_name 'use the init subcommand' do

  SubcommandUtil = Beaker::Subcommands::SubcommandUtil
  def delete_root_folder_contents
    on default, 'rm -rf /root/* /root/.beaker'
  end

  step 'ensure beaker init requires hosts flag' do
    result = on(default, 'beaker init')
    assert_match(/No value(.+)--hosts/, result.raw_output)
  end

  step 'ensure beaker init writes YAML configuration files to disk' do
    delete_root_folder_contents
    on(default, 'beaker init --hosts centos6-64')
    subcommand_options = on(default, "cat #{SubcommandUtil::SUBCOMMAND_OPTIONS}").stdout
    subcommand_state = on(default, "cat #{SubcommandUtil::SUBCOMMAND_STATE}").stdout
    parsed_options = YAML.parse(subcommand_options).to_ruby
    assert(parsed_options["HOSTS"].count == 1)
    assert(parsed_options.class == Hash)
    assert(YAML.parse(subcommand_state).to_ruby.class == Hash)
  end

  step 'ensure beaker init saves beaker-run arguments to the subcommand_options.yaml' do
    delete_root_folder_contents
    on(default, 'beaker init --log-level verbose --hosts centos6-64')
    subcommand_options = on(default, "cat #{SubcommandUtil::SUBCOMMAND_OPTIONS}").stdout
    hash = YAML.parse(subcommand_options).to_ruby
    assert_equal('verbose', hash['log_level'])
  end
end
