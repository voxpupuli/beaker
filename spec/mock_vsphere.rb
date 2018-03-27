class MockRbVmomiSnapshot
  attr_accessor :name
  attr_accessor :rootSnapshotList
  attr_accessor :childSnapshotList

  def initialize
    @name = nil
    @rootSnapshotList = []
    @childSnapshotList = []
  end

  def print_nested_array arg
    str = '[ '
    arg.each do |arry|
      if arry.is_a?(Array)
        str += print_nested_array( arry )
      elsif arry.is_a?(MockRbVmomiSnapshot)
        str += arry.to_s + ", "
      end
    end
    str + ' ]'
  end

  def to_s
    "Snapshot(name: #{@name}, rootSnapshotlist: #{print_nested_array(@rootSnapshotList)}, childSnapshotList: #{print_nested_array(@childSnapshotList)})"
  end

  def snapshot
    self
  end

end

class MockRbVmomiVM
  attr_accessor :snapshot, :name, :state

  def info
    self
  end

  def process_snaphash snaphash
    shotlist = []
    snaphash.each do | name, subsnaps |
      new_snap = MockRbVmomiSnapshot.new
      new_snap.name = name
      if subsnaps.is_a?(Hash)
        new_snap.childSnapshotList = process_snaphash( subsnaps )
      end
      shotlist << new_snap
    end
    shotlist
  end

  def get_snapshot name, snaplist = @snapshot.rootSnapshotList
    snapshot = nil
    snaplist.each do |snap|
      if snap.is_a?(Array)
        snapshot = get_snapshot(snap, name)
      elsif snap.name == name
        snapshot = snap.snapshot
      end
    end
    snapshot
  end

  def initialize name, snaphash
    @name = name
    @snapshot = MockRbVmomiSnapshot.new
    @snapshot.name = name
    @snapshot.rootSnapshotList = process_snaphash( snaphash )
  end

end

class MockRbVmomiConnection

  class CustomizationSpecManager

    class CustomizationSpec
      def spec
        true
      end
    end

    def initialize
      @customizationspec = CustomizationSpec.new
    end

    def GetCustomizationSpec arg
      @customizationspec
    end

  end

  class PropertyCollector
    class Result
      def initialize(name, object)
        @name = name
        @object = object
      end

      def val
        @name
      end

      def obj
        @object
      end

      def propSet
        [self]
      end

    end

    class ResultContainer
      attr_accessor :token

      def initialize
        @results = []
      end

      def objects
        @results
      end

      def add_object obj
        @results << obj
      end

    end

    def initialize
      @results = ResultContainer.new
    end


    def RetrievePropertiesEx hash
      @results.token = true
      @results
    end

    def ContinueRetrievePropertiesEx token
      @results.token = false
      @results
    end

    def add_result name, object
      @results.add_object( Result.new(name, object) )
    end

    def WaitForUpdates arg
      result = OpenStruct.new
      result.version = 'version'
      result
    end

    def CreateFilter arg
      filter = OpenStruct.new
      filter.DestroyPropertyFilter = true
      filter
    end

  end

  class ServiceInstance
    class Datacenter
      attr_accessor :vmFolder
      attr_accessor :hostFolder

      def initialize
        @vmFolder = MockRbVmomi::VIM::Folder.new
        @vmFolder.name = "/root"
      end

      def find_datastore arg
        true
      end

    end

    def initialize
      @datacenter = Datacenter.new
    end

    def find_datacenter dc
      @datacenter
    end

  end

  class ServiceManager
    class ViewManager

      def CreateContainerView hash
        @view = hash
      end

    end

    def initialize
      @customizationspecmanager = CustomizationSpecManager.new
      @viewmanager = ViewManager.new
    end

    def customizationSpecManager
      @customizationspecmanager
    end

    def viewManager
      @viewmanager
    end

    def rootFolder
      "/root"
    end

  end

  def initialize opts
    @host = opts[ :host ]
    @user = opts[ :user ]
    @password = opts[ :password ]
    @insecure = opts[ :insecure ]
    @serviceinstance = ServiceInstance.new
    @servicemanager = ServiceManager.new
    @propertycollector = PropertyCollector.new

  end

  def serviceInstance
    @serviceinstance
  end

  def serviceContent
    @servicemanager
  end

  def propertyCollector
    @propertycollector
  end

  def set_info vms
    vms.each do |vm|
      @propertycollector.add_result(vm.name, vm)
    end
  end
end


class MockRbVmomi

  class VIM
    class Folder
      attr_accessor :name

      def find
        self
      end


      def childEntity
        self
      end

      def resourcePool
        self
      end

      def traverse path, type=Object, create=false
        self
      end
    end

    class ResourcePool
      attr_accessor :name

      def find
        self
      end

      def resourcePool
        self
      end

    end

    class ClusterComputeResource
      attr_accessor :name

      def find
        self
      end

      def resourcePool
        self
      end

    end

    class TraversalSpec
      def initialize hash

      end

    end

    def self.connect opts
      MockRbVmomiConnection.new( opts )
    end

  end

end
