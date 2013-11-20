require 'beaker-rspec/beaker_shim'
require "beaker-rspec/helpers/serverspec"
include BeakerRSpec::BeakerShim

RSpec.configure do |c|
  # Enable color
  c.tty = true

  # Define persistant hosts setting
  c.add_setting :hosts, :default => []

  # Defined target nodeset
  nodeset = ENV['RSPEC_SET'] || 'default'
  nodesetfile = ENV['RSPEC_SETFILE'] || File.join('spec/acceptance/nodesets',"#{nodeset}.yml")

  preserve = ENV['RSPEC_DESTROY'] ? '--preserve-hosts' : ''
  fresh_nodes = ENV['RSPEC_NO_PROVISION'] ? '--no-provision' : ''

  # Configure all nodes in nodeset
  c.setup([preserve, fresh_nodes, '--type','git','--hosts', nodesetfile])
  c.provision
  c.validate

  # Destroy nodes if no preserve hosts
  c.after :suite do
    c.cleanup
  end
end
