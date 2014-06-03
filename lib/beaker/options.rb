[ 'options_hash', 'presets', 'command_line_parser', 'options_file_parser', 'hosts_file_parser', 'pe_version_scraper', 'parser' ].each do |lib|
  require "beaker/options/#{lib}"
end
