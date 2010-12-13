class TestWrapper
  def initialize
    # We put this on each wrapper (rather than the class) so that methods
    # defined in the tests don't leak out to other tests. 
    class << self
      def run_test(file_name,class_name,config)
        eval File.read(file_name)
        eval(class_name).new(config)
      end
    end
  end
end
