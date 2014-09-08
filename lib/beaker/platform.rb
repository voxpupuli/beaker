module Beaker
  # This class create a Platform object inheriting from String.  It supports
  # all String methods while adding several platform-specific use cases.
  class Platform < String
    # Supported platforms
    PLATFORMS = /^(gentoo|osx|centos|fedora|debian|oracle|redhat|scientific|sles|ubuntu|windows|solaris|aix|el)\-.+\-.+$/

    # Platform version numbers vs. codenames conversion hash
    PLATFORM_VERSION_CODES =
      { :debian => { "wheezy"  => "7",
                     "squeeze" => "6",
                   },
        :ubuntu => { "trusty"  => "1404",
                     "saucy"   => "1310",
                     "raring"  => "1304",
                     "quantal" => "1210",
                     "precise" => "1204",
                     "lucid"   => "1004",
                   },
      }

    # A string with the name of the platform.
    attr_reader :variant

    # A string with the version number of the platform.
    attr_reader :version

    # A string with the codename of the platform+version, nil on platforms
    # without codenames.
    attr_reader :codename

    # A string with the cpu architecture of the platform.
    attr_reader :arch

    # Creates the Platform object.  Checks to ensure that the platform String
    # provided meets the platform formatting rules.  Platforms name must be of
    # the format /^OSFAMILY-VERSION-ARCH.*$/ where OSFAMILY is one of:
    # * osx
    # * centos
    # * fedora
    # * debian
    # * oracle
    # * redhat
    # * scientific
    # * sles
    # * ubuntu
    # * windows
    # * solaris
    # * aix
    # * el
    # * gentoo
    def initialize(name)
      if name !~ PLATFORMS
        raise ArgumentError, "Unsupported platform name #{name}"
      end

      super

      @variant, version, @arch = self.split('-', 3)
      codename_version_hash = PLATFORM_VERSION_CODES[@variant.to_sym]

      @version = version
      @codename = nil

      if codename_version_hash
        if codename_version_hash[version]
          @codename = version
          @version = codename_version_hash[version]
        else
          version = version.delete('.')
          version_codename_hash = codename_version_hash.invert
          @codename = version_codename_hash[version]
        end
      end
    end

    # Returns array of attributes to allow single line assignment to local
    # variables in DSL and test case methods.
    def to_array
      return @variant, @version, @arch, @codename
    end

    # Returns the platform string with the platform version as a codename.  If no conversion is
    # necessary then the original, unchanged platform String is returned.
    # @example Platform.new('debian-7-xxx').with_version_codename == 'debian-wheezy-xxx'
    # @return [String] the platform string with the platform version represented as a codename
    def with_version_codename
      version_array = [@variant, @version, @arch]
      if @codename
        version_array = [@variant, @codename, @arch]
      end
      return version_array.join('-')
    end

    # Returns the platform string with the platform version as a number.  If no conversion is necessary
    # then the original, unchanged platform String is returned.
    # @example Platform.new('debian-wheezy-xxx').with_version_number == 'debian-7-xxx'
    # @return [String] the platform string with the platform version represented as a number
    def with_version_number
      [@variant, @version, @arch].join('-')
    end

  end
end
