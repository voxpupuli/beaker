
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

