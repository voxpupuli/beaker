require 'beaker/ssh_connection'
module Beaker
  class Fusion < Beaker::Hypervisor

    def initialize(fusion_hosts, options)
      require 'rubygems' unless defined?(Gem)
      begin
        require 'fission'
      rescue LoadError
        raise "Unable to load fission, please ensure it is installed!"
      end
      @logger = options[:logger]
      @options = options
      @hosts = fusion_hosts
      #check preconditions for fusion
      @hosts.each do |host|
        raise "You must specify a snapshot for Fusion instances, no snapshot defined for #{host.name}!" unless host["snapshot"]
      end
      @fission = Fission::VM
    end

    def provision
      available = @fission.all.data.collect{|vm| vm.name}.sort.join(", ")
      @logger.notify "Available VM names: #{available}"

      @hosts.each do |host|
        vm_name = host["vmname"] || host.name
        vm = @fission.new vm_name
        raise "Could not find VM '#{vm_name}' for #{host.name}!" unless vm.exists?

        vm_snapshots = vm.snapshots.data
        if vm_snapshots.nil? or vm_snapshots.empty?
          raise "No snapshots available for VM #{host.name} (vmname: '#{vm_name}')"
        end

        available_snapshots = vm_snapshots.sort.join(", ")
        @logger.notify "Available snapshots for #{host.name}: #{available_snapshots}"
        snap_name = host["snapshot"]
        raise "Could not find snapshot '#{snap_name}' for host #{host.name}!" unless vm.snapshots.data.include? snap_name

        @logger.notify "Reverting #{host.name} to snapshot '#{snap_name}'"
        start = Time.now
        vm.revert_to_snapshot snap_name
        while vm.running?.data
          sleep 1
        end
        time = Time.now - start
        @logger.notify "Spent %.2f seconds reverting" % time

        @logger.notify "Resuming #{host.name}"
        start = Time.now
        vm.start :headless => true
        until vm.running?.data
          sleep 1
        end
        time = Time.now - start
        @logger.notify "Spent %.2f seconds resuming VM" % time

        begin
          try_ssh_connection(host.name, host['user'], host['ssh'])
        rescue *Beaker::SshConnection::RETRYABLE_EXCEPTIONS => e
          @logger.notify "Obtaining IP information for #{host.name}"
          ip = vm.network_info.data[vm.network_info.data.keys[0]]['ip_address']
          if not ip
            raise "Unable to connect to vm via hostname #{host.name}, and ip address is unavailable via vmname #{host[:vmname]}."
          else
            @logger.notify "Found IP address #{ip} for #{host.name}. Setting host.ip value"
            begin
              try_ssh_connection(ip, host['user'], host['ssh'])
            rescue *Beaker::SshConnection::RETRYABLE_EXCEPTIONS => e
              raise "Unable to connect to vm via IP address #{ip} for #{host.name}"
            end
            host[:ip] = ip
          end
          set_hostnames @hosts, @options

        end
      end
      hack_etc_hosts @hosts, @options

      end #revert_fusion

      def cleanup
        @logger.notify "No cleanup for fusion boxes"
      end

      # Set the hostname of all instances to be the hostname defined in the
      # beaker configuration.
      #
      # @param [Host, Array<Host>] hosts An array of hosts to act upon
      # @param [Hash{Symbol=>String}] opts Options to alter execution.
      #
      # @return [void]
      # @api private
      def set_hostnames hosts, opts
        hosts.each do |host|
          if host['platform'] =~ /el-7/
            # on el-7 hosts, the hostname command doesn't "stick" randomly
            host.exec(Command.new("hostnamectl set-hostname #{host.name}"))
          else
            host.exec(Command.new("hostname #{host.name}"))
          end
        end
      end

      # Attempt SSH connection to given host
      #
      # @param host [String] the hostname or IP address to connect to
      # @param user [String] the username to use for the connection
      # @param ssh [Hash] SSH parameters to use for the connection
      #
      # @return [void]
      # @api private
      def try_ssh_connection(host, user, ssh)
        @logger.notify "Attempting SSH connection to #{host}"
        Net::SSH.start(host,user,ssh)
      end
  end
end
