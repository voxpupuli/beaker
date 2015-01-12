require 'beaker/dsl/install_utils'
require 'fileutils'

module Beaker
  module DSL
    # This module contains methods to assist in installing projects from source
    # that use ezbake for packaging.
    #
    # @api dsl
    module EZBakeUtils

      # @!group Public DSL Methods

      # Installs leiningen project with given name and version on remote host.
      #
      # @param [Host] host A single remote host on which to install the
      #   specified leiningen project.
      # @param [String] project_name The name of the project. In ezbake context
      #   this is the name of both a subdirectory of the ezbake_dir/configs dir
      #   and the name of the .clj file in that directory which contains the
      #   project map used by ezbake to create the staging directory.
      # @param [String] project_param_string The version of the project specified by
      #   project_name which is to be built and installed on the remote host.
      # @param [Hash] env_args Hash of environment arguments
      # @param [String] ezbake_dir The directory to which ezbake should be
      #   cloned; alternatively, if ezbake is already at that directory, it will
      #   be updated from its github master before any ezbake operations are
      #   performed.
      # @api dsl
      def install_from_ezbake host, project_name=nil,
                              project_param_string=nil, env_args={},
                              ezbake_dir='tmp/ezbake'
        ezbake_validate_support host
        project_name = ezbake_lein_project_name if project_name.nil?
        install_ezbake_tarball_on_host host, project_name, project_param_string, ezbake_dir

        # Now run the main makefile tasks to do the source build
        variant, version, _, _ = host['platform'].to_array
        case variant
        when /^(fedora|el|centos)$/
          env = {
            "defaultsdir" => "/etc/sysconfig",
          }
          # Deal with systemd versus SysV in a forwards compatible way
          if (variant =~ /^(el|centos)$/ && version =~ /^(5|6)/)
            ezbake_make host, "install-source-rpm-sysv", env
          else
            ezbake_make host, "install-source-rpm-systemd", env
          end
        when /^(debian|ubuntu|cumulus)$/
          ezbake_make host, "install-source-deb", "defaultsdir" => "/etc/default"
        else
          raise RuntimeError, "No ezbake installation step for #{variant} yet..."
        end
      end

      # Installs termini with given name and version on remote host.
      #
      # @param [Host] host A single remote host on which to install the
      #   specified leiningen project.
      # @param [String] project_name The name of the project. In ezbake context
      #   this is the name of both a subdirectory of the ezbake_dir/configs dir
      #   and the name of the .clj file in that directory which contains the
      #   project map used by ezbake to create the staging directory.
      # @param [String] project_param_string The version of the project specified by
      #   project_name which is to be built and installed on the remote host.
      # @param [Hash] env_args Hash of environment arguments
      # @param [String] ezbake_dir The directory to which ezbake should be
      #   cloned; alternatively, if ezbake is already at that directory, it will
      #   be updated from its github master before any ezbake operations are
      #   performed.
      # @api dsl
      def install_termini_from_ezbake host, project_name=nil,
                                      project_param_string=nil,
                                      env_args={},
                                      ezbake_dir='tmp/ezbake'
        ezbake_validate_support host
        project_name = ezbake_lein_project_name if project_name.nil?
        install_ezbake_tarball_on_host host, project_name, project_param_string, ezbake_dir
        ezbake_make host, "install-#{project_name}-termini"
      end

      # Installs ezbake dependencies on given host.
      #
      # @param [Host] host A single remote host on which to install the
      #   packaging dependencies of the ezbake project configuration currently in
      #   Beaker::DSL::EZBakeUtils.config
      # @api dsl
      def install_ezbake_deps host
        ezbake_validate_support host
        ezbake_tools_available? host

        if not ezbake_config
          ezbake_stage project_name, project_param_string
        end

        variant, version, arch, codename = host['platform'].to_array
        ezbake = ezbake_config

        case variant
        when /^(fedora|el|centos)$/
          dependency_list = ezbake[:redhat][:additional_dependencies]
          dependency_list.each do |dependency|
            package_name, _, package_version = dependency.split
            install_package host, package_name, package_version
          end

        when /^(debian|ubuntu|cumulus)$/
          dependency_list = ezbake[:debian][:additional_dependencies]
          dependency_list.each do |dependency|
            package_name, _, package_version = dependency.split
            if package_version
              package_version = package_version.chop
            end
            install_package host, package_name, package_version
          end

        else
          raise RuntimeError, "No repository installation step for #{variant} yet..."
        end
      end

      # @!endgroup

      REMOTE_PACKAGES_REQUIRED = ['make']
      LOCAL_COMMANDS_REQUIRED = [
        ['leiningen', 'lein --version', nil],
        ['lein-pprint', 'lein with-profile ci pprint :version',
          'Must have lein-pprint installed under the :ci profile.'],
        ['java', 'java -version', nil],
        ['git', 'git --version', nil],
        ['rake', 'rake --version', nil],
      ]
      class << self
        attr_accessor :config
      end

      # Test for support in one place
      #
      # @param [Host] host host to check for support
      # @raise [RuntimeError] if OS is not supported
      # @api private
      def ezbake_validate_support host
        variant, version, _, _ = host['platform'].to_array
        unless variant =~ /^(fedora|el|centos|debian|ubuntu|cumulus)$/
          raise RuntimeError,
                "No support for #{variant} within ezbake_utils ..."
        end
      end

      # @!group Private helpers

      # Execute lein pprint, allowing for a single argument to be
      # passed
      #
      # @param [String] arg Argument to pass to lein ci pprint
      # @return [String] result after munging from clj format
      # @api private
      def ezbake_lein_pprint arg
        cmd =
          "lein with-profile ci pprint #{arg} | tail -n 1 | cut -d\\\" -f2"
        logger.notify("localhost $ #{cmd}")
        result = `#{cmd}`.strip
        logger.notify(result)
        result
      end

      # Retrieve the name of the current project using lein pprint
      # from the local repos project.clj.
      #
      # @return [String] name string from project.clj
      # @api private
      def ezbake_lein_project_name
        ezbake_lein_pprint ":name"
      end

      # Return the version of the project retrieved using pprint from
      # the local repos project.clj.
      #
      # @return [String] version string from project.clj
      # @api private
      def ezbake_lein_project_version
        ezbake_lein_pprint ":version"
      end

      # Build, copy & unpack tarball on remote host
      #
      # @param [Host] host installation destination
      # @param [String] project_name The name of the project. In ezbake context
      #   this is the name of both a subdirectory of the ezbake_dir/configs dir
      #   and the name of the .clj file in that directory which contains the
      #   project map used by ezbake to create the staging directory.
      # @param [String] project_param_string The version of the project specified by
      #   project_name which is to be built and installed on the remote host.
      # @param [String] ezbake_dir The directory to which ezbake should be
      #   cloned; alternatively, if ezbake is already at that directory, it will
      #   be updated from its github master before any ezbake operations are
      #   performed.
      # @api private
      def install_ezbake_tarball_on_host host, project_name,
                                         project_param_string=nil,
                                         ezbake_dir='tmp/ezbake'
        ezbake_tools_available? host

        if not ezbake_config
          ezbake_stage project_name, project_param_string
        end

        variant, _, _, _ = host['platform'].to_array
        case variant
        when /^(osx|windows|solaris|aix)$/
          raise RuntimeError, "Beaker::DSL::EZBakeUtils unsupported platform: #{variant}"
        end

        # Skip installation if the remote directory exists
        result = on host, "test -d #{ezbake_install_dir}", :acceptable_exit_codes => [0, 1]
        return if result.exit_code == 0

        ezbake_staging_dir = File.join(ezbake_dir, "target/staging")
        Dir.chdir(ezbake_staging_dir) do
          ezbake_local_cmd 'rake package:tar'
        end

        local_tarball = ezbake_staging_dir + "/pkg/" + ezbake_install_name + ".tar.gz"
        remote_tarball = ezbake_install_dir + ".tar.gz"
        scp_to host, local_tarball, remote_tarball

        # untar tarball on host
        on host, "tar -xzf " + remote_tarball

        # Check to ensure directory exists
        on host, "test -d #{ezbake_install_dir}"
      end

      # Checks given host for the tools necessary to perform
      # install_from_ezbake. If no host is given then check the local machine
      # for necessary available tools. If a tool is not found, then raise
      # RuntimeError.
      #
      # @param [String] host (optional) if provided tests for the
      #   tools on a remote host
      # @api private
      def ezbake_tools_available? host = nil
        if host
          REMOTE_PACKAGES_REQUIRED.each do |package_name|
            if not check_for_package host, package_name
              raise RuntimeError, "Required package, #{package_name}, not installed on #{host}"
            end
          end
        else
          LOCAL_COMMANDS_REQUIRED.each do |software_name, command, additional_error_message|
            if not system command
              error_message = "Must have #{software_name} installed on development system.\n"
              if additional_error_message
                error_message += additional_error_message
              end
              raise RuntimeError, error_message
            end
          end
        end
      end

      # Return the ezbake config.
      #
      # @return [Hash] configuration for ezbake, usually from ezbake.rb
      # @api private
      def ezbake_config
        EZBakeUtils.config
      end

      # Prepares a staging directory for the specified project.
      #
      # @param [String] project_name The name of the ezbake project being worked
      #   on.
      # @param [String] project_param_string Parameters to be passed to ezbake
      #   on the command line.
      # @param [String] ezbake_dir The local directory where the ezbake project
      #   resides or should reside if it doesn't exist already.
      # @api private
      def ezbake_stage project_name, project_param_string=nil,
                       ezbake_dir="tmp/ezbake"
        ezbake_tools_available?
        #conditionally_clone "gitmirror@github.delivery.puppetlabs.net:puppetlabs-ezbake.git",
        #                    ezbake_dir
        # TODO: will need removal before merging, since we'll want to
        # work against a shipped version of ezbake
        conditionally_clone "git@github.com:kbarber/ezbake.git",
                            ezbake_dir, "pdb-1034-ezbake-pr-testing"

        # If it was not already passed through, try retreiving the project
        # version from the local repository in cwd.
        if project_param_string.nil?
          project_param_string = "#{project_name}-version=#{ezbake_lein_project_version}"
        end

        # Get the absolute path to the local repo
        m2_repo = File.join(Dir.pwd, 'tmp', 'm2-local')

        lein_prefix = 'lein update-in : assoc :local-repo "\"' +
                      m2_repo + '\"" --'

        # Install the PuppetDB jar into the local repository
        ezbake_local_cmd "#{lein_prefix} install",
                         :throw_on_failure => true

        Dir.chdir(ezbake_dir) do
          # TODO: disabled this to test new lein plugin

          # ezbake_local_cmd "#{lein_prefix} run -- stage #{project_name} #{project_param_string}",
          #                  :throw_on_failure => true
          # TODO: here we compile a development version of the plugin,
          # but for prod we'll need to work something else out
          ezbake_local_cmd "#{lein_prefix} install",
                            :throw_on_failure => true
        end

        # TODO: should we also be passing through project_name &
        # project_param_string if its provided? I'm guessing this is
        # true for other projects, but we should allow nil for the
        # sake of all-in-one projects like PDB.
        ezbake_local_cmd "#{lein_prefix} with-profile ezbake ezbake build",
                         :throw_on_failure => true


        #staging_dir = File.join(ezbake_dir, 'target', 'staging')
        staging_dir = File.join('target','staging')
        Dir.chdir(staging_dir) do
          ezbake_local_cmd 'rake package:bootstrap'

          load 'ezbake.rb'
          ezbake = EZBake::Config
          ezbake[:package_version] = `echo -n $(rake pl:print_build_param[ref] | tail -n 1)`
          EZBakeUtils.config = ezbake
        end
      end

      # Executes a local command using system, logging the prepared command
      #
      # @param [String] cmd command to execute
      # @param [Hash] opts options
      # @option opts [bool] :throw_on_failure If true, throws an
      #   exception if the exit code is non-zero. Defaults to false.
      # @return [bool] true if exit == 0 false if otherwise
      # @raise [RuntimeError] if :throw_on_failure is true and
      #   command fails
      # @api private
      def ezbake_local_cmd cmd, opts={}
        opts = {
          :throw_on_failure => false,
        }.merge(opts)

        logger.notify "localhost $ #{cmd}"
        result = system cmd
        if opts[:throw_on_failure] && result == false
          raise RuntimeError, "Command failure #{cmd}"
        end
        result
      end

      # Retrieve the tarball installation name. This is the name of
      # the tarball without the .tar.gz extension, and the name of the
      # path where it will unpack to.
      #
      # @return [String] name of the tarball and directory
      # @api private
      def ezbake_install_name
        ezbake = ezbake_config
        project_package_version = ezbake[:package_version]
        project_name = ezbake[:project]
        "%s-%s" % [ project_name, project_package_version ]
      end

      # Returns the full path to the installed software on the remote host.
      #
      # This only returns the path, it doesn't work out if its installed or
      # not.
      #
      # @return [String] path to the installation dir
      # @api private
      def ezbake_install_dir
        "/root/#{ezbake_install_name}"
      end

      # A make helper that wraps the execution of make in the proper
      # ezbake installation directory.
      #
      # @param [Host] host Host to run make on
      # @param [String] task Task to execute with make
      # @param [Hash] env_args Options to pass to make as environment vars
      # @api private
      def ezbake_make host, task, env_args={}
        env_args = {
          "prefix" => "/usr",
          "initdir" => "/etc/init.d",
          "unitdir" => "/usr/lib/systemd/system",
        }.merge(env_args)

        cd_to_package_dir = "cd #{ezbake_install_dir}; "

        env = ""
        if not env_args.empty?
          env = "env " + env_args.map {|k, v| "#{k}=#{v} "}.join(' ')
        end

        cmd_prefix = cd_to_package_dir + env

        on host, cmd_prefix + "make -e #{task}"
      end

      # Only clone from given git URI if there is no existing git clone at the
      # given local_path location.
      #
      # @param [String] upstream_uri git URI
      # @param [String] local_path path to conditionally install to
      # @api private
      def conditionally_clone upstream_uri, local_path, branch="origin/HEAD"
        ezbake_tools_available?
        if ezbake_local_cmd "git --work-tree=#{local_path} --git-dir=#{local_path}/.git status"
          ezbake_local_cmd "git --work-tree=#{local_path} --git-dir=#{local_path}/.git fetch origin"
          ezbake_local_cmd "git --work-tree=#{local_path} --git-dir=#{local_path}/.git checkout #{branch}"
        else
          parent_dir = File.dirname(local_path)
          FileUtils.mkdir_p(parent_dir)
          ezbake_local_cmd "git clone #{upstream_uri} #{local_path}"
          ezbake_local_cmd "git --work-tree=#{local_path} --git-dir=#{local_path}/.git checkout #{branch}"
        end
      end

    end
  end
end
