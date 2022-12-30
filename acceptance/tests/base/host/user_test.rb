test_name 'User Test' do
  step "#user_get: has an Administrator user on Windows" do
    hosts.select { |h| h['platform'].include?('windows') }.each do |host|
      host.user_get('Administrator') do |result|
        refute_match(result.stdout, 'NET HELPMSG', 'Output indicates Administrator not found')
      end
    end
  end

  step "#user_get: should not have CaptainCaveman user on Windows" do
    hosts.select { |h| h['platform'].include?('windows') }.each do |host|
      assert_raises Beaker::Host::CommandFailure do
        host.user_get('CaptainCaveman') { |result| }
      end
    end
  end

end
