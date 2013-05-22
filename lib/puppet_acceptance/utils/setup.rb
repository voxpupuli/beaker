module PuppetAcceptance
  class SetupWrapper
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
      @logger.debug "Get ip address of Master #{master}"
      if master['platform'].include? 'solaris'
        stdout = master.exec(HostCommand.new("ifconfig -a inet| awk '/broadcast/ {print $2}' | cut -d/ -f1 | head -1")).stdout
      else
        stdout = master.exec(HostCommand.new("ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1")).stdout
      end
      ip=stdout.chomp

      path = "/etc/hosts"
      if master['platform'].include? 'solaris'
        path = "/etc/inet/hosts"
      end

      @logger.debug "Update %s on #{master}" % path
      # Preserve the mode the easy way...
      master.exec(HostCommand.new("cp %s %s.old" % [path, path]))
      master.exec(HostCommand.new("cp %s %s.new" % [path, path]))
      master.exec(HostCommand.new("grep -v '#{ip} #{master}' %s > %s.new" % [path, path]))
      master.exec(HostCommand.new("echo '#{ip} #{master}' >> %s.new" % path))
      master.exec(HostCommand.new("mv %s.new %s" % [path, path]))
    end

    def set_rvm_of_ruby
      if @options[:rvm].include? 'system'
        @logger.notify "Setting Ruby version to sytem default"
        @hosts.each do |host|
          host.exec(HostCommand.new("rvm --default system"))
        end
      elsif @options[:rvm].include? 'skip'
        @logger.notify "Skipping set ruby version"
        return
      else
        @logger.notify "Setting Ruby version"
        @hosts.each do |host|
          host.exec(HostCommand.new("rvm --default use #{@options[:rvm]}"))
        end
      end
    end

  end
end
