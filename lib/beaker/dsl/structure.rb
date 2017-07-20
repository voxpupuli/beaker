require 'beaker/dsl/assertions'
module Beaker
  module DSL
    # These are simple structural elements necessary for writing
    # understandable tests and ensuring cleanup actions happen. If using a
    # third party test runner they are unnecessary.
    #
    # To include this in your own test runner a method #logger should be
    # available to yield a logger that implements
    # {Beaker::Logger}'s interface. As well as a method
    # #teardown_procs that yields an array.
    #
    # @example Structuring a test case.
    #     test_name 'Look at me testing things!' do
    #       teardown do
    #         ...clean up actions...
    #       end
    #
    #       step 'Prepare the things' do
    #         ...setup steps...
    #       end
    #
    #       step 'Test the things' do
    #         ...tests...
    #       end
    #
    #       step 'Expect this to fail' do
    #         expect_failure('expected to fail due to PE-1234') do
    #         assert_equal(400, response.code, 'bad response code from API call')
    #       end
    #     end
    #
    module Structure
      require 'pry'
      # Provides a method to help structure tests into coherent steps.
      # @param [String] step_name The name of the step to be logged.
      # @param [Proc] block The actions to be performed in this step.
      def step step_name, &block
        logger.notify "\n* #{step_name}\n"
        set_current_step_name(step_name)
        if block_given?
          logger.step_in()
          begin
            yield
          rescue Exception => e
            if(@options.has_key?(:debug_errors) && @options[:debug_errors] == true)
              logger.info("Exception raised during step execution and debug-errors option is set, entering pry. Exception was: #{e.inspect}")
              logger.info("HINT: Use the pry 'backtrace' and 'up' commands to navigate to the test code")
              binding.pry
            end
            raise e
          end
          logger.step_out()
        end
      end

      # Provides a method to name tests.
      #
      # @param [String] my_name The name of the test to be logged.
      # @param [Proc] block The actions to be performed during this test.
      #
      def test_name my_name, &block
        logger.notify "\n#{my_name}\n"
        set_current_test_name(my_name)
        if block_given?
          logger.step_in()
          yield
          logger.step_out()
        end
      end

      # Declare a teardown process that will be called after a test case is
      # complete.
      #
      # @param block [Proc] block of code to execute during teardown
      # @example Always remove /etc/puppet/modules
      #   teardown do
      #     on(master, puppet_resource('file', '/etc/puppet/modules',
      #       'ensure=absent', 'purge=true'))
      #   end
      def teardown &block
        @teardown_procs << block
      end

      # Wrap an assert that is supposed to fail due to a product bug, an
      # undelivered feature, or some similar situation.
      #
      # This converts failing asserts into passing asserts (so we can continue to
      # run the test even though there are underlying product bugs), and converts
      # passing asserts into failing asserts (so we know when the underlying product
      # bug has been fixed).
      #
      # Pass an assert as a code block, and pass an explanatory message as a
      # parameter. The assert's logic will be inverted (so passes turn into fails
      # and fails turn into passes).
      #
      # @example Typical usage
      #   expect_failure('expected to fail due to PE-1234') do
      #     assert_equal(400, response.code, 'bad response code from API call')
      #   end
      #
      # @example Output when a product bug would normally cause the assert to fail
      #   Warning: An assertion was expected to fail, and did.
      #   This is probably due to a known product bug, and is probably not a problem.
      #   Additional info: 'expected to fail due to PE-6995'
      #   Failed assertion: 'bad response code from API call.
      #   <400> expected but was <409>.'
      #
      # @example Output when the product bug has been fixed
      #   <RuntimeError: An assertion was expected to fail, but passed.
      #   This is probably because a product bug was fixed, and "expect_failure()"
      #   needs to be removed from this assert.
      #   Additional info: 'expected to fail due to PE-6996'>
      #
      # @param [String] explanation A description of why this assert is expected to
      #                             fail
      # @param block [Proc] block of code is expected to either raise an
      #                     {Beaker::Assertions} or else return a value that
      #                     will be ignored
      # @raise [RuntimeError] if the code block passed to this method does not raise
      #                       a {Beaker::Assertions} (i.e., if the assert
      #                       passes)
      # @author Chris Cowell-Shah (<tt>ccs@puppetlabs.com</tt>)
      def expect_failure(explanation, &block)
        begin
          yield if block_given?  # code block should contain an assert that you expect to fail
        rescue Beaker::DSL::Assertions, Minitest::Assertion => failed_assertion
          # Yay! The assert in the code block failed, as expected.
          # Swallow the failure so the test passes.
          logger.notify 'An assertion was expected to fail, and did. ' +
                          'This is probably due to a known product bug, ' +
                          'and is probably not a problem. ' +
                          "Additional info: '#{explanation}' " +
                          "Failed assertion: '#{failed_assertion}'"
          return
        end
        # Uh-oh! The assert in the code block unexpectedly passed.
        fail('An assertion was expected to fail, but passed. ' +
                 'This is probably because a product bug was fixed, and ' +
                 '"expect_failure()" needs to be removed from this test. ' +
                 "Additional info: '#{explanation}'")
      end

      # Limit the hosts a test case is run against
      # @note This will modify the {Beaker::TestCase#hosts} member
      #   in place unless an array of hosts is passed into it and
      #   {Beaker::TestCase#logger} yielding an object that responds
      #   like {Beaker::Logger#warn}, as well as
      #   {Beaker::DSL::Outcomes#skip_test}, and optionally
      #   {Beaker::TestCase#hosts}.
      #
      # @param [Symbol] type The type of confinement to do. Valid parameters
      #                      are *:to* to confine the hosts to only those that
      #                      match *criteria* or *:except* to confine the test
      #                      case to only those hosts that do not match
      #                      criteria.
      # @param [Hash{Symbol,String=>String,Regexp,Array<String,Regexp>}]
      #   criteria Specify the criteria with which a host should be
      #   considered for inclusion or exclusion.  The key is any attribute
      #   of the host that will be yielded by {Beaker::Host#[]}.
      #   The value can be any string/regex or array of strings/regexp.
      #   The values are compared using [Enumerable#any?] so that if one
      #   value of an array matches the host is considered a match for that
      #   criteria.
      # @param [Array<Host>] host_array This creatively named parameter is
      #   an optional array of hosts to confine to.  If not passed in, this
      #   method will modify {Beaker::TestCase#hosts} in place.
      # @param [Proc] block Addition checks to determine suitability of hosts
      #   for confinement.  Each host that is still valid after checking
      #   *criteria* is then passed in turn into this block.  The block
      #   should return true if the host matches this additional criteria.
      #
      # @example Basic usage to confine to debian OSes.
      #     confine :to, :platform => 'debian'
      #
      # @example Confining to anything but Windows and Solaris
      #     confine :except, :platform => ['windows', 'solaris']
      #
      # @example Using additional block to confine to Solaris global zone.
      #     confine :to, :platform => 'solaris' do |solaris|
      #       on( solaris, 'zonename' ) =~ /global/
      #     end
      #
      # @example Confining to an already defined subset of hosts
      #     confine :to, {}, agents
      #
      # @example Confining from  an already defined subset of hosts
      #     confine :except, {}, agents
      #
      # @example Confining to all ubuntu agents + all non-agents
      #     confine :to, { :platform => 'ubuntu' }, agents
      #
      # @example Confining to any non-windows agents + all non-agents
      #     confine :except, { :platform => 'windows' }, agents
      #
      #
      # @return [Array<Host>] Returns an array of hosts that are still valid
      #   targets for this tests case.
      # @raise [SkipTest] Raises skip test if there are no valid hosts for
      #   this test case after confinement.
      def confine(type, criteria, host_array = nil, &block)
        hosts_to_modify = Array( host_array || hosts )
        hosts_not_modified = hosts - hosts_to_modify #we aren't examining these hosts
        case type
        when :except
          if criteria and ( not criteria.empty? )
            hosts_to_modify = hosts_to_modify - select_hosts(criteria, hosts_to_modify, &block) + hosts_not_modified
          else
            # confining to all hosts *except* provided array of hosts
            hosts_to_modify = hosts_not_modified
          end
          if hosts_to_modify.empty?
            logger.warn "No suitable hosts without: #{criteria.inspect}"
            skip_test "No suitable hosts found without #{criteria.inspect}"
          end
        when :to
          if criteria and ( not criteria.empty? )
            hosts_to_modify = select_hosts(criteria, hosts_to_modify, &block) + hosts_not_modified
          else
            # confining to only hosts in provided array of hosts
          end
          if hosts_to_modify.empty?
            logger.warn "No suitable hosts with: #{criteria.inspect}"
            skip_test "No suitable hosts found with #{criteria.inspect}"
          end
        else
          raise "Unknown option #{type}"
        end
        self.hosts = hosts_to_modify
        hosts_to_modify
      end

      # Ensures that host restrictions as specifid by type, criteria and
      # host_array are confined to activity within the passed block.
      # TestCase#hosts is reset after block has executed.
      #
      # @see #confine
      def confine_block(type, criteria, host_array = nil, &block)
        host_array = Array( host_array || hosts )
        original_hosts = self.hosts.dup
        confine(type, criteria, host_array)

        yield

      rescue Beaker::DSL::Outcomes::SkipTest => e
        # I don't like this much, but adding options to confine is a breaking change
        # to the DSL that would involve a major version bump
        if e.message !~ /No suitable hosts found/
          # a skip generated from the provided block, pass it up the chain
          raise e
        end
      ensure
        self.hosts = original_hosts
      end

      #Return a set of hosts that meet the given criteria
      # @param [Hash{Symbol,String=>String,Regexp,Array<String,Regexp>}]
      #   criteria Specify the criteria with which a host should be
      #   considered for inclusion.  The key is any attribute
      #   of the host that will be yielded by {Beaker::Host#[]}.
      #   The value can be any string/regex or array of strings/regexp.
      #   The values are compared using [Enumerable#any?] so that if one
      #   value of an array matches the host is considered a match for that
      #   criteria.
      # @param [Array<Host>] host_array This creatively named parameter is
      #   an optional array of hosts to confine to.  If not passed in, this
      #   method will modify {Beaker::TestCase#hosts} in place.
      # @param [Proc] block Addition checks to determine suitability of hosts
      #   for selection.  Each host that is still valid after checking
      #   *criteria* is then passed in turn into this block.  The block
      #   should return true if the host matches this additional criteria.
      #
      # @return [Array<Host>] Returns an array of hosts that meet the provided criteria
      def select_hosts(criteria, host_array = nil, &block)
        hosts_to_select_from = host_array || hosts
        criteria.each_pair do |property, value|
          hosts_to_select_from = hosts_to_select_from.select do |host|
            inspect_host host, property, value
          end
        end
        if block_given?
          hosts_to_select_from = hosts_to_select_from.select do |host|
            yield host
          end
        end
        hosts_to_select_from
      end

      # @!visibility private
      def inspect_host(host, property, one_or_more_values)
        values = Array(one_or_more_values)
        return values.any? do |value|
          true_false = false
          case value
          when String
            true_false = host[property.to_s].include? value
          when Regexp
            true_false = host[property.to_s] =~ value
          end
          true_false
        end
      end
    end
  end
end
