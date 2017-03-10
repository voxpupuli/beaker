test_name 'use the exec subcommand' do

  def delete_root_folder_contents
    on default, 'rm -rf /root/* /root/.beaker'
  end

  step 'ensure the workspace is clean' do
    delete_root_folder_contents
  end

  step 'run init and provision to set up the system' do
    on default, 'beaker init --hosts centos6-64; beaker provision'
    subcommand_state = on(default, 'cat .beaker/.subcommand_state.yaml').stdout
    subcommand_state = YAML.parse(subcommand_state).to_ruby
    assert_equal(true, subcommand_state['provisioned'])
  end

  step 'create a test dir and populate it with tests' do
    on default, 'mkdir -p testing_dir'
  end

  step 'create remote test file' do
    testfile = <<-TESTFILE
    on(agents, 'echo hello world')
    TESTFILE
    create_remote_file(default, '/root/testing_dir/testfile1.rb', testfile)
  end

  step 'specify that remote file with beaker exec' do
    result = on(default, 'beaker exec testing_dir/testfile1.rb --log-level verbose')
    assert_match(/hello world/, result.stdout)
  end
end
