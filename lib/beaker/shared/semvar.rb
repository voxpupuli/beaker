module Beaker
  module Shared
    module Semvar

      #Is semver-ish version a less than semver-ish version b
      #@param [String] a A version of the from '\d.\d.\d.*'
      #@param [String] b A version of the form '\d.\d.\d.*'
      #@return [Boolean] true if a is less than b, otherwise return false
      #
      #@note This has been updated for our current versioning scheme.
      #@note 2019.5.0 is greater than 2019.5.0-rc0
      #@note 2019.5.0-rc0-1-gabc1234 is greater than 2019.5.0-rc0
      #@note 2019.5.0-rc1 is greater than 2019.5.0-rc0-1-gabc1234
      #@note 2019.5.0-1-gabc1234 is greater than 2019.5.0
      def version_is_less a, b
        a_nums = a.split('-')[0].split('.')
        b_nums = b.split('-')[0].split('.')
        (0...a_nums.length).each do |i|
          if i < b_nums.length
            if a_nums[i].to_i < b_nums[i].to_i
              return true
            elsif a_nums[i].to_i > b_nums[i].to_i
              return false
            end
          else
            return false
          end
        end
        #checks all dots, they are equal so examine the rest
        a_rest = a.split('-').drop(1)
        a_is_release = a_rest.empty?
        a_is_rc = !a_is_release && /rc\d+/.match?(a_rest[0])
        b_rest = b.split('-').drop(1)
        b_is_release = b_rest.empty?
        b_is_rc = !b_is_release && /rc\d+/.match?(b_rest[0])

        if a_is_release && b_is_release
          # They are equal
          return false
        elsif !a_is_release && !b_is_release
          a_next = a_rest.shift
          b_next = b_rest.shift
          if a_is_rc && b_is_rc
            a_rc = a_next.gsub('rc','').to_i
            b_rc = b_next.gsub('rc','').to_i
            if a_rc < b_rc
              return true
            elsif a_rc > b_rc
              return false
            else
              a_next = a_rest.shift
              b_next = b_rest.shift
              if a_next && b_next
                return a_next.to_i < b_next.to_i
              else
                # If a has nothing after -rc#, it is a tagged RC and 
                # b must be a later build after this tag.
                return a_next.nil?
              end
            end
          else
            # If one of them is not an rc (and also not a release), 
            # that one is a post-release build. So if a is the RC, it is less.
            return a_is_rc
          end
        else
          return (b_is_release && a_is_rc) || (a_is_release && !b_is_rc)
        end
      end

      # Gets the max semver version from a list of them
      # @param [Array<String>]  versions  List of versions to get max from
      # @param [String]         default   Default version if list is nil or empty
      #
      # @note nil values will be skipped
      # @note versions parameter will be copied so that the original
      #   won't be tampered with
      #
      # @return [String, nil] the max string out of the versions list or the
      #   default value if the list is faulty, which can either be set or nil
      def max_version(versions, default=nil)
        return default if !versions || versions.empty?
        versions_copy = versions.dup
        highest = versions_copy.shift
        versions_copy.each do |version|
          next if !version
          highest = version if version_is_less(highest, version)
        end
        highest
      end
    end
  end
end

