module Beaker
  module DSL
    module InstallUtils
      #
      # This module contains methods to help install puppet modules
      #
      # To mix this is into a class you need the following:
      # * a method *hosts* that yields any hosts implementing
      #   {Beaker::Host}'s interface to act upon.
      # * a method *options* that provides an options hash, see {Beaker::Options::OptionsHash}
      # * the module {Beaker::DSL::Roles} that provides access to the various hosts implementing
      #   {Beaker::Host}'s interface to act upon
      # * the module {Beaker::DSL::Wrappers} the provides convenience methods for {Beaker::DSL::Command} creation
      module ModuleUtils

        # The directories in the module directory that will not be scp-ed to the test system when using
        # `copy_module_to`
        PUPPET_MODULE_INSTALL_IGNORE = ['.bundle', '.git', '.idea', '.vagrant', '.vendor', 'vendor', 'acceptance',
                                        'bundle', 'spec', 'tests', 'log', '.svn', 'junit', 'pkg', 'example']

        # Install the desired module on all hosts using either the PMT or a
        #   staging forge
        #
        # @see install_dev_puppet_module
        def install_dev_puppet_module_on( host, opts )
          if options[:forge_host]
            with_forge_stubbed_on( host ) do
              install_puppet_module_via_pmt_on( host, opts )
            end
          else
            copy_module_to( host, opts )
          end
        end
        alias :puppet_module_install_on :install_dev_puppet_module_on

        # Install the desired module on all hosts using either the PMT or a
        #   staging forge
        #
        # Passes options through to either `install_puppet_module_via_pmt_on`
        #   or `copy_module_to`
        #
        # @param opts [Hash]
        #
        # @example Installing a module from the local directory
        #   install_dev_puppet_module( :source => './', :module_name => 'concat' )
        #
        # @example Installing a module from a staging forge
        #   options[:forge_host] = 'my-forge-api.example.com'
        #   install_dev_puppet_module( :source => './', :module_name => 'concat' )
        #
        # @see install_puppet_module_via_pmt
        # @see copy_module_to
        def install_dev_puppet_module( opts )
          block_on( hosts ) {|h| install_dev_puppet_module_on( h, opts ) }
        end
        alias :puppet_module_install :install_dev_puppet_module

        # Install the desired module with the PMT on a given host
        #
        # @param opts [Hash]
        # @option opts [String] :module_name The short name of the module to be installed
        # @option opts [String] :version The version of the module to be installed
        def install_puppet_module_via_pmt_on( host, opts = {} )
          block_on host do |h|
            version_info = opts[:version] ? "-v #{opts[:version]}" : ""
            if opts[:source]
              author_name, module_name = parse_for_modulename( opts[:source] )
              modname = "#{author_name}-#{module_name}"
            else
              modname = opts[:module_name]
            end

            puppet_opts = {}
            if host[:default_module_install_opts].respond_to? :merge
              puppet_opts = host[:default_module_install_opts].merge( puppet_opts )
            end

            on h, puppet("module install #{modname} #{version_info}", puppet_opts)
          end
        end

        # Install the desired module with the PMT on all known hosts
        # @see #install_puppet_module_via_pmt_on
        def install_puppet_module_via_pmt( opts = {} )
          install_puppet_module_via_pmt_on(hosts, opts)
        end

        # Install local module for acceptance testing
        # should be used as a presuite to ensure local module is copied to the hosts you want, particularly masters
        # @param [Host, Array<Host>, String, Symbol] one_or_more_hosts
        #                   One or more hosts to act upon,
        #                   or a role (String or Symbol) that identifies one or more hosts.
        # @option opts [String] :source ('./')
        #                   The current directory where the module sits, otherwise will try
        #                         and walk the tree to figure out
        # @option opts [String] :module_name (nil)
        #                   Name which the module should be installed under, please do not include author,
        #                     if none is provided it will attempt to parse the metadata.json and then the Module file to determine
        #                     the name of the module
        # @option opts [String] :target_module_path (host['distmoduledir']/modules)
        #                   Location where the module should be installed, will default
        #                    to host['distmoduledir']/modules
        # @option opts [Array] :ignore_list
        # @option opts [String] :protocol
        #                   Name of the underlying transfer method. Valid options are 'scp' or 'rsync'.
        # @raise [ArgumentError] if not host is provided or module_name is not provided and can not be found in Modulefile
        #
        def copy_module_to(one_or_more_hosts, opts = {})
          block_on one_or_more_hosts do |host|
            opts = {:source => './',
                    :target_module_path => host['distmoduledir'],
                    :ignore_list => PUPPET_MODULE_INSTALL_IGNORE}.merge(opts)

            ignore_list = build_ignore_list(opts)
            target_module_dir = on( host, "echo #{opts[:target_module_path]}" ).stdout.chomp
            source_path = File.expand_path( opts[:source] )
            source_dir = File.dirname(source_path)
            source_name = File.basename(source_path)
            if opts.has_key?(:module_name)
              module_name = opts[:module_name]
            else
              _, module_name = parse_for_modulename( source_path )
            end

            target_path = File.join(target_module_dir, module_name)
            if host.is_powershell? #make sure our slashes are correct
              target_path = target_path.gsub(/\//,'\\')
            end

            opts[:protocol] ||= 'scp'
            case opts[:protocol]
            when 'scp'
              #move to the host
              logger.debug "Using scp to transfer #{source_path} to #{target_path}"
              scp_to host, source_path, target_module_dir, {:ignore => ignore_list}

              #rename to the selected module name, if not correct
              cur_path = File.join(target_module_dir, source_name)
              if host.is_powershell? #make sure our slashes are correct
                cur_path = cur_path.gsub(/\//,'\\')
              end
              host.mv cur_path, target_path unless cur_path == target_path
            when 'rsync'
              logger.debug "Using rsync to transfer #{source_path} to #{target_path}"
              rsync_to host, source_path, target_path, {:ignore => ignore_list}
            else
              logger.debug "Unsupported transfer protocol, returning nil"
              nil
            end
          end
        end
        alias :copy_root_module_to :copy_module_to

        #Recursive method for finding the module root
        # Assumes that a Modulefile exists
        # @param [String] possible_module_directory
        #                   will look for Modulefile and if none found go up one level and try again until root is reached
        #
        # @return [String,nil]
        def parse_for_moduleroot(possible_module_directory)
          if File.exists?("#{possible_module_directory}/Modulefile") || File.exists?("#{possible_module_directory}/metadata.json")
            possible_module_directory
          elsif possible_module_directory === '/'
            logger.error "At root, can't parse for another directory"
            nil
          else
            logger.debug "No Modulefile or metadata.json found at #{possible_module_directory}, moving up"
            parse_for_moduleroot File.expand_path(File.join(possible_module_directory,'..'))
          end
        end

        #Parse root directory of a module for module name
        # Searches for metadata.json and then if none found, Modulefile and parses for the Name attribute
        # @param [String] root_module_dir
        # @return [String] module name
        def parse_for_modulename(root_module_dir)
          author_name, module_name = nil, nil
          if File.exists?("#{root_module_dir}/metadata.json")
            logger.debug "Attempting to parse Modulename from metadata.json"
            module_json = JSON.parse(File.read "#{root_module_dir}/metadata.json")
            if(module_json.has_key?('name'))
              author_name, module_name = get_module_name(module_json['name'])
            end
          end
          if !module_name && File.exists?("#{root_module_dir}/Modulefile")
            logger.debug "Attempting to parse Modulename from Modulefile"
            if /^name\s+'?(\w+-\w+)'?\s*$/i.match(File.read("#{root_module_dir}/Modulefile"))
              author_name, module_name = get_module_name(Regexp.last_match[1])
            end
          end
          if !module_name && !author_name
            logger.debug "Unable to determine name, returning null"
          end
          return author_name, module_name
        end

        #Parse modulename from the pattern 'Auther-ModuleName'
        #
        # @param [String] author_module_name <Author>-<ModuleName> pattern
        #
        # @return [String,nil]
        #
        def get_module_name(author_module_name)
          split_name = split_author_modulename(author_module_name)
          if split_name
            return split_name[:author], split_name[:module]
          end
        end

        #Split the Author-Name into a hash
        # @param [String] author_module_attr
        #
        # @return [Hash<Symbol,String>,nil] :author and :module symbols will be returned
        #
        def split_author_modulename(author_module_attr)
          result = /(\w+)-(\w+)/.match(author_module_attr)
          if result
            {:author => result[1], :module => result[2]}
          else
            nil
          end
        end

        # Build an array list of files/directories to ignore when pushing to remote host
        # Automatically adds '..' and '.' to array.  If not opts of :ignore list is provided
        # it will use the static variable PUPPET_MODULE_INSTALL_IGNORE
        #
        # @param opts [Hash]
        # @option opts [Array] :ignore_list A list of files/directories to ignore
        def build_ignore_list(opts = {})
          ignore_list = opts[:ignore_list] || PUPPET_MODULE_INSTALL_IGNORE
          if !ignore_list.kind_of?(Array) || ignore_list.nil?
            raise ArgumentError "Ignore list must be an Array"
          end
          ignore_list << '.' unless ignore_list.include? '.'
          ignore_list << '..' unless ignore_list.include? '..'
          ignore_list
        end

      end
    end

  end
end
