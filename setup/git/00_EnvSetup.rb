test_name "Setup environment"

WINDOWS_GEMS = [
  'sys-admin', 'win32console -v1.3.2', 'win32-dir', 'win32-eventlog',
  'win32-process', 'win32-service', 'win32-taskscheduler'
]

hosts.each do |host|
  case host['platform']
  when /windows/
    WINDOWS_GEMS.each do |gem|
      step "Installing #{gem}"
      on host, "cmd /c gem install #{gem} --no-ri --no-rdoc"
    end
  else
  end
end
