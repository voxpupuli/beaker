class MockShip 
  attr_accessor :name, :ports, :image_id, :flavor, :region, :username, :dns, :tags

  def initialize
    @dns = "my.ip.address"
  end

  def wait_for_sshd
    @dns = "#{@name}.my.ip"
    return true
  end

end

class MockFleet
  attr_accessor :ships
  @@attempts = 0

  def initialize
    @ships = []
  end

  def add type
    @ships << MockShip.new
    yield(@ships[-1])
    @ships[-1]
  end

  def start
    if @@attempts < 1
      @@attempts += 1
      raise Fog::Errors::Error
    end
  end

  def destroy
  end

end

class MockBlimpy 
  @@fleet = nil
  def self.fleet 
    yield(@@fleet = MockFleet.new)
    @@fleet
  end

end
