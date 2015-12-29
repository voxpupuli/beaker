[ 'host', 'command_factory', 'command', 'options' ].each do |lib|
      require "beaker/#{lib}"
end

module Unix
  class Host < Beaker::Host
    [ 'user', 'group', 'exec', 'pkg', 'file' ].each do |lib|
          require "beaker/host/unix/#{lib}"
    end

    include Unix::User
    include Unix::Group
    include Unix::File
    include Unix::Exec
    include Unix::Pkg

    def platform_defaults
      h = Beaker::Options::OptionsHash.new
      h.merge({
        'user'             => 'root',
        'group'            => 'root',
        'pathseparator'    => ':',
      })
    end

    # Determines which SSH Server is in use on this host
    #
    # @note This method is mostly a placeholder method, since only :openssh
    #   can be returned at this time. Checkout {Windows::Host#determine_ssh_server}
    #   for an example where work needs to be done to determine the answer
    #
    # @return [Symbol] Value for the SSH Server in use
    def determine_ssh_server
      :openssh
    end

    # Gets the path & file name for the puppet agent dev package on Unix
    #
    # @param [String] puppet_collection Name of the puppet collection to use
    # @param [String] puppet_agent_version Version of puppet agent to get
    # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
    #
    # @note Solaris does require :download_url to be set on the opts argument
    #   in order to check for builds on the builds server
    #
    # @raise [ArgumentError] If one of the two required parameters (puppet_collection,
    #   puppet_agent_version) is either not passed or set to nil
    #
    # @return [String, String] Path to the directory and filename of the package, respectively
    def solaris_puppet_agent_dev_package_info( puppet_collection = nil, puppet_agent_version = nil, opts = {} )
      error_message = "Must provide %s argument to get puppet agent package information"
      raise ArgumentError, error_message % "puppet_collection" unless puppet_collection
      raise ArgumentError, error_message % "puppet_agent_version" unless puppet_agent_version
      raise ArgumentError, error_message % "opts[:download_url]" unless opts[:download_url]

      variant, version, arch, codename = self['platform'].to_array
      platform_error = "Incorrect platform '#{variant}' for #solaris_puppet_agent_dev_package_info"
      raise ArgumentError, platform_error if variant != 'solaris'

      if arch == 'x86_64'
        arch = 'i386'
      end
      release_path_end = "solaris/#{version}/#{puppet_collection}"
      solaris_revision_conjunction = '-'
      revision = '1'
      if version == '10'
        solaris_release_version = ''
        pkg_suffix = 'pkg.gz'
        solaris_name_conjunction = '-'
        component_version = puppet_agent_version
      elsif version == '11'
        # Ref:
        # http://www.oracle.com/technetwork/articles/servers-storage-admin/ips-package-versioning-2232906.html
        #
        # Example to show package name components:
        #   Full package name: puppet-agent@1.2.5.38.6813,5.11-1.sparc.p5p
        #   Schema: <component-name><solaris_name_conjunction><component_version><solaris_release_version><solaris_revision_conjunction><revision>.<arch>.<pkg_suffix>
        solaris_release_version = ',5.11' # injecting comma to prevent from adding another var
        pkg_suffix = 'p5p'
        solaris_name_conjunction = '@'
        component_version = puppet_agent_version.dup
        component_version.gsub!(/[a-zA-Z]/, '')
        component_version.gsub!(/(^-)|(-$)/, '')
        # Here we strip leading 0 from version components but leave
        # singular 0 on their own.
        component_version = component_version.split('-').join('.')
        component_version = component_version.split('.').map(&:to_i).join('.')
      end
      release_file_base = "puppet-agent#{solaris_name_conjunction}#{component_version}#{solaris_release_version}"
      release_file_end = "#{arch}.#{pkg_suffix}"
      release_file = "#{release_file_base}#{solaris_revision_conjunction}#{revision}.#{release_file_end}"
      if not link_exists?("#{opts[:download_url]}/#{release_path_end}/#{release_file}")
        release_file = "#{release_file_base}.#{release_file_end}"
      end
      return release_path_end, release_file
    end

    # Gets the path & file name for the puppet agent dev package on Unix
    #
    # @param [String] puppet_collection Name of the puppet collection to use
    # @param [String] puppet_agent_version Version of puppet agent to get
    # @param [Hash{Symbol=>String}] opts Options hash to provide extra values
    #
    # @note Solaris does require some options to be set. See
    #   {#solaris_puppet_agent_dev_package_info} for more details
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
      case variant
      when /^(solaris)$/
        release_path_end, release_file = solaris_puppet_agent_dev_package_info(
          puppet_collection, puppet_agent_version, opts )
      when /^(sles|aix)$/
        arch = 'ppc' if variant == 'aix' && arch == 'power'
        release_path_end = "#{variant}/#{version}/#{puppet_collection}/#{arch}"
        release_file = "puppet-agent-#{puppet_agent_version}-1.#{variant}#{version}.#{arch}.rpm"
      else
        msg = "puppet_agent dev package info unknown for platform '#{self['platform']}'"
        raise ArgumentError, msg
      end
      return release_path_end, release_file
    end

    def external_copy_base
      return @external_copy_base if @external_copy_base
      @external_copy_base = '/root'
      variant, version, arch, codename = self['platform'].to_array
      # Solaris 10 uses / as the root user directory. Solaris 11 uses /root (like most).
      @external_copy_base = '/' if variant == 'solaris' && version == '10'
      @external_copy_base
    end

    def initialize name, host_hash, options
      super

      @external_copy_base = nil
    end

  end
end
