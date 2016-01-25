class MockNetworkClient
  attr_accessor :optionhash

  def initialize optionhash
    @optionhash = optionhash
  end

  def networks(*args)
    self
  end

  def find(*args)
    self
  end

  def id(*args)
    self
  end

end
