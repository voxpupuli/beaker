require 'yaml' unless defined?(YAML)
require 'rbvmomi'
require 'beaker/logger'

class VsphereHelper
  def initialize vInfo
    @logger = vInfo[:logger] || Beaker::Logger.new
    @connection = RbVmomi::VIM.connect :host     => vInfo[:server],
                                       :user     => vInfo[:user],
                                       :password => vInfo[:pass],
                                       :insecure => true
  end

  def self.load_config(dot_fog = '.fog')
    # support Fog/Cloud Provisioner layout
    # (ie, someplace besides my made up conf)
    vsphere_credentials = nil
    if File.exists?( dot_fog )
      vsphere_credentials = load_fog_credentials(dot_fog)
    else
      raise ArgumentError, ".fog file '#{dot_fog}' does not exist"
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

  def find_snapshot vm, snapname
    if vm.snapshot
      search_child_snaps vm.snapshot.rootSnapshotList, snapname
    else
      raise "vm #{vm.name} has no snapshots to revert to"
    end
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

  def find_datastore(dc,datastorename)
    datacenter = @connection.serviceInstance.find_datacenter(dc)
    datacenter.find_datastore(datastorename)
  end

  def find_folder(dc,foldername)
    datacenter = @connection.serviceInstance.find_datacenter(dc)
    base = datacenter.vmFolder.traverse(foldername)
    if base != nil
      base
    else
      abort "Failed to find folder #{foldername}"
    end
  end

  def find_pool(dc,poolname)
    datacenter = @connection.serviceInstance.find_datacenter(dc)
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

  def wait_for_tasks tasks, try, attempts
    obj_set = tasks.map { |task| { :obj => task } }
    filter = @connection.propertyCollector.CreateFilter(
      :spec => {
        :propSet => [{ :type => 'Task',
                       :all  => false,
                       :pathSet => ['info.state']}],
        :objectSet => obj_set
      },
      :partialUpdates => false
    )
    ver = ''
    while true
      result = @connection.propertyCollector.WaitForUpdates(:version => ver)
      ver = result.version
      complete = 0
      tasks.each do |task|
        if ['success', 'error'].member? task.info.state
          complete += 1
        end
      end
      break if (complete == tasks.length)
      if try <= attempts
        sleep 5
        try += 1
      else
        raise "unable to complete Vsphere tasks before timeout"
      end
    end

    filter.DestroyPropertyFilter
    tasks
  end

  def close
    @connection.close
  end
end

