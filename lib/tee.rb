class Tee
  def initialize(file)
    @file = file
  end

  def method_missing(*args)
    @file.send(*args)
    STDOUT.send(*args)
  end

  def respond_to?(name)
    @file.respond_to? name
  end
end
