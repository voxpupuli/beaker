[ 'host', 'command_factory' ].each do |lib|
  require "beaker/#{lib}"
end

module Eos
  class Host < Unix::Host

    # Gets the path & file name for the puppet agent dev package on EOS
    #
    # @param [String] puppet_collection Name of the puppet collection to use
    # @param [String] puppet_agent_version Version of puppet agent to get
    # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
    #
    # @note EOS doesn't use any additional options at this time, but does require
    #   both puppet_collection & puppet_agent_version, & will fail without them
    #
    # @raise [ArgumentError] If one of the two required parameters (puppet_collection,
    #   puppet_agent_version) is either not passed or set to nil
    #
    # @return [String, String] Path to the directory and filename of the package, respectively
    def puppet_agent_dev_package_info( puppet_collection = nil, puppet_agent_version = nil, opts = {} )
      error_message = "Must provide %s argument to get puppet agent dev package information"
      raise ArgumentError, error_message % "puppet_collection" unless puppet_collection
      raise ArgumentError, error_message % "puppet_agent_version" unless puppet_agent_version

      variant, version, arch, _ = self['platform'].to_array
      release_path = "#{variant}/#{version}/#{puppet_collection}/#{arch}"
      release_file = "puppet-agent-#{puppet_agent_version}-1.#{variant}#{version}.#{arch}.swix"
      return release_path, release_file
    end

    # Copies a remote file to the host location specified
    #
    # @param [String] remote_url URL to the remote file
    # @param [String] host_directory Path to the host directory on the host.
    #
    # @note in EOS, you just copy the file as an extension, you don't worry
    #   about location, so that parameter is ignored
    #
    # @return [Result] The result of copying that file to the host
    def get_remote_file( remote_url, host_directory = '' )
      commands = ['enable', "copy #{remote_url} extension:"]
      command = commands.join("\n")
      execute("Cli -c '#{command}'")
    end

    # Installs an extension file already copied via {#get_remote_file} or something similar
    #
    # @param [String] filename Name of the file to install, including file extension
    #
    # @return [Result] The result of running the install command on the host
    def install_from_file( filename )
      commands = ['enable', "extension #{filename}"]
      command = commands.join("\n")
      execute("Cli -c '#{command}'")
    end

  end
end