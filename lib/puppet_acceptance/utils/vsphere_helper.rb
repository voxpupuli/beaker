require 'yaml' unless defined?(YAML)
require 'rubygems' unless defined?(Gem)
require 'puppet_acceptance/logger'

begin
  require 'rbvmomi'
rescue LoadError
  raise "Unable to load RbVmomi, please ensure its installed"
end

class VsphereHelper
  def initialize vInfo = {}
    @logger = vInfo[:logger] || PuppetAcceptance::Logger.new
    @connection = RbVmomi::VIM.connect :host     => vInfo[:server],
                                       :user     => vInfo[:user],
                                       :password => vInfo[:pass],
                                       :insecure => true
  end

  def self.load_config
    # support Fog/Cloud Provisioner layout
    # (ie, someplace besides my made up conf)
    vsphere_credentials = nil
    if File.exists? '/etc/plharness/vsphere'
      vsphere_credentials = load_legacy_credentials

    elsif File.exists?( File.join(ENV['HOME'], '.fog') )
      vsphere_credentials = load_fog_credentials

    end

    return vsphere_credentials
  end

  def self.load_fog_credentials
    vInfo = YAML.load_file( File.join(ENV['HOME'], '.fog') )

    vsphere_credentials = {}
    vsphere_credentials[:server] = vInfo[:default][:vsphere_server]
    vsphere_credentials[:user]   = vInfo[:default][:vsphere_username]
    vsphere_credentials[:pass]   = vInfo[:default][:vsphere_password]

    return vsphere_credentials
  end

  def self.load_legacy_credentials
    vInfo = YAML.load_file '/etc/plharness/vsphere'

    puts(
      "Use of /etc/plharness/vsphere as a config file is deprecated.\n" +
      "Please use ~/.fog instead\n" +
      "See http://docs.puppetlabs.com/pe/2.0/" +
      "cloudprovisioner_configuring.html for format"
    )

    vsphere_credentials = {}
    vsphere_credentials[:server] = vInfo['location']
    vsphere_credentials[:user]   = vInfo['user']
    vsphere_credentials[:pass]   = vInfo['pass']

    return vsphere_credentials
  end

  def find_snapshot vm, snapname
    search_child_snaps vm.snapshot.rootSnapshotList, snapname
  end

  def search_child_snaps tree, snapname
    snapshot = nil
    tree.each do |child|
      if child.name == snapname
        snapshot ||= child.snapshot
      else
        snapshot ||= search_child_snaps child.childSnapshotList, snapname
      end
    end
    snapshot
  end

  # an easier wrapper around the horrid PropertyCollector interface,
  # necessary for searching VMs in all Datacenters that may be nested
  # within folders of arbitrary depth
  # returns a hash array of <name> => <VirtualMachine ManagedObjects>
  def find_vms names, connection = @connection
    names = names.is_a?(Array) ? names : [ names ]
    containerView = get_base_vm_container_from connection
    propertyCollector = connection.propertyCollector

    objectSet = [{
      :obj => containerView,
      :skip => true,
      :selectSet => [ RbVmomi::VIM::TraversalSpec.new({
          :name => 'gettingTheVMs',
          :path => 'view',
          :skip => false,
          :type => 'ContainerView'
      }) ]
    }]

    propSet = [{
      :pathSet => [ 'name' ],
      :type => 'VirtualMachine'
    }]

    results = propertyCollector.RetrievePropertiesEx({
      :specSet => [{
        :objectSet => objectSet,
        :propSet   => propSet
      }],
      :options => { :maxObjects => nil }
    })

    vms = {}
    results.objects.each do |result|
      name = result.propSet.first.val
      next unless names.include? name
      vms[name] = result.obj
    end

    while results.token do
      results = propertyCollector.ContinueRetrievePropertiesEx({:token => results.token})
      results.objects.each do |result|
        name = result.propSet.first.val
        next unless names.include? name
        vms[name] = result.obj
      end
    end
    vms
  end

  def get_base_vm_container_from connection
    viewManager = connection.serviceContent.viewManager
    viewManager.CreateContainerView({
      :container => connection.serviceContent.rootFolder,
      :recursive => true,
      :type      => [ 'VirtualMachine' ]
    })
  end

  def close
    @connection.close
  end
end

