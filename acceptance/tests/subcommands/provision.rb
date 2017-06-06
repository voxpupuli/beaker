test_name 'use the provision subcommand' do

  SubcommandUtil = Beaker::Subcommands::SubcommandUtil

  def delete_root_folder_contents
    on default, 'rm -rf /root/* /root/.beaker'
  end

  step 'run beaker init and provision' do
    delete_root_folder_contents
    result = on(default, 'beaker provision --hosts centos6-64')
    assert_match(/ERROR(.+)--hosts/, result.raw_output)
    on(default, 'beaker init --hosts centos6-64')
    result = on(default, 'beaker provision')
    assert_match(/Using available host/, result.stdout)
    subcommand_state = on(default, "cat #{SubcommandUtil::SUBCOMMAND_STATE}").stdout
    subcommand_state = YAML.parse(subcommand_state).to_ruby
    assert_equal(true, subcommand_state['provisioned'])
  end
end
