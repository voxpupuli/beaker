module Beaker
  class Solaris < Beaker::Hypervisor

    def initialize(solaris_hosts, options)
      @options = options
      @logger = options[:logger]
      @hosts = solaris_hosts
      @fog_file = nil
      if File.exists?( @options[:dot_fog] )
        @fog_file = YAML.load_file( @options[:dot_fog] )
      end
      raise "Cant load #{@options[:dot_fog]} config" unless @fog_file

    end

    def provision
      hypername = @fog_file[:default][:solaris_hypervisor_server]
      vmpath    = @fog_file[:default][:solaris_hypervisor_vmpath]
      snappaths = @fog_file[:default][:solaris_hypervisor_snappaths]

      hyperopts = @options.dup
      hyperopts['HOSTS']  = {
          hypername => { 'platform' => 'solaris-11-sparc' }
      }

      @logger.notify "Connecting to hypervisor at #{hypername}"
      hypervisor = Beaker::Host.create( hypername, hyperopts )
      hypervisor[:user] = @fog_file[:default][:solaris_hypervisor_username] || hypervisor[:user]
      hypervisor[:ssh][:keys] = [@fog_file[:default][:solaris_hypervisor_keyfile]] || hypervisor[:ssh][:keys]

      @hosts.each do |host|
        vm_name = host['vmname'] || host.name
        #use the snapshot provided for this host
        snapshot = host['snapshot']

        @logger.notify "Reverting #{vm_name} to snapshot #{snapshot}"
        start = Time.now
        hypervisor.exec(Command.new("sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}@#{snapshot}"))
        snappaths.each do |spath|
          @logger.notify "Reverting #{vm_name}/#{spath} to snapshot #{snapshot}"
          hypervisor.exec(Command.new("sudo /sbin/zfs rollback -Rf #{vmpath}/#{vm_name}/#{spath}@#{snapshot}"))
        end
        time = Time.now - start
        @logger.notify "Spent %.2f seconds reverting" % time

        @logger.notify "Booting #{vm_name}"
        start = Time.now
        hypervisor.exec(Command.new("sudo /sbin/zoneadm -z #{vm_name} boot"))
        @logger.notify "Spent %.2f seconds booting #{vm_name}" % (Time.now - start)
      end
      hypervisor.close
    end

    def cleanup
      @logger.notify "No cleanup for solaris boxes"
    end

  end
end
