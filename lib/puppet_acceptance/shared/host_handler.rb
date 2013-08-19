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

      def hosts_with_role(hosts, desired_role = nil)
        hosts.select do |host|
          desired_role.nil? or host['roles'].include?(desired_role.to_s)
        end
      end 

      def only_host_with_role(hosts, role)
        a_host = hosts_with_role(hosts, role)
        raise "There can be only one #{role}, but I found:" +
          "#{a_host.map {|h| h.to_s } }" unless a_host.length == 1
        a_host.first 
      end
    end
  end
end
