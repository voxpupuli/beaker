require 'yaml' unless defined?(YAML)
require 'rubygems' unless defined?(Gem)
begin
  require 'beaker/logger'
rescue LoadError
  require File.expand_path(File.join(File.dirname(__FILE__), '..', 'logger.rb'))
end

class VsphereHelper
  def initialize vInfo = {}
    @logger = vInfo[:logger] || Beaker::Logger.new
    begin
      require 'rbvmomi'
    rescue LoadError
      raise "Unable to load RbVmomi, please ensure its installed"
    end
    @connection = RbVmomi::VIM.connect :host     => vInfo[:server],
                                       :user     => vInfo[:user],
                                       :password => vInfo[:pass],
                                       :insecure => true
  end

  def self.load_config(dot_fog = '.fog')
    # support Fog/Cloud Provisioner layout
    # (ie, someplace besides my made up conf)
    vsphere_credentials = nil
    if File.exists? '/etc/plharness/vsphere'
      vsphere_credentials = load_legacy_credentials

    elsif File.exists?( dot_fog )
      vsphere_credentials = load_fog_credentials(dot_fog)
    end

    return vsphere_credentials
  end

  def self.load_fog_credentials(dot_fog = '.fog')
    vInfo = YAML.load_file( dot_fog )

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

  def find_customization name
    csm = @connection.serviceContent.customizationSpecManager

    begin
      customizationSpec = csm.GetCustomizationSpec({:name => name}).spec
    rescue
      customizationSpec = nil
    end

    return customizationSpec
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

  def find_datastore datastorename
    datacenter = @connection.serviceInstance.find_datacenter
    datacenter.find_datastore(datastorename)
  end

  def find_folder foldername
    datacenter = @connection.serviceInstance.find_datacenter
    base = datacenter.vmFolder
    folders = foldername.split('/')
    folders.each do |folder|
      case base
        when RbVmomi::VIM::Folder
          base = base.childEntity.find { |f| f.name == folder }
        else
          abort "Unexpected object type encountered (#{base.class}) while finding folder"
      end
    end

    base
  end

  def find_pool poolname
    datacenter = @connection.serviceInstance.find_datacenter
    base = datacenter.hostFolder
    pools = poolname.split('/')
    pools.each do |pool|
      case base
        when RbVmomi::VIM::Folder
          base = base.childEntity.find { |f| f.name == pool }
        when RbVmomi::VIM::ClusterComputeResource
          base = base.resourcePool.resourcePool.find { |f| f.name == pool }
        when RbVmomi::VIM::ResourcePool
          base = base.resourcePool.find { |f| f.name == pool }
        else
          abort "Unexpected object type encountered (#{base.class}) while finding resource pool"
      end
    end

    base = base.resourcePool unless base.is_a?(RbVmomi::VIM::ResourcePool) and base.respond_to?(:resourcePool)
    base
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

