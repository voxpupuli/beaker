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

      # Validates that the given version is a valid/expected PE version.
      # Splits up a PE version string into a struct of all the elements of the version
      #
      # @param version [String] A PE version string
      # @return [Struct] containing the elements of the version
      def puppet_version_split(version)
        version_struct = Struct.new("Version", :ver, :rc, :build, :sha, :x, :y, :z, :semver, :string) do
          def to_s
            "#{semver}-#{rc}-#{build}-g#{sha}"
          end
        end
        v = version_struct.new

        v[:string] = version

        if version =~ /^\d+(\.\d+)?(\.\d)?+$/
          v[:ver] = version
          v[:rc] = 999
        elsif version =~ /^\d+\.\d+\.\d+(-\d+-g[a-f0-9]+)?$/
          v[:ver], v[:build], v[:sha] = version.split('-', 3)
          v[:rc] = 999
        elsif version =~ /^\d+\.\d+\.\d+(-rc\d+-\d+-g[a-f0-9]+)?$/
          v[:ver], v[:rc], v[:build], v[:sha] = version.split('-', 4)
          v[:rc] = v[:rc].tr('rc', '').to_i
        else
          raise "Unknown version format: #{version}"
        end

        v[:x], v[:y], v[:z] = v.ver.split('.').collect { |str| str.to_i }

        if v[:build]
          v[:build] = v[:build].to_i
        end

        if v[:sha]
          v[:sha] = v[:sha][1..-1]
        else
          v[:sha] = 'none'
        end

        v.each_pair { |name, value| v[name] = 0 if value.nil? }

        v[:semver] = Semantic::Version.new [v.x, v.y, v.z].join('.')

        return v
      end

      # Wrapper around semantic semver gem that supports our
      # semver-breaking version scheme in PE.
      #
      # Overview of how PE is versioned for the public:
      # <year of release>.<release number in year>.<bug fix z>
      # Ex. 2016.5.0, 2016.5.1, 2017.1.0, 2017.1.1
      #
      # Overview of how PE internal builds are versioned:
      # year.release.bug_z(-rc[0-9])-<build number>-g<git SHA>
      # Ex. 2016.5.0-rc0-100-gabcdef12
      #
      # This comparison method ignores the git SHA, because it cannot
      # usefully be compared and no two builds should have the same
      # SHA.
      #
      #@param [String] a A version of the from '\d.\d.\d-rc\d-\d.-g<sha>'
      #@param [String/Symbol] cmp A comparison operator such as <, >, or ==
      #@param [String] b A version of the form '\d.\d.\d-rc\d-\d.-g<sha>'
      #@return [Boolean] true if a <cmp> b
      #
      #@example puppet_version_comparison('2017.1.0-rc9-100-gabcdef', :>, '2016.2.1') returns true
      #@example puppet_version_comparison('2017.1.0-rc9-100-gabcdef', :>=, '2016.2.1') returns true
      #@example puppet_version_comparison('2017.1.0-rc9-100-gabcdef', :<, '2016.2.1') returns false
      #@example puppet_version_comparison('2017.1.0-rc9-100-gabcdef', :<=, '2016.2.1') returns false
      #@example puppet_version_comparison('2017.1.0-rc9-100-gabcdef', :==, '2016.2.1') returns false
      #@example puppet_version_comparison('2017.1.0-rc9-100-gabcdef', :!=, '2016.2.1') returns true
      #@example See the semver_spec.rb for more examples
      #@note 3.0.0-160-gac44cfb is greater than 3.0.0, and 2.8.2
      #@note 3.0.0-rc-0-160-gac44cfb is less than 3.0.0, and greater 2.8.2
      def puppet_version_comparison a, cmp, b
        as = puppet_version_split(a)
        bs = puppet_version_split(b)

        if as.semver != bs.semver
          return as.semver.send(cmp.to_sym, bs.semver)
        elsif as.rc != bs.rc
          return as.rc.send(cmp.to_sym, bs.rc)
        else
          return as.build.send(cmp.to_sym, bs.build)
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
