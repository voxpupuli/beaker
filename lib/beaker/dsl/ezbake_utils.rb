require 'beaker/dsl/install_utils'

module Beaker
  module DSL
    #
    # This module contains methods to assist in installing projects from source
    # that use ezbake for packaging.
    #
    # @api dsl
    module EZBakeUtils
      class << self
        attr_accessor :config
      end

      # Return the ezbake config.
      #
      def ezbake_config
        EZBakeUtils.config
      end

      # Prepares a staging directory for the specified project.
      #
      # @param [String] project_name The name of the ezbake project being worked
      #                              on.
      # @param [String] project_version The desired version of the primary
      #                                 subproject being worked.
      # @param [String] ezbake_dir The local directory where the ezbake project
      #                            resides or should reside if it doesn't exist
      #                            already.
      #
      def ezbake_stage project_name, project_version, ezbake_dir="tmp/ezbake"
        conditionally_clone "git@github.com:puppetlabs/ezbake.git", ezbake_dir

        package_version = ''
        Dir.chdir(ezbake_dir) do
          `lein run -- stage #{project_name} #{project_name}-version=#{project_version}`
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
        platform = host['platform']
        ezbake = ezbake_config

        case platform
        when /^(fedora|el|centos)-(\d+)-(.+)$/
          variant = (($1 == 'centos')? 'el' : $1)
          version = $2
          arch = $3

          dependency_list = ezbake[:redhat][:additional_dependencies]
          dependency_list.each do |dependency|
            package_name, blah, package_version = dependency.split
            install_package_version host, package_name, package_version
          end

        when /^(debian|ubuntu)-([^-]+)-(.+)$/
          variant = $1
          version = $2
          arch = $3

          dependency_list = ezbake[:debian][:additional_dependencies]
          dependency_list.each do |dependency|
            dependency = dependency.split
            package_name = dependency[0]
            package_version = dependency[2].chop # ugh
            install_package_version host, package_name, package_version
          end

        else
          raise "No repository installation step for #{platform} yet..."
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
      # @param [String] project_version The version of the project specified by
      # project_name which is to be built and installed on the remote host.
      # @param [String] ezbake_dir The directory to which ezbake should be
      # cloned; alternatively, if ezbake is already at that directory, it will
      # be updated from its github master before any ezbake operations are
      # performed.
      #
      def install_from_ezbake host, project_name, project_version, ezbake_dir='tmp/ezbake'
        if not ezbake_config
          ezbake_stage project_name, project_version
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
        make_env = "env prefix=/usr confdir=/etc rundir=/var/run/#{project_name} "
        make_env += "initdir=/etc/init.d "
        on host, cd_to_package_dir + make_env + "make -e install-" + project_name

        # install init scripts and default settings, perform additional preinst
        # TODO: figure out a better way to install init scripts and defaults
        platform = host['platform']
        case platform
          when /^(fedora|el|centos)-(\d+)-(.+)$/
            make_env += "defaultsdir=/etc/sysconfig "
            on host, cd_to_package_dir + make_env + "make -e install-rpm-sysv-init"
          when /^(debian|ubuntu)-([^-]+)-(.+)$/
            make_env += "defaultsdir=/etc/defaults "
            on host, cd_to_package_dir + make_env + "make -e install-deb-sysv-init"
          else
            raise "No ezbake installation step for #{platform} yet..."
        end
      end

      # @!visibility private
      def conditionally_clone(upstream_uri, local_path)
        if system "git --work-tree=#{local_path} --git-dir=#{local_path}/.git status"
          system "git --work-tree=#{local_path} --git-dir=#{local_path}/.git pull"
        else
          parent_dir = File.dirname(local_path)
          FileUtils.mkdir_p(parent_dir)
          system "git clone #{upstream_uri} #{local_path}"
        end
      end

    end
  end
end
