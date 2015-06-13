module Beaker
  module DSL
    module Helpers
      # Methods that help you query the state of your tests, these
      # methods do not require puppet to be installed to execute correctly
      module TestHelpers

        # Gets the currently executing test's name, which is set in a test
        # using the {Beaker::DSL::Structure#test_name} method.
        #
        # @return [String] Test name, or nil if it hasn't been set
        def current_test_name()
          metadata[:case] && metadata[:case][:name] ? metadata[:case][:name] : nil
        end

        # Gets the currently executing test's filename, which is set from the
        # +@path+ variable passed into the {Beaker::TestCase#initialize} method,
        # not including the '.rb' extension
        #
        # @example if the path variable was man/plan/canal.rb, then the filename would be:
        #   canal
        #
        # @return [String] Test filename, or nil if it hasn't been set
        def current_test_filename()
          metadata[:case] && metadata[:case][:file_name] ? metadata[:case][:file_name] : nil
        end

        # Gets the currently executing test's currently executing step name.
        # This is set using the {Beaker::DSL::Structure#step} method.
        #
        # @return [String] Step name, or nil if it hasn't been set
        def current_step_name()
          metadata[:step] && metadata[:step][:name] ? metadata[:step][:name] : nil
        end

        # Sets the currently executing test's name.
        #
        # @param [String] name Name of the test
        #
        # @return nil
        # @api private
        def set_current_test_name(name)
          metadata[:case] ||= {}
          metadata[:case][:name] = name
        end

        # Sets the currently executing test's filename.
        #
        # @param [String] filename Name of the file being tested
        #
        # @return nil
        # @api private
        def set_current_test_filename(filename)
          metadata[:case] ||= {}
          metadata[:case][:file_name] = filename
        end

        # Sets the currently executing step's name.
        #
        # @param [String] name Name of the step
        #
        # @return nil
        # @api private
        def set_current_step_name(name)
          metadata[:step] ||= {}
          metadata[:step][:name] = name
        end

      end
    end
  end
end
