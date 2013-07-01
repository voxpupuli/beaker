module PuppetAcceptance 
  module Shared
    module HostHandler

      # NOTE: this code is shamelessly stolen from facter's 'domain' fact, but
      # we don't have access to facter at this point in the run.  Also, this
      # utility method should perhaps be moved to a more central location in the
      # framework.
      def get_domain_name(host)
        domain = nil
        search = nil
        resolv_conf = host.exec(Command.new("cat /etc/resolv.conf")).stdout
        resolv_conf.each_line { |line|
          if line =~ /^\s*domain\s+(\S+)/
            domain = $1
          elsif line =~ /^\s*search\s+(\S+)/
            search = $1
          end
        }
        return domain if domain
        return search if search
      end

      def get_ip(host)
        host.exec(Command.new("ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1")).stdout.chomp
      end

      def set_etc_hosts(host, etc_hosts)
        host.exec(Command.new("echo '#{etc_hosts}' > /etc/hosts"))
      end
    end
  end
end
