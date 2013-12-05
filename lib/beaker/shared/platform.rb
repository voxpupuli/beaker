module Beaker
  module Shared
    module Platform
      #supported platforms
      PLATFORMS = /^(centos|fedora|debian|oracle|redhat|scientific|sles|ubuntu|windows|solaris|aix|el)\-.+\-.+$/

      PLATFORM_VERSION_CODES = 
        { :debian => { "wheezy"  => "7",
                       "squeeze" => "6",
                     },
          :ubuntu => { "saucy"   => "1310",
                       "raring"  => "1304",
                       "quantal" => "1210",
                       "precise" => "1204",
                     },
        }

      def use_version_codename(platform)
        name, version, extra = platform.split('-', 3)
        PLATFORM_VERSION_CODES.each_key do |platform|
          if name =~ /#{platform}/
            PLATFORM_VERSION_CODES[platform].each do |version_codename, version_number|
              #remove '.' from version number
              if version.delete('.') =~ /#{version_number}/
                version = version_codename
              end
            end
          end
        end
        [name, version, extra].join('-')
      end

      def use_version_number(platform)
        name, version, extra = platform.split('-', 3)
        PLATFORM_VERSION_CODES.each_key do |platform|
          if name =~ /#{platform}/
            PLATFORM_VERSION_CODES[platform].each do |version_codename, version_number|
              if version =~ /#{version_codename}/
                version = version_number
              end
            end
          end
        end
        [name, version, extra].join('-')
      end

    end
  end
end
