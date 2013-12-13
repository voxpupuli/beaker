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

  preserve = ENV['RS_DESTROY'] == 'no' ? '--preserve-hosts' : ''
  fresh_nodes = ENV['RS_PROVISION'] == 'no' ? '--no-provision' : ''

  # Configure all nodes in nodeset
  c.setup([preserve, fresh_nodes, '--type','git','--hosts', nodesetfile])
  c.provision
  c.validate

  # Destroy nodes if no preserve hosts
  c.after :suite do
    c.cleanup
  end
end
