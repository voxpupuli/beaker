test_name 'use the provision subcommand' do

  SubcommandUtil = Beaker::Subcommands::SubcommandUtil

  def delete_root_folder_contents
    on default, 'rm -rf /root/* /root/.beaker'
    on default, 'mkdir -p /root/.ssh/'
    scp_to default, "#{ENV['HOME']}/.ssh/id_rsa-acceptance", "/root/.ssh/id_rsa"
  end

  step 'run beaker init and provision' do
    delete_root_folder_contents
    on(default, 'beaker init')
    result = on(default, 'beaker provision --hosts centos6-64')
    assert_match(/Using available host/, result.stdout)

    subcommand_state = on(default, "cat #{SubcommandUtil::SUBCOMMAND_STATE}").stdout
    subcommand_state = YAML.parse(subcommand_state).to_ruby
    assert_equal(true, subcommand_state['provisioned'])
  end
end
