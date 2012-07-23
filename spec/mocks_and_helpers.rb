
class MockConfig < Struct.new(:CONFIG, :HOSTS)
  def initialize(conf, hosts, is_pe = false)
    @is_pe = is_pe
    super conf, hosts
  end

  def is_pe?
    @is_pe
  end
end

class MockIO < IO
  def initialize
  end

  methods.each do |meth|
    define_method(:meth) {}
  end

  def === other
    super other
  end
end

module TestFileHelpers
  def create_files file_array
    file_array.each do |f|
      FileUtils.mkdir_p File.dirname(f)
      FileUtils.touch f
    end
  end
end

