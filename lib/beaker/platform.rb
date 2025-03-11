module Beaker
  # This class create a Platform object inheriting from String.  It supports
  # all String methods while adding several platform-specific use cases.
  class Platform < String
    # Supported platforms
    PLATFORMS = /^(alpine|amazon(fips)?|(free|open)bsd|osx|centos|fedora|debian|oracle|redhat|redhatfips|scientific|opensuse|sles|ubuntu|windows|solaris|aix|archlinux|el)\-.+\-.+$/
    # Platform version numbers vs. codenames conversion hash
    PLATFORM_VERSION_CODES =
      { :debian => { "forky" => "14",
                     "trixie" => "13",
                     "bookworm" => "12",
                     "bullseye" => "11",
                     "buster" => "10", },
        :ubuntu => { "noble" => "2404",
                     "jammy" => "2204",
                     "focal" => "2004",
                     "bionic" => "1804", },
        :osx => { "highsierra" => "1013",
                  "sierra" => "1012",
                  "elcapitan" => "1011",
                  "yosemite" => "1010",
                  "mavericks" => "109", }, }

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
    # * amazon
    # * amazonfips
    # * freebsd
    # * openbsd
    # * osx
    # * centos
    # * fedora
    # * debian
    # * oracle
    # * redhat
    # * redhatfips
    # * scientific
    # * opensuse
    # * sles
    # * ubuntu
    # * windows
    # * solaris
    # * aix
    # * el
    # * archlinux
    def initialize(name)
      raise ArgumentError, "Unsupported platform name #{name}" if !PLATFORMS.match?(name)

      super

      @variant, version, @arch = self.split('-', 3)
      codename_version_hash = PLATFORM_VERSION_CODES[@variant.to_sym]

      @version = version
      @codename = nil

      return unless codename_version_hash

      if codename_version_hash[version]
        @codename = version
        @version = codename_version_hash[version]
      else
        version = version.delete('.')
        version_codename_hash = codename_version_hash.invert
        @codename = version_codename_hash[version]
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
      [@variant, @codename || @version, @arch].join('-')
    end

    # Returns the platform string with the platform version as a number.  If no conversion is necessary
    # then the original, unchanged platform String is returned.
    # @example Platform.new('debian-wheezy-xxx').with_version_number == 'debian-7-xxx'
    # @return [String] the platform string with the platform version represented as a number
    def with_version_number
      [@variant, @version, @arch].join('-')
    end

    def uses_chrony?
      case @variant
      when 'amazon', 'fedora'
        true
      when 'el'
        @version.to_i >= 8
      else
        false
      end
    end

    # Return a list of packages that should always be present.
    #
    # @return [Array<String>] A list of packages to install
    def base_packages
      case @variant
      when 'el'
        @version.to_i >= 8 ? ['iputils'] : %w[curl]
      when 'debian'
        %w[curl lsb-release]
      when 'freebsd'
        %w[curl perl5|perl]
      when 'solaris'
        @version.to_i >= 11 ? %w[curl] : %w[CSWcurl wget]
      when 'archlinux'
        %w[curl net-tools openssh]
      when 'amazon', 'amazonfips', 'fedora'
        ['iputils']
      when 'aix', 'osx', 'windows'
        []
      else
        %w[curl]
      end
    end

    # Return a list of packages that are needed for timesync
    #
    # @return [Array<String>] A list of packages to install for timesync
    def timesync_packages
      return ['chrony'] if uses_chrony?

      case @variant
      when 'freebsd', 'openbsd', 'windows', 'aix', 'osx'
        []
      when 'archlinux', 'opensuse'
        ['ntp']
      when 'sles'
        @version.to_i >= 11 ? %w[ntp] : []
      when 'solaris'
        @version.to_i >= 11 ? %w[ntp] : %w[CSWntp]
      else
        %w[ntpdate]
      end
    end
  end
end
