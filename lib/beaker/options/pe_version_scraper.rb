module Beaker
  module Options
    module PEVersionScraper
      def self.load_pe_version dist_dir, version_file
        version = ""
        begin
          open("#{dist_dir}/#{version_file}") do |file|
            while line = file.gets
              if /(\w.*)/ =~ line then
                version = $1.strip
                puts "Found LATEST: Puppet Enterprise Version #{version}"
              end
            end
          end
        rescue
          version = 'unknown'
        end
        return version
      end

      def self.load_pe_version_win dist_dir, version_file
        version = ""
        begin
          open("#{dist_dir}/#{version_file}") do |file|
            while line = file.gets
              if /(\w.*)/ =~ line then
                version=$1.strip
                puts "Found LATEST: Puppet Enterprise Windows Version #{version}"
              end
            end
          end
        rescue
          version = 'unknown'
        end
        return version
      end

    end
  end
end
