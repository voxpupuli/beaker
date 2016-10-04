require 'semantic'

module Beaker
  module Shared
    module Semvar

      #Is semver-ish version a less than semver-ish version b
      #@param [String] a A version of the from '\d.\d.\d.*'
      #@param [String] b A version of the form '\d.\d.\d.*'
      #@return [Boolean] true if a is less than b, otherwise return false
      #
      #@note 3.0.0-160-gac44cfb is greater than 3.0.0, and 2.8.2
      #@note -rc being less than final builds is not yet implemented.
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
        a_rest = a.split('-', 2)[1]
        b_rest = b.split('-', 2)[1]
        if a_rest and b_rest and a_rest < b_rest
          return false
        elsif a_rest and not b_rest
          return false
        elsif not a_rest and b_rest
          return true
        end
        return false
      end

      # Wrapper around semantic semver gem that supports our
      # semver-breaking version scheme in PE.
      #
      #@param [String] a A version of the from '\d.\d.\d.*'
      #@param [String/Symbol] cmp A comparison operator such as <, >, or ==
      #@param [String] b A version of the form '\d.\d.\d.*'
      #@return [Boolean] true if a <cmp> b
      #
      #@note 3.0.0-160-gac44cfb is greater than 3.0.0, and 2.8.2
      #@note -rc being less than final builds is not yet implemented.
      def puppet_version_comparison a, cmp, b
        ah = Hash.new(0)
        bh = Hash.new(0)

        ah[:ver], ah[:rc], ah[:build] = a.split('-', 3)
        bh[:ver], bh[:rc], bh[:build] = b.split('-', 3)

        ah[:x], ah[:y], ah[:z] = ah[:ver].split('.')
        bh[:x], bh[:y], bh[:z] = bh[:ver].split('.')

        ah.each { |k, v| ah[k] = 0 if ah[k].nil? }
        bh.each { |k, v| bh[k] = 0 if bh[k].nil? }

        ah[:semver] = Semantic::Version.new [ah[:x], ah[:y], ah[:z]].join('.')
        bh[:semver] = Semantic::Version.new [bh[:x], bh[:y], bh[:z]].join('.')

        if ah[:semver] != bh[:semver]
          return ah[:semver].send(cmp.to_sym, bh[:semver])
        elsif ah[:rc] != bh[:rc]
          return ah[:rc].to_s.send(cmp.to_sym, bh[:rc].to_s)
        else
          return ah[:build].to_s.send(cmp.to_sym, bh[:build].to_s)
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
