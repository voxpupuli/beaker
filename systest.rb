#!/usr/bin/env ruby

require 'rubygems' unless defined?(Gem)
require 'net/ssh'
require 'net/scp'
require 'net/http'
require 'socket'
require 'optparse'
require 'systemu'
require 'test/unit'
require 'yaml'

Dir[
  File.expand_path(File.dirname(__FILE__)+'/lib/puppet_acceptance/*.rb')
].each do |file|
  require file
end

PuppetAcceptance::CLI.new.execute!

puts "systest completed successfully, thanks."
exit 0
