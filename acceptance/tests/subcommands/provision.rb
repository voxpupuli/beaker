test_name 'use the provision subcommand' do

  def delete_root_folder_contents
    on default, 'rm -rf /root/* /root/.beaker'
  end

  # step 'ensure that `beaker provision` fails correctly when a configuration has not been initialized' do
  #   delete_root_folder_contents
  #   result = on(default, 'beaker provision', :accept_all_exit_codes => true)
  #   assert_match(/Please initialise a configuration/, result.stdout)
  #   refute_equal(0, result.exit_code, '`beaker provision` in an uninitialised configuration should return a non-zero exit code')
  # end

  # step 'ensure that `beaker help provision` works' do
  #   result = on(default, 'beaker help provision')
  #   assert_match(/Usage/, result.stdout)
  #   assert_equal(0, result.exit_code, '`beaker help provision` should return a zero exit code')
  # end

  # step 'ensure that `beaker provision --help` works' do
  #   result = on(default, 'beaker provision --help')
  #   assert_match(/Usage/, result.stdout)
  #   assert_equal(0, result.exit_code, '`beaker provision --help` should return a zero exit code')
  # end

  # step 'ensure that `beaker provision` provisions vmpooler configuration' do
  #    result = on(default, "beaker init vmpooler")
  #    assert_match(/Writing host config/, result.stdout)
  #    assert_equal(0, result.exit_code, "`beaker init vmpooler` should return a zero exit code")
  #    step 'ensure that the Rakefile is present' do
  #      on(default, '[ -e "Rakefile" ]')
  #    end
  #    step 'ensure provision provisions, validates, and configures new hosts' do
  #      result = on(default, "beaker provision")
  #      assert_equal(0, result.exit_code, "`beaker provision` should return a zero exit code")
  #    end
  #    step 'ensure provision will not provision new hosts if hosts have already been provisioned' do
  #      result = on(default, 'beaker provision')
  #      assert_match(/Hosts have already been provisioned/, result.stdout)
  #      assert_equal(0, result.exit_code, "`beaker provision` should return a zero exit code")
  #    end
  #   delete_root_folder_contents
  # end
  step 'run beaker init and provision' do
    on(default, 'beaker init')
    result = on(default, 'beaker provision --hosts centos6-64')
    assert_match(/Using available host/, result.stdout)
  end

end
