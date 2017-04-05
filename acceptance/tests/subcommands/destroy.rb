test_name 'use the destroy subcommand' do

  def delete_root_folder_contents
    on default, 'rm -rf /root/* /root/.beaker'
  end

  step 'ensure that `beaker destroy` fails correctly when a configuration has not been initialized' do
    delete_root_folder_contents
    result = on(default, 'beaker destroy', :accept_all_exit_codes => true)
    assert_match(/Please provision an environment/, result.stdout)
    assert_equal(1, result.exit_code, '`beaker destroy` in an uninitialised configuration should return a non-zero exit code')
  end

  step 'ensure that `beaker help destroy` works' do
    result = on(default, 'beaker help destroy')
    assert_match(/Usage/, result.stdout)
    assert_equal(0, result.exit_code, '`beaker help destroy` should return a zero exit code')
  end

  step 'ensure that `beaker destroy --help` works' do
    result = on(default, 'beaker destroy --help')
    assert_match(/Usage/, result.stdout)
    assert_equal(0, result.exit_code, '`beaker destroy --help` should return a zero exit code')
  end

  step 'ensure that `beaker destroy` destroys vmpooler configuration' do
     delete_root_folder_contents
     result = on(default, "beaker init --hosts centos6-64")
     assert_match(/Writing configured options to disk/, result.stdout)
     assert_equal(0, result.exit_code, "`beaker init` should return a zero exit code")
     step 'ensure destroy fails to run against an unprovisioned environment' do
       result = on(default, "beaker destroy", :accept_all_exit_codes => true)
       assert_match(/Please provision an environment/, result.stdout)
       assert_equal(1, result.exit_code, "`beaker destroy` should return a non zero exit code")
     end
     step 'ensure provision provisions, validates, and configures new hosts' do
       result = on(default, "beaker provision")
       assert_match(/Using available host/, result.stdout)
       assert_equal(0, result.exit_code, "`beaker provision` should return a zero exit code")
     end
     step 'ensure destroy will destroy a provisioned environment' do
       result = on(default, 'beaker destroy')
       assert_match(/Handing/, result.stdout)
       assert_equal(0, result.exit_code, "`beaker destroy` should return a zero exit code")
     end
    delete_root_folder_contents
  end

end
