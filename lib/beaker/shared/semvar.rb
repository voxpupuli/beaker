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

      # Wrapper class around Semantic::Version that supports our
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
      #
      #@example PuppetVersion.new('2017.1.0-rc9-100-gabcdef') > '2016.2.1' returns true
      #@example PuppetVersion.new('2017.1.0-rc9-100-gabcdef') >= '2016.2.1' returns true
      #@example PuppetVersion.new('2017.1.0-rc9-100-gabcdef') < '2016.2.1' returns false
      #@example PuppetVersion.new('2017.1.0-rc9-100-gabcdef') <= '2016.2.1' returns false
      #@example PuppetVersion.new('2017.1.0-rc9-100-gabcdef') == '2016.2.1' returns false
      #@example PuppetVersion.new('2017.1.0-rc9-100-gabcdef') != '2016.2.1' returns true
      #@example See the semver_spec.rb for more examples
      #@note 3.0.0-160-gac44cfb is greater than 3.0.0, and 2.8.2
      #@note 3.0.0-rc-0-160-gac44cfb is less than 3.0.0, and greater 2.8.2
      class PuppetVersion < Semantic::Version
        attr_reader :major, :minor, :patch, :rc, :build, :sha

        def initialize(version)
          @ver_string = version
          @rc = 999
          @build = 0

          if version =~ /^\d+(\.\d+)?(\.\d)?+$/
            semver = version
          elsif version =~ /^\d+\.\d+\.\d+(-\d+-g[a-f0-9]+)?$/
            semver, @build, @sha = version.split('-', 3)
          elsif version =~ /^\d+\.\d+\.\d+(-rc\d+-\d+-g[a-f0-9]+)?$/
            semver, @rc, @build, @sha = version.split('-', 4)
            @rc = @rc.tr('rc', '').to_i
          else
            raise "PuppetVersion: Unknown format #{version}"
          end

          semver_split = semver.split('.').collect { |str| str.to_i }
          x = semver_split[0] || 0
          y = semver_split[1] || 0
          z = semver_split[2] || 0

          if @build
            @build = @build.to_i
          end

          if @sha
            @sha = @sha[1..-1]
          else
            @sha = nil
          end

          super([x, y, z].join('.'))
        end

        # Overrides Semantic::Version::to_a
        def to_a
          [@major, @minor, @patch, @rc, @build, @sha]
        end

        # Overrides Semantic::Version::to_h
        def to_h
          keys = [:major, :minor, :patch, :rc, :build, :sha]
          Hash[keys.zip(self.to_a)]
        end

        # Overrides Semantic::Version::to_s
        def to_s
          str = super.to_s
          str << ('-rc' << @rc unless @rc.nil? || @rc == 999)
          str << ('-' << @build unless @build.nil?)
          str << ('-g' << @sha unless @sha.nil?)

          str
        end

        def sha=(sha)
          @sha = sha
        end

        # Overrides Semantic::Version::<=>
        def <=>(other_version)
          other_version = Beaker::Shared::Semvar::PuppetVersion.new(other_version) if other_version.is_a? String

          v1 = self.dup
          v2 = other_version.dup

          # The sha must be excluded from the comparison, so that e.g.
          # 1.2.3-rc0-100-gfoo and 1.2.3-rc0-100-gbar are semantically equal.
          # This differs from http://www.semver.org
          v1.sha = nil
          v2.sha = nil

          compare_recursively(v1.to_a, v2.to_a)
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
