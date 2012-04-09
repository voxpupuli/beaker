test_name "Setup environment"

WINDOWS_GEMS = %w[sys-admin win32-dir win32-eventlog win32-process win32-service win32-taskscheduler]

hosts.each do |host|
  case host['platform']
  when /windows/
    step "Installing gems"
    on host, "cmd /c gem install #{WINDOWS_GEMS.join(' ')} --no-ri --no-rdoc"
  else
  end
end
