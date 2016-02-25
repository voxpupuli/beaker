class MockFogObject
  attr_accessor :id, :ip, :server

  def initialize
    @id = 'testid'
    @ip = '127.0.0.1'
    @server = nil
  end
end

class MockComputeClient
  attr_accessor :optionhash, :server, :create_options

  def initialize optionhash
    @optionhash = optionhash
    @server = nil
  end

  def flavors(*args)
    self
  end

  def images(*args)
    self
  end

  def servers(*args)
    self
  end

  def create(options)
    @create_options = options
    self
  end

  def find(*args)
    return MockFogObject.new
  end

  def wait_for(*args)
    self
  end

  def addresses(*args)
    self
  end

  def id(*args)
    self
  end

  def ip(*args)
    self
  end

  def metadata(*args)
    self
  end

  def update(*args)
    self
  end

end
