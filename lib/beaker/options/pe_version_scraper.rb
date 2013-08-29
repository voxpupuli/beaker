module Beaker
  module Options
    module PEVersionScraper
      require 'open-uri'
      def self.load_pe_version dist_dir, version_file
        version = nil
        begin
          open("#{dist_dir}/#{version_file}") do |file|
            while line = file.gets
              if /(\w.*)/ =~ line then
                version = $1.strip
                puts "Found LATEST: Puppet Enterprise Version #{version}"
              end
            end
          end
        rescue Exception => e
          raise "Failure to examine #{dist_dir}/#{version_file}\n\t\t#{e.to_s}"
        end
        return version
      end

    end
  end
end
