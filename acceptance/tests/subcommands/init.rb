test_name 'use the init subcommand' do

  def delete_root_folder_contents
    on default, 'rm -rf /root/*'
  end

  step 'ensure that `beaker init` exit value should be 1 when not provided with a supported hypervisor' do
    result = on(default, 'beaker init ec2', :accept_all_exit_codes => true)
    refute_equal(0, result.exit_code, '`beaker init` without a hypervisor argument should return a non-zero exit code')
  end

  step 'ensure that `beaker help init` works' do
    result = on(default, 'beaker help init')
    assert_match(/Usage+/, result.stdout)
  end

  step 'ensure that `beaker init` accepts no argument as well as accepts either vmpooler or vagrant hypervisor arguments' do
    ['vmpooler', 'vagrant', ''].each do |hypervisor|
      result = on(default, "beaker init #{hypervisor}")
      assert_match(/Writing host config.+/, result.stdout)
      step 'ensure that the Rakefile is present' do
        on(default, '[ -e "Rakefile" ]')
      end
    delete_root_folder_contents
    end
  end


  step 'ensure that a Rakefile is not overwritten if it does exist prior' do
    delete_root_folder_contents
    on(default, "beaker init vmpooler")
    prepended_rakefile = on(default, 'cat Rakefile').stdout
    delete_root_folder_contents
    on(default, 'echo "require \'tempfile\'" >> Rakefile')
    on(default, 'beaker init vmpooler', :accept_all_exit_codes => true)
    rakefile = on(default, 'cat Rakefile')

    # Assert that the Rakefile contents includes the original and inserted requirements
    assert(result.stdout.include?(prepended_rakefile), 'Rakefile should not contain prepended require')
    assert(result.stdout.include?("require 'tempfile'"), 'Rakefile should not contain prepended require')
  end
end
