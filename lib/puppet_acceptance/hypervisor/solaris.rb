module PuppetAcceptance 
  class Solaris < PuppetAcceptance::Hypervisor

    def initialize(solaris_hosts, options, config)
      @options = options
      @config = config['CONFIG'].dup
      @logger = options[:logger]
      @solaris_hosts = solaris_hosts
      fog_file = nil
      if File.exists?( File.join(ENV['HOME'], '.fog') )
        fog_file = YAML.load_file( File.join(ENV['HOME'], '.fog') )
      end
      raise "Cant load ~/.fog config" unless fog_file

      hypername = fog_file[:default][:solaris_hypervisor_server]
      vmpath    = fog_file[:default][:solaris_hypervisor_vmpath]
      snappaths = fog_file[:default][:solaris_hypervisor_snappaths]

      hyperconf = {
        'HOSTS'  => {
          hypername => { 'platform' => 'solaris-11-sparc' }
        },
        'CONFIG' => {
          'user' => fog_file[:default][:solaris_hypervisor_username] || ENV['USER'],
          'ssh'  => {
            :keys => fog_file[:default][:solaris_hypervisor_keyfile] || "#{ENV['HOME']}/.ssh/id_rsa"
          }
        }
      }

      hyperconfig = PuppetAcceptance::TestConfig.new( hyperconf, @options )

      @logger.notify "Connecting to hypervisor at #{hypername}"
      hypervisor = PuppetAcceptance::Host.create( hypername, @options, hyperconfig )

      @solaris_hosts.each do |host|
        vm_name = host['vmname'] || host.name
        #use the snapshot provided for this host, otherwise use the snapshot provided for this test run
        snapshot = host['snapshot'] || @options[:snapshot]


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
