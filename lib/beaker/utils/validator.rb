module Beaker
  module Utils
    module Validator
      PACKAGES = ['curl']
      UNIX_PACKAGES = ['ntpdate']
      OPENSUSE_PACKAGES = ['ntp']

      def self.validate(hosts, logger)
        hosts.each do |host|
          PACKAGES.each do |pkg|
            if not host.check_for_package pkg
              host.install_package pkg
            end
          end
          if host['platform'] =~ /(opensuse|sles)/
            OPENSUSE_PACKAGES.each do |pkg|
              if not host.check_for_package pkg
                host.install_package pkg
              end
            end
          else
            if host['platform'] !~ /(windows)|(aix)|(solaris)/
              UNIX_PACKAGES.each do |pkg|
                if not host.check_for_package pkg
                  host.install_package pkg
                end
              end
            end
          end
        end
      rescue => e
        report_and_raise(logger, e, "validate")
      end
    end
  end
end
