%w(validator options_hash presets command_line_parser options_file_parser hosts_file_parser parser).each do |lib|
  require "beaker/options/#{lib}"
end
