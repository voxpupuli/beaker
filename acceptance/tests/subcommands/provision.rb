test_name 'use the provision subcommand' do

  def delete_root_folder_contents
    on default, 'rm -rf /root/* /root/.beaker'
  end

  step 'run beaker init and provision' do
    on(default, 'beaker init')
    result = on(default, 'beaker provision --hosts centos6-64')
    assert_match(/Using available host/, result.stdout)

    subcommand_state = on(default, 'cat .beaker/.subcommand_state.yaml').stdout
    subcommand_state = YAML.parse(subcommand_state).to_ruby
    assert_equal(true, subcommand_state['provisioned'])
  end
end
