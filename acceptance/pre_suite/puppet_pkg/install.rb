# the version is required on windows
# all versions are required for osx
install_puppet({
  :version        => ENV['BEAKER_PUPPET_VERSION'] || '4.8.0',
  :puppet_agent_version => ENV['BEAKER_PUPPET_AGENT_VERSION'] || '1.8.0'
})

on(master, puppet('resource user puppet ensure=present'))
on(master, puppet('resource group puppet ensure=present'))
