class Response
  attr_accessor :code, :message, :data
  def initialize(code = 0, message = '', data = nil)
    @code = code
    @message = message
    @data = data
  end
end

class MockFissionVM
  attr_accessor :name
  @@snaps = []
  def initialize name
    @name = name
    @running = true
  end

  def self.set_snapshots snaps
    @@snaps = snaps
  end

  def snapshots
    Response.new(0, '', @@snaps)
  end

  def revert_to_snapshot name
    @running = false
  end

  def running?
    Response.new(0, '', @running)
  end

  def start opt
    @running = true
  end

  def exists?
    true
  end
end

class MockFission
  @@vms = []
  def self.presets hosts
    snaps = []
    hosts.each do |host|
      @@vms << MockFissionVM.new( host.name )
      snaps << host[ :snapshot ]
    end
    MockFissionVM.set_snapshots(snaps)
  end

  def self.all
    Response.new(0, '', @@vms)
  end
  def self.new name
    MockFissionVM.new(name)
  end
end
