['host', 'command_factory'].each do |lib|
  require "beaker/#{lib}"
end

module Eos
  class Host < Unix::Host
    # Copies a remote file to the host location specified
    #
    # @param [String] remote_url URL to the remote file
    # @param [String] host_directory Path to the host directory on the host.
    #
    # @note in EOS, you just copy the file as an extension, you don't worry
    #   about location, so that parameter is ignored
    #
    # @return [Result] The result of copying that file to the host
    def get_remote_file(remote_url, _host_directory = '')
      commands = ['enable', "copy #{remote_url} extension:"]
      command = commands.join("\n")
      execute("Cli -c '#{command}'")
    end

    # Installs an extension file already copied via {#get_remote_file} or something similar
    #
    # @param [String] filename Name of the file to install, including file extension
    #
    # @return [Result] The result of running the install command on the host
    def install_from_file(filename)
      commands = ['enable', "extension #{filename}"]
      command = commands.join("\n")
      execute("Cli -c '#{command}'")
    end

  end
end
