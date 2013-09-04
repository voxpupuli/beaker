require 'open-uri'
module Beaker
  module Options
    module PEVersionScraper
      def self.load_pe_version dist_dir, version_file
        version = nil
        begin
          open("#{dist_dir}/#{version_file}") do |file|
            while line = file.gets
              if /(\w.*)/ =~ line then
                version = $1.strip
              end
            end
          end
        rescue Errno::ENOENT, OpenURI::HTTPError => e
          raise ArgumentError, "Failure to examine #{dist_dir}/#{version_file}\n\t\t#{e.to_s}"
        end
        return version
      end

    end
  end
end
