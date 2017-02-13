module Beaker
  module DSL
    # Test Tagging is about applying meta-data to tests (using the #tag method),
    # so that you can control which tests are executed in a particular beaker
    # run at a more fine-grained level.
    #
    # @note There are a few places where TestTagging-related code is located:
    #   - {Beaker::Options::Parser#normalize_tags!} makes sure the test tags
    #     are formatted correctly for use in this module
    #   - {Beaker::Options::CommandLineParser#initialize} parses test tagging
    #     options
    #   - {Beaker::Options::Validator#validate_tags} ensures test tag CLI params
    #     are valid for use by this module
    module TestTagging

      # Sets tags on the current {Beaker::TestCase}, and skips testing
      # if necessary after checking this case's tags against the ones that are
      # being included or excluded.
      #
      # @param [Array<String>] tags Tags to be assigned to the current test
      #
      # @return nil
      # @api public
      def tag(*tags)
        metadata[:case] ||= {}
        metadata[:case][:tags] = []
        tags.each do |tag|
          metadata[:case][:tags] << tag.downcase
        end

        @options[:test_tag_and]     ||= []
        @options[:test_tag_or]      ||= []
        @options[:test_tag_exclude] ||= []

        tags_needed_to_include_this_test = []
        @options[:test_tag_and].each do |tag_to_include|
          tags_needed_to_include_this_test << tag_to_include \
            unless metadata[:case][:tags].include?(tag_to_include)
        end
        skip_test "#{self.path} does not include necessary tag(s): #{tags_needed_to_include_this_test}" \
          if tags_needed_to_include_this_test.length > 0

        found_test_tag = false
        @options[:test_tag_or].each do |tag_to_include|
          found_test_tag = metadata[:case][:tags].include?(tag_to_include)
          break if found_test_tag
        end
        skip_test "#{self.path} does not include any of these tag(s): #{@options[:test_tag_or]}" \
          if @options[:test_tag_or].length > 0 && !found_test_tag

        tags_to_remove_to_include_this_test = []
        @options[:test_tag_exclude].each do |tag_to_exclude|
          tags_to_remove_to_include_this_test << tag_to_exclude \
            if metadata[:case][:tags].include?(tag_to_exclude)
        end
        skip_test "#{self.path} includes excluded tag(s): #{tags_to_remove_to_include_this_test}" \
          if tags_to_remove_to_include_this_test.length > 0

        platform_specific_tag_confines
      end

      # Handles platform-specific tag confines logic
      #
      # @return nil
      # @!visibility private
      def platform_specific_tag_confines
        @options[:platform_tag_confines_object] ||= PlatformTagConfiner.new(
          @options[:platform_tag_confines]
        )
        confines = @options[:platform_tag_confines_object].confine_details(
          metadata[:case][:tags]
        )
        confines.each do |confine_details|
          logger.notify( confine_details[:log_message] )
          confine(
            confine_details[:type],
            :platform => confine_details[:platform_regex]
          )
        end
      end

      class PlatformTagConfiner

        # Constructs the PlatformTagConfiner, transforming the user format
        #   into the internal structure for use by Beaker itself.
        #
        # @param [Array<Hash{Symbol=>Object}>] platform_tag_confines_array
        #   The array of PlatformTagConfines objects that specify how these
        #   confines should behave. See the note below for more info
        #
        # @note PlatformTagConfines objects come in the form
        #     [
        #       {
        #         :platform => <platform-regex>,
        #         :tag_reason_hash => {
        #           <tag> => <reason to confine>,
        #           <tag> => <reason to confine>,
        #           ...etc...
        #         }
        #       }
        #     ]
        #
        #   Internally, we want to turn tag matches into platform
        #     confine statements. So a better internal structure would
        #     be something of the form:
        #     {
        #       <tag> => [{
        #         :platform => <platform-regex>,
        #         :reason => <reason to confine>,
        #         :type => :except,
        #       }, ... ]
        #     }
        def initialize(platform_tag_confines_array)
          platform_tag_confines_array ||= []
          @tag_confine_details_hash = {}
          platform_tag_confines_array.each do |entry|
            entry[:tag_reason_hash].keys.each do |tag|
              @tag_confine_details_hash[tag] ||= []
              log_msg = "Tag '#{tag}' found, confining: except platforms "
              log_msg << "matching regex '#{entry[:platform]}'. Reason: "
              log_msg << "'#{entry[:tag_reason_hash][tag]}'"
              @tag_confine_details_hash[tag] << {
                :platform_regex => entry[:platform],
                :log_message => log_msg,
                :type => :except
              }
            end
          end
        end

        # Gets the confine details needed for a set of tags
        #
        # @param [Array<String>] tags Tags of the given test
        #
        # @return [Array<Hash{Symbol=>Object}>] an array of
        #   Confine details hashes, which are hashes of symbols
        #   to their properties, which are objects of various
        #   kinds, depending on the key
        def confine_details(tags)
          tags ||= []
          details = []
          tags.each do |tag|
            tag_confine_array = @tag_confine_details_hash[tag]
            next if tag_confine_array.nil?

            details.push( *tag_confine_array )
            # tag_confine_array.each do |confine_details|
            #   details << confine_details
            # end
          end
          details
        end
      end

    end
  end
end