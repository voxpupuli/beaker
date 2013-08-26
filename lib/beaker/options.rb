[ 'options_hash', 'defaults', 'command_line_parser', 'pe_version_scraper', 'parser' ].each do |file|
  begin
    require "beaker/options/#{file}"
  rescue LoadError
    require File.expand_path(File.join(File.dirname(__FILE__), 'options', file))
  end
end
