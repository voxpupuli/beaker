require 'beaker-rspec/beaker_shim'
require "beaker-rspec/helpers/serverspec"
include BeakerRSpec::BeakerShim

RSpec.configure do |c|
  # Enable color
  c.tty = true

  # Define persistant hosts setting
  c.add_setting :hosts, :default => []
  # Define persistant options setting
  c.add_setting :options, :default => {}

  # Defined target nodeset
  nodeset = ENV['RS_SET'] || 'default'
  nodesetfile = ENV['RS_SETFILE'] || File.join('spec/acceptance/nodesets',"#{nodeset}.yml")

  case ENV['RS_DESTROY']
  when 'no'
    preserve = ['--preserve-hosts','always']
  when 'onpass'
    preserve = ['--preserve-hosts','onfail']
  else
    preserve = ['--preserve-hosts','never']
  end
  fresh_nodes = ENV['RS_PROVISION'] == 'no' ? '--no-provision' : nil
  keyfile = ENV['RS_KEYFILE'] ? ['--keyfile', ENV['RS_KEYFILE']] : nil
  debug = ENV['RS_DEBUG'] ? ['--log-level', 'debug'] : nil

  # Configure all nodes in nodeset
  c.setup([preserve, fresh_nodes, '--hosts', nodesetfile, keyfile, debug].flatten.compact)
  c.provision
  c.validate

  # Destroy nodes if no preserve hosts
  c.after :suite do
    c.cleanup
  end
end
