require 'beaker/dsl/install_utils'

module Beaker
  module DSL
    #
    # This module contains methods to assist in installing projects from source
    # that use ezbake for packaging.
    #
    # @api dsl
    module EZBakeUtils

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

      # Return the ezbake config.
      #
      def ezbake_config
        EZBakeUtils.config
      end

      # Checks given host for the tools necessary to perform
      # install_from_ezbake. If no host is given then check the local machine
      # for necessary available tools. If a tool is not found, then raise
      # RuntimeError.
      #
      def ezbake_tools_available? host = nil
        if host
          REMOTE_PACKAGES_REQUIRED.each do |package_name|
            if not check_for_package host, package_name
              raise "Required package, #{package_name}, not installed on #{host}" 
            end
          end
        else
          LOCAL_COMMANDS_REQUIRED.each do |software_name, command, additional_error_message|
            if not system command
              error_message = "Must have #{software_name} installed on development system.\n"
              if additional_error_message
                error_message += additional_error_message
              end
              raise error_message
            end
          end
        end
      end

      # Prepares a staging directory for the specified project.
      #
      # @param [String] project_name The name of the ezbake project being worked
      #                              on.
      # @param [String] project_param_string Parameters to be passed to ezbake
      #                                      on the command line.
      # @param [String] ezbake_dir The local directory where the ezbake project
      #                            resides or should reside if it doesn't exist
      #                            already.
      #
      def ezbake_stage project_name, project_param_string, ezbake_dir="tmp/ezbake"
        ezbake_tools_available?
        conditionally_clone "gitmirror@github.delivery.puppetlabs.net:puppetlabs-ezbake.git", ezbake_dir

        package_version = ''
        Dir.chdir(ezbake_dir) do
          `lein run -- stage #{project_name} #{project_param_string}`
        end

        staging_dir = File.join(ezbake_dir, 'target/staging')
        Dir.chdir(staging_dir) do
          output = `rake package:bootstrap`
          load 'ezbake.rb'
          ezbake = EZBake::Config
          ezbake[:package_version] = `echo -n $(rake pl:print_build_param[ref] | tail -n 1)`
          EZBakeUtils.config = ezbake
        end
      end

      # Installs ezbake dependencies on given host.
      #
      # @param [Host] host A single remote host on which to install the
      # packaging dependencies of the ezbake project configuration currently in
      # Beaker::DSL::EZBakeUtils.config
      #
      def install_ezbake_deps host
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

        when /^(debian|ubuntu)$/
          dependency_list = ezbake[:debian][:additional_dependencies]
          dependency_list.each do |dependency|
            package_name, _, package_version = dependency.split
            if package_version
              package_version = package_version.chop
            end
            install_package host, package_name, package_version
          end

        else
          raise "No repository installation step for #{variant} yet..."
        end

      end

      # Installs leiningen project with given name and version on remote host.
      #
      # @param [Host] host A single remote host on which to install the
      # specified leiningen project.
      # @param [String] project_name The name of the project. In ezbake context
      # this is the name of both a subdirectory of the ezbake_dir/configs dir
      # and the name of the .clj file in that directory which contains the
      # project map used by ezbake to create the staging directory.
      # @param [String] project_param_string The version of the project specified by
      # project_name which is to be built and installed on the remote host.
      # @param [String] ezbake_dir The directory to which ezbake should be
      # cloned; alternatively, if ezbake is already at that directory, it will
      # be updated from its github master before any ezbake operations are
      # performed.
      #
      def install_from_ezbake host, project_name, project_param_string, env_args={}, ezbake_dir='tmp/ezbake'
        ezbake_tools_available? host

        if not ezbake_config
          ezbake_stage project_name, project_param_string
        end

        variant, _, _, _ = host['platform'].to_array

        case variant
        when /^(osx|windows|solaris|aix)$/
          raise "Beaker::DSL::EZBakeUtils unsupported platform: #{variant}"
        end

        ezbake = ezbake_config
        project_package_version = ezbake[:package_version]
        project_name = ezbake[:project]

        ezbake_staging_dir = File.join(ezbake_dir, "target/staging")

        remote_tarball = ""
        local_tarball = ""
        dir_name = ""

        Dir.chdir(ezbake_staging_dir) do
          output = `rake package:tar`

          pattern = "%s-%s"
          dir_name = pattern % [
            project_name,
            project_package_version
          ]
          local_tarball = "./pkg/" + dir_name + ".tar.gz"
          remote_tarball = "/root/" +  dir_name + ".tar.gz"

          scp_to host, local_tarball, remote_tarball
        end

        # untar tarball on host
        on host, "tar -xzf " + remote_tarball

        # "make" on target
        cd_to_package_dir = "cd /root/" + dir_name + "; "
        env = ""
        if not env_args.empty?
          env = "env " + env_args.map {|k, v| "#{k}=#{v} "}.join(' ')
        end
        on host, cd_to_package_dir + env + "make -e install-" + project_name

        # install init scripts and default settings, perform additional preinst
        # TODO: figure out a better way to install init scripts and defaults
        case variant
          when /^(fedora|el|centos)$/
            env += "defaultsdir=/etc/sysconfig "
            on host, cd_to_package_dir + env + "make -e install-rpm-sysv-init"
          when /^(debian|ubuntu)$/
            env += "defaultsdir=/etc/default "
            on host, cd_to_package_dir + env + "make -e install-deb-sysv-init"
          else
            raise "No ezbake installation step for #{variant} yet..."
        end
      end

      # Only clone from given git URI if there is no existing git clone at the
      # given local_path location.
      #
      # @!visibility private
      def conditionally_clone(upstream_uri, local_path)
        ezbake_tools_available?
        if system "git --work-tree=#{local_path} --git-dir=#{local_path}/.git status"
          system "git --work-tree=#{local_path} --git-dir=#{local_path}/.git fetch origin"
          system "git --work-tree=#{local_path} --git-dir=#{local_path}/.git checkout origin/HEAD"
        else
          parent_dir = File.dirname(local_path)
          FileUtils.mkdir_p(parent_dir)
          system "git clone #{upstream_uri} #{local_path}"
        end
      end

    end
  end
end
