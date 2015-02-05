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
      # @api dsl
      def install_from_ezbake host
        ezbake_validate_support host
        ezbake_tools_available?
        install_ezbake_tarball_on_host host
        ezbake_installsh host, "service"
      end

      # Installs termini with given name and version on remote host.
      #
      # @param [Host] host A single remote host on which to install the
      #   specified leiningen project.
      # @api dsl
      def install_termini_from_ezbake host
        ezbake_validate_support host
        ezbake_tools_available?
        install_ezbake_tarball_on_host host
        ezbake_installsh host, "termini"
      end

      # Install a development version of ezbake into the local m2 repository
      #
      # This can be useful if you want to work on a development branch of
      # ezbake that hasn't been released yet. Ensure your project dependencies
      # in your development branch include a reference to the -SNAPSHOT
      # version of the project for it to successfully pickup a pre-shipped
      # version of ezbake.
      #
      # @param url [String] git url
      # @param branch [String] git branch
      # @api dsl
      def ezbake_dev_build url = "git@github.com:puppetlabs/ezbake.git",
                           branch = "master"
        ezbake_dir = 'tmp/ezbake'
        conditionally_clone url, ezbake_dir, branch
        lp = ezbake_lein_prefix

        Dir.chdir(ezbake_dir) do
          ezbake_local_cmd "#{lp} install",
                            :throw_on_failure => true
        end
      end

      # @!endgroup

      class << self
        attr_accessor :config
      end

      # @!group Private helpers

      # Test for support in one place
      #
      # @param [Host] host host to check for support
      # @raise [RuntimeError] if OS is not supported
      # @api private
      def ezbake_validate_support host
        variant, version, _, _ = host['platform'].to_array
        unless variant =~ /^(fedora|el|centos|debian|ubuntu)$/
          raise RuntimeError,
                "No support for #{variant} within ezbake_utils ..."
        end
      end

      # Build, copy & unpack tarball on remote host
      #
      # @param [Host] host installation destination
      # @api private
      def install_ezbake_tarball_on_host host
        if not ezbake_config
          ezbake_stage
        end

        # Skip installation if the remote directory exists
        result = on host, "test -d #{ezbake_install_dir}", :acceptable_exit_codes => [0, 1]
        return if result.exit_code == 0

        ezbake_staging_dir = File.join('target', 'staging')
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

      LOCAL_COMMANDS_REQUIRED = [
        ['leiningen', 'lein --version', nil],
        ['lein-pprint', 'lein with-profile ci pprint :version',
          'Must have lein-pprint installed under the :ci profile.'],
        ['java', 'java -version', nil],
        ['git', 'git --version', nil],
        ['rake', 'rake --version', nil],
      ]

      # Checks given host for the tools necessary to perform
      # install_from_ezbake.
      #
      # @raise [RuntimeError] if tool is not found
      # @api private
      def ezbake_tools_available?
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

      # Return the ezbake config.
      #
      # @return [Hash] configuration for ezbake, usually from ezbake.rb
      # @api private
      def ezbake_config
        EZBakeUtils.config
      end

      # Returns a leiningen prefix with local m2 repo capability
      #
      # @return [String] lein prefix command that uses a local build
      #   m2 repository.
      # @api private
      def ezbake_lein_prefix
        # Get the absolute path to the local repo
        m2_repo = File.join(Dir.pwd, 'tmp', 'm2-local')

        'lein update-in : assoc :local-repo "\"' + m2_repo + '\"" --'
      end

      # Prepares a staging directory for the specified project.
      #
      # @api private
      def ezbake_stage
        # Install the PuppetDB jar into the local repository
        ezbake_local_cmd "#{ezbake_lein_prefix} install",
                         :throw_on_failure => true

        # Run ezbake stage
        ezbake_local_cmd "#{ezbake_lein_prefix} with-profile ezbake ezbake stage",
                         :throw_on_failure => true

        # Boostrap packaging, and grab configuration info from project
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

      # A helper that wraps the execution of install.sh in the proper
      # ezbake installation directory.
      #
      # @param [Host] host Host to run install.sh on
      # @param [String] task Task to execute with install.sh
      # @api private
      def ezbake_installsh host, task=""
        on host, "cd #{ezbake_install_dir}; bash install.sh #{task}"
      end

      # Only clone from given git URI if there is no existing git clone at the
      # given local_path location.
      #
      # @param [String] upstream_uri git URI
      # @param [String] local_path path to conditionally install to
      # @param [String] branch to checkout
      # @api private
      def conditionally_clone upstream_uri, local_path, branch="origin/HEAD"
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
