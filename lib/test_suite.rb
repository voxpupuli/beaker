class TestSuite
  def initialize(root, options = {})
    @test_files = (Dir[File.join(root, "**/*.rb")] + [root]).select { |f| File.file?(f) }

    if options[:random]
      @random_seed = options[:random] == true ? Time.now.strftime('%s').to_i : options[:random].to_i
      srand @random_seed
      @test_files = @test_files.sort_by { rand }
    else
      @test_files = @test_files.sort
    end
  end

  def test_files
    @test_files
  end

  def random_seed
    @random_seed
  end
end
