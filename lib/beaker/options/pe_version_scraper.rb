require 'open-uri'
module Beaker
  module Options
    #A set of functions to determine the PE version to use during testing
    module PEVersionScraper
      # Scrape the PE version (such as 3.0) from the file at dist_dir/version_file
      #
      # Version file is of the format
      #
      #  3.0.1-3-g57b669e
      #
      # @param [String] dist_dir The directory containing the version_file
      # @param [String] version_file The file to scrape
      #
      # @return [String, nil] The PE version in the version_file or nil if not found
      # @raise [ArgumentError] Raises if version_file does not exist or cannot be opened
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
