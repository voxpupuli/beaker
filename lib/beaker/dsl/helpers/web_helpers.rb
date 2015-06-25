module Beaker
  module DSL
    module Helpers
      # Convenience methods for checking links and moving web content to hosts
      module WebHelpers

        # Blocks until the port is open on the host specified, returns false
        # on failure
        def port_open_within?( host, port = 8140, seconds = 120 )
          repeat_for( seconds ) do
            host.port_open?( port )
          end
        end

        #Determine is a given URL is accessible
        #@param [String] link The URL to examine
        #@return [Boolean] true if the URL has a '200' HTTP response code, false otherwise
        #@example
        #  extension = link_exists?("#{URL}.tar.gz") ? ".tar.gz" : ".tar"
        def link_exists?(link)
          require "net/http"
          require "net/https"
          require "open-uri"
          url = URI.parse(link)
          http = Net::HTTP.new(url.host, url.port)
          http.use_ssl = (url.scheme == 'https')
          http.start do |http|
            return http.head(url.request_uri).code == "200"
          end
        end

        # Fetch file_name from the given base_url into dst_dir.
        #
        # @param [String] base_url The base url from which to recursively download
        #                          files.
        # @param [String] file_name The trailing name compnent of both the source url
        #                           and the destination file.
        # @param [String] dst_dir The local destination directory.
        #
        # @return [String] dst The name of the newly-created file.
        #
        # @!visibility private
        def fetch_http_file(base_url, file_name, dst_dir)
          FileUtils.makedirs(dst_dir)
          src = "#{base_url}/#{file_name}"
          dst = File.join(dst_dir, file_name)
          if File.exists?(dst)
            logger.notify "Already fetched #{dst}"
          else
            logger.notify "Fetching: #{src}"
            logger.notify "  and saving to #{dst}"
            open(src) do |remote|
              File.open(dst, "w") do |file|
                FileUtils.copy_stream(remote, file)
              end
            end
          end
          return dst
        end

        # Recursively fetch the contents of the given http url, ignoring
        # `index.html` and `*.gif` files.
        #
        # @param [String] url The base http url from which to recursively download
        #                     files.
        # @param [String] dst_dir The local destination directory.
        #
        # @return [String] dst The name of the newly-created subdirectory of
        #                      dst_dir.
        #
        # @!visibility private
        def fetch_http_dir(url, dst_dir)
          logger.notify "fetch_http_dir (url: #{url}, dst_dir #{dst_dir})"
          if url[-1, 1] !~ /\//
            url += '/'
          end
          url = URI.parse(url)
          chunks = url.path.split('/')
          dst = File.join(dst_dir, chunks.last)
          #determine directory structure to cut
          #only want to keep the last directory, thus cut total number of dirs - 2 (hostname + last dir name)
          cut = chunks.length - 2
          wget_command = "wget -nv -P #{dst_dir} --reject \"index.html*\",\"*.gif\" --cut-dirs=#{cut} -np -nH --no-check-certificate -r #{url}"

          logger.notify "Fetching remote directory: #{url}"
          logger.notify "  and saving to #{dst}"
          logger.notify "  using command: #{wget_command}"

          #in ruby 1.9+ we can upgrade this to popen3 to gain access to the subprocess pid
          result = `#{wget_command} 2>&1`
          result.each_line do |line|
            logger.debug(line)
          end
          if $?.to_i != 0
            raise "Failed to fetch_remote_dir '#{url}' (exit code #{$?}"
          end
          dst
        end

      end
    end
  end
end
