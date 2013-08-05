#!/usr/bin/env ruby

if ENV['RUBYLIB']
  ENV['RUBYLIB'] += ':lib'
else
  ENV['RUBYLIB'] = 'lib'
end

system('bin/systest', *ARGV)
exit $?.exitstatus  
