module Beaker
  class Platform < String
    #supported platforms
    PLATFORMS = /^(centos|fedora|debian|oracle|redhat|scientific|sles|ubuntu|windows|solaris|aix|el)\-.+\-.+$/

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

    def initialize(name)
      if name !~ PLATFORMS
        raise ArgumentError, "Unsupported platform name #{name}"
      end
      super
    end

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
