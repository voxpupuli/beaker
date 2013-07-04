module PuppetAcceptance
  module Utils
    class SetupHelper

      def initialize(options, hosts)
        @options = options.dup
        @hosts = hosts
        @logger = options[:logger]
      end

      def find_masters(hosts)
        hosts.select do |host|
          host['roles'].include?("master")
        end
      end

      def find_only_master(hosts)
        m = find_masters(hosts)
        raise "too many masters, expected one but found #{m.map {|h| h.to_s }}" unless m.length == 1
        m.first
      end

      def add_master_entry
        @logger.notify "Add Master entry to /etc/hosts"
        master = find_only_master(@hosts)
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

        path = "/etc/hosts"
        if master['platform'].include? 'solaris'
          path = "/etc/inet/hosts"
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
        script = "https://raw.github.com/puppetlabs/puppetlabs-sshkeys/master/templates/scripts/manage_root_authorized_keys"
        setup_root_authorized_keys = "curl -k -o - #{script} | %s"
        @logger.notify "Sync root authorized_keys from github"
        @hosts.each do |host|
          # Allow all exit code, as this operation is unlikely to cause problems if it fails.
          if host['platform'].include? 'solaris'
            host.exec(Command.new(setup_root_authorized_keys % "bash"), :acceptable_exit_codes => (0..255))
          else
            host.exec(Command.new(setup_root_authorized_keys % "env PATH=/usr/gnu/bin:$PATH bash"), :acceptable_exit_codes => (0..255))
          end
        end
      rescue => e
        report_and_raise(@logger, e, "sync_root_keys")
      end

    end
  end
end
