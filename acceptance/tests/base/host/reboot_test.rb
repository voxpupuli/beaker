test_name 'Reboot Test' do
  step "#reboot: can reboot the host" do
    hosts.each do |host|
      host.reboot
      on host, "echo #{host} rebooted!"
    end
  end
end