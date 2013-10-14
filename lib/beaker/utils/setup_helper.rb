module Beaker
  module Utils
    class SetupHelper
      ETC_HOSTS_PATH = "/etc/hosts"
      ETC_HOSTS_PATH_SOLARIS = "/etc/inet/hosts"
      ROOT_KEYS_SCRIPT = "https://raw.github.com/puppetlabs/puppetlabs-sshkeys/master/templates/scripts/manage_root_authorized_keys"
      ROOT_KEYS_SYNC_CMD = "curl -k -o - #{ROOT_KEYS_SCRIPT} | %s"

      def initialize(options, hosts)
        @options = options.dup
        @hosts = hosts
        @logger = options[:logger]
      end

      def add_master_entry
        @logger.notify "Add Master entry to /etc/hosts"
        master = only_host_with_role(@hosts, :master)
        if master["hypervisor"] and master["hypervisor"] =~ /vagrant/
          @logger.debug "Don't update master entry on vagrant masters"
          return
        end
        @logger.debug "Get ip address of Master #{master}"
        if master['platform'].include? 'solaris'
          stdout = master.exec(Command.new("ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1")).stdout
        else
          stdout = master.exec(Command.new("ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1")).stdout
        end
        ip=stdout.chomp

        path = ETC_HOSTS_PATH
        if master['platform'].include? 'solaris'
          path = ETC_HOSTS_PATH_SOLARIS
        end

        @logger.debug "Update %s on #{master}" % path
        # Preserve the mode the easy way...
        master.exec(Command.new("cp %s %s.old" % [path, path]))
        master.exec(Command.new("cp %s %s.new" % [path, path]))
        master.exec(Command.new("grep -v '#{ip} #{master}' %s > %s.new" % [path, path]))
        master.exec(Command.new("echo '#{ip} #{master}' >> %s.new" % path))
        master.exec(Command.new("mv %s.new %s" % [path, path]))
      rescue => e
        report_and_raise(@logger, e, "add_master_entry")
      end

      def sync_root_keys
        # JJM This step runs on every system under test right now.  We're anticipating
        # issues on Windows and maybe Solaris.  We will likely need to filter this step
        # but we're deliberately taking the approach of "assume it will work, fix it
        # when reality dictates otherwise"
        @logger.notify "Sync root authorized_keys from github"
        @hosts.each do |host|
          # Allow all exit code, as this operation is unlikely to cause problems if it fails.
          if host['platform'].include? 'solaris'
            host.exec(Command.new(ROOT_KEYS_SYNC_CMD % "bash"), :acceptable_exit_codes => (0..255))
          else
            host.exec(Command.new(ROOT_KEYS_SYNC_CMD % "env PATH=/usr/gnu/bin:$PATH bash"), :acceptable_exit_codes => (0..255))
          end
        end
      rescue => e
        report_and_raise(@logger, e, "sync_root_keys")
      end

    end
  end
end
