test_name 'use the init subcommand' do

  def delete_root_folder_contents
    on default, 'rm -rf /root/*'
  end

  step 'ensure that `beaker init` fails correctly when not provided a hypervisor' do
    expect_failure('it should return a non-zero code when it fails') do
      result = on(default, 'beaker init', :accept_all_exit_codes => true)
      refute_equal(0, result.exit_code, '`beaker init` without a hypervisor argument should return a non-zero exit code')
    end
  end

  step 'ensure that `beaker help init` works' do
    result = on(default, 'beaker help init')
    assert_equal(0, result.exit_code, '`beaker help init` should return a zero exit code')
  end

  step 'ensure that `beaker init` accepts both vmpooler and vagrant hypervisor arguments' do

    ['vmpooler', 'vagrant'].each do |hypervisor|
      result = on(default, "beaker init --hypervisor=#{hypervisor}")
      assert_match(/Writing default host config/, result.stdout)
      assert_equal(0, result.exit_code, "`beaker init --hypervisor=#{hypervisor}` should return a zero exit code")
      step 'ensure that the Rakefile is present' do
        on(default, '[ -e "Rakefile" ]')
      end
    delete_root_folder_contents
    end
  end


  step 'ensure that a Rakefile is not overwritten if it does exist prior' do
    delete_root_folder_contents
    on(default, "beaker init --hypervisor=vmpooler")
    prepended_rakefile = on(default, 'cat Rakefile').stdout
    delete_root_folder_contents
    on(default, 'echo "require \'tempfile\'" >> Rakefile')
    on(default, 'beaker init --hypervisor=vmpooler', :accept_all_exit_codes => true)
    rakefile = on(default, 'cat Rakefile')

    # Assert that the Rakefile contents includes the original and inserted requirements
    assert(result.stdout.include?(prepended_rakefile), 'Rakefile should not contain prepended require')
    assert(result.stdout.include?("require 'tempfile'"), 'Rakefile should not contain prepended require')
  end
end

