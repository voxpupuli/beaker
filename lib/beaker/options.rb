[ 'options_hash', 'presets', 'command_line_parser', 'options_file_parser', 'hosts_file_parser', 'pe_version_scraper', 'parser' ].each do |file|
  begin
    require "beaker/options/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'options', file))
  end
end
