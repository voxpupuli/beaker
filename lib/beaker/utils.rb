[ 'ntp_control', 'setup_helper', 'repo_control', 'validator' ].each do |file|
  begin
    require "beaker/utils/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'utils', file))
  end
end
