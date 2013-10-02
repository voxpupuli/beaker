module TestFileHelpers
  def create_files file_array
    file_array.each do |f|
      FileUtils.mkdir_p File.dirname(f)
      FileUtils.touch f
    end
  end
end
