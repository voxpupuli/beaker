test_name "Remove acceptance VMs"

  if options[:vmrun] == 'blimpy' and not options[:preserve_hosts]
    fleet = Blimpy.fleet do |fleet|
      hosts.each do |host|
        fleet.add(:aws) do |ship|
          ship.name = host.name
        end
      end
    end

    fleet.destroy
  else
    skip_test "Skipping cleanup VM step"
  end
