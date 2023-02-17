test_name 'test generic installers'

confine :except, :platform => /^windows|osx/

step 'install arbitrary msi via url' do
  hosts.each do |host|
    if host['platform'].include?('win')
      # this should be implemented at the host/win/pkg.rb level someday
      generic_install_msi_on(host, 'https://releases.hashicorp.com/vagrant/1.8.4/vagrant_1.8.4.msi', {}, {:debug => true})
    end
  end
end

step 'install arbitrary dmg via url' do
  hosts.each do |host|
    if host['platform'].include?('osx')
      host.generic_install_dmg('https://releases.hashicorp.com/vagrant/1.8.4/vagrant_1.8.4.dmg', 'Vagrant', 'Vagrant.pkg')
    end
  end
end
