test_name 'Group Test' do
  step "#group_get: has an Administrators group on Windows" do
    hosts.select { |h| h['platform'].include?('windows') }.each do |host|
      host.group_get('Administrators') do |result|
        refute_match(result.stdout, '1376', 'Output indicates Administrators not found')
      end
    end
  end

  step "#group_get: should not have CroMags group on Windows" do
    hosts.select { |h| h['platform'].include?('windows') }.each do |host|
      assert_raises Beaker::Host::CommandFailure do
        host.group_get('CroMags') { |result| }
      end
    end
  end

end
