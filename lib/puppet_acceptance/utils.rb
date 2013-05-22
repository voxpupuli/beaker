[ 'vsphere_helper', 'vm_control', 'ntp_control', 'etc_hosts'].each do |file|
  begin
    require "puppet_acceptance/utils/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'utils', file))
  end
end
