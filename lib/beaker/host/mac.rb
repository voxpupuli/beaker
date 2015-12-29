[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
  require "beaker/#{lib}"
end

module Mac
    class Host < Unix::Host

    [ 'exec', 'user', 'group', 'pkg' ].each do |lib|
      require "beaker/host/mac/#{lib}"
    end

    include Mac::Exec
    include Mac::User
    include Mac::Group
    include Mac::Pkg

    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'             => 'root',
        'group'            => 'root',
        'pathseparator'    => ':',
      })
    end

    # Gets the path & file name for the puppet agent dev package on OSX
    #
    # @param [String] puppet_collection Name of the puppet collection to use
    # @param [String] puppet_agent_version Version of puppet agent to get
    # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
    #
    # @note OSX doesn't use any additional options at this time, but does require
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

      variant, version, arch, codename = self['platform'].to_array

      mac_pkg_name = "puppet-agent-#{puppet_agent_version}"
      version = version[0,2] + '.' + version[2,2] unless version.include?(".")
      # newest hotness
      path_chunk = "apple/#{version}/#{puppet_collection}/#{arch}"
      release_path_end = path_chunk
      # moved to doing this when 'el capitan' came out & the objection was
      # raised that the code name wasn't a fact, & as such can be hard to script
      # example: puppet-agent-0.1.0-1.osx10.9.dmg
      release_file = "#{mac_pkg_name}-1.osx#{version}.dmg"
      if not link_exists?("#{opts[:download_url]}/#{release_path_end}/#{release_file}") # new hotness
        # little older change involved the code name as only difference from above
        # example: puppet-agent-0.1.0-1.mavericks.dmg
        release_file = "#{mac_pkg_name}-1.#{codename}.dmg"
      end
      if not link_exists?("#{opts[:download_url]}/#{release_path_end}/#{release_file}") # oops, try the old stuff
        release_path_end = "apple/#{puppet_collection}"
        # example: puppet-agent-0.1.0-osx-10.9-x86_64.dmg
        release_file = "#{mac_pkg_name}-#{variant}-#{version}-x86_64.dmg"
      end
      return release_path_end, release_file
    end

    attr_reader :external_copy_base
    def initialize name, host_hash, options
      super

      @external_copy_base = '/var/root'
    end

  end
end
