module Beaker
  #This class create a Platform object inheriting from String.  It supports all String methods while adding
  #several platform-specific use cases.
  class Platform < String
    #Supported platforms
    PLATFORMS = /^(osx|centos|fedora|debian|oracle|redhat|scientific|sles|ubuntu|windows|solaris|aix|el)\-.+\-.+$/
    #Platform version numbers vs. codenames conversion hash
    PLATFORM_VERSION_CODES =
      { :debian => { "wheezy"  => "7",
                     "squeeze" => "6",
                   },
        :ubuntu => { "trusty"  => "1404",
                     "saucy"   => "1310",
                     "raring"  => "1304",
                     "quantal" => "1210",
                     "precise" => "1204",
                   },
      }

    #Creates the Platform object.  Checks to ensure that the platform String provided meets the platform
    #formatting rules.  Platforms name must be of the format /^OSFAMILY-VERSION-ARCH.*$/ where OSFAMILY is one of:
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
    def initialize(name)
      if name !~ PLATFORMS
        raise ArgumentError, "Unsupported platform name #{name}"
      end
      super
    end

    # Returns the platform string with the platform version as a codename.  If no conversion is
    # necessary then the original, unchanged platform String is returned.
    # @example Platform.new('debian-7-xxx').with_version_codename == 'debian-wheezy-xxx'
    # @return [String] the platform string with the platform version represented as a codename
    def with_version_codename
      name, version, extra = self.split('-', 3)
      PLATFORM_VERSION_CODES.each_key do |platform|
        if name =~ /#{platform}/
          PLATFORM_VERSION_CODES[platform].each do |version_codename, version_number|
            #remove '.' from version number
            if version.delete('.') =~ /#{version_number}/
              version = version_codename
              break
            end
          end
          break
        end
      end
      [name, version, extra].join('-')
    end

    # Returns the platform string with the platform version as a number.  If no conversion is necessary
    # then the original, unchanged platform String is returned.
    # @example Platform.new('debian-wheezy-xxx').with_version_number == 'debian-7-xxx'
    # @return [String] the platform string with the platform version represented as a number
    def with_version_number
      name, version, extra = self.split('-', 3)
      PLATFORM_VERSION_CODES.each_key do |platform|
        if name =~ /#{platform}/
          PLATFORM_VERSION_CODES[platform].each do |version_codename, version_number|
            if version =~ /#{version_codename}/
              version = version_number
              break
            end
          end
          break
        end
      end
      [name, version, extra].join('-')
    end

  end
end
