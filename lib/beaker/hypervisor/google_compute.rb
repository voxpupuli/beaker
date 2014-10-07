require 'time'

module Beaker
  #Beaker support for the Google Compute Engine.
  class GoogleCompute < Beaker::Hypervisor

    SLEEPWAIT = 5
    #number of hours before an instance is considered a zombie
    ZOMBIE = 3

    #Create the array of metaData, each member being a hash with a :key and a :value.  Sets
    #:department, :project and :jenkins_build_url.
    def format_metadata
      [ {:key => :department, :value => @options[:department]},
        {:key => :project, :value => @options[:project]},
        {:key => :jenkins_build_url, :value => @options[:jenkins_build_url]} ].delete_if { |member| member[:value].nil? or member[:value].empty?}
    end

    #Create a new instance of the Google Compute Engine hypervisor object
    #@param [<Host>] google_hosts The array of google hosts to provision, may ONLY be of platforms /centos-6-.*/ and
    #                             /debian-7-.*/.  We currently only support the Google Compute provided templates.
    #@param [Hash{Symbol=>String}] options The options hash containing configuration values
    #@option options [String] :gce_project The Google Compute Project name to connect to
    #@option options [String] :gce_keyfile The location of the Google Compute service account keyfile
    #@option options [String] :gce_password The password for the Google Compute service account key
    #@option options [String] :gce_email The email address for the Google Compute service account
    #@option options [String] :gce_machine_type A Google Compute machine type used to create instances, defaults to n1-highmem-2
    #@option options [Integer] :timeout The amount of time to attempt execution before quiting and exiting with failure
    def initialize(google_hosts, options)
      require 'beaker/hypervisor/google_compute_helper'
      @options = options
      @logger = options[:logger]
      @hosts = google_hosts
      @firewall = ''
      @gce_helper = GoogleComputeHelper.new(options)
    end

    #Create and configure virtual machines in the Google Compute Engine, including their associated disks and firewall rules
    #Currently ONLY supports Google Compute provided templates of CENTOS-6 and DEBIAN-7
    def provision
      try = 1
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

      #get machineType resource, used by all instances
      machineType = @gce_helper.get_machineType(start, attempts)

      #set firewall to open pe ports
      network = @gce_helper.get_network(start, attempts)
      @firewall = generate_host_name
      @gce_helper.create_firewall(@firewall, network, start, attempts)

      @logger.debug("Created Google Compute firewall #{@firewall}")


      @hosts.each do |host|
        gplatform = Platform.new(host[:image] || host[:platform])
        img = @gce_helper.get_latest_image(gplatform, start, attempts)
        host['diskname'] = generate_host_name
        disk = @gce_helper.create_disk(host['diskname'], img, start, attempts)
        @logger.debug("Created Google Compute disk for #{host.name}: #{host['diskname']}")

        #create new host name
        host['vmhostname'] = generate_host_name
        #add a new instance of the image
        instance = @gce_helper.create_instance(host['vmhostname'], img, machineType, disk, start, attempts)
        @logger.debug("Created Google Compute instance for #{host.name}: #{host['vmhostname']}")

        #add metadata to instance, if there is any to set
        mdata = format_metadata
        if not mdata.empty?
          @gce_helper.setMetadata_on_instance(host['vmhostname'], instance['metadata']['fingerprint'],
                                              mdata,
                                              start, attempts)
          @logger.debug("Added tags to Google Compute instance #{host.name}: #{host['vmhostname']}")
        end

        #get ip for this host
        host['ip'] = instance['networkInterfaces'][0]['accessConfigs'][0]['natIP']

        #configure ssh
        default_user = host['user']
        host['user'] = 'google_compute'

        disable_se_linux(host, @options)
        copy_ssh_to_root(host, @options)
        enable_root_login(host, @options)
        host['user'] = default_user

        #shut down connection, will reconnect on next exec
        host.close

        @logger.debug("Instance ready: #{host['vmhostname']} for #{host.name}}")
      end
    end

    #Shutdown and destroy virtual machines in the Google Compute Engine, including their associated disks and firewall rules
    def cleanup()
      attempts = @options[:timeout].to_i / SLEEPWAIT
      start = Time.now

      @gce_helper.delete_firewall(@firewall, start, attempts)

      @hosts.each do |host|
        @gce_helper.delete_instance(host['vmhostname'], start, attempts)
        @logger.debug("Deleted Google Compute instance #{host['vmhostname']} for #{host.name}")
        @gce_helper.delete_disk(host['diskname'], start, attempts)
        @logger.debug("Deleted Google Compute disk #{host['diskname']} for #{host.name}")
      end

    end

    #Shutdown and destroy Google Compute instances (including their associated disks and firewall rules)
    #that have been alive longer than ZOMBIE hours.
    def kill_zombies(max_age = ZOMBIE)
      now = start = Time.now
      attempts = @options[:timeout].to_i / SLEEPWAIT

      #get rid of old instances
      instances = @gce_helper.list_instances(start, attempts)
      if instances
        instances.each do |instance|
          created = Time.parse(instance['creationTimestamp'])
          alive = (now - created ) /60 /60
          if alive >= max_age
            #kill it with fire!
            @logger.debug("Deleting zombie instance #{instance['name']}")
            @gce_helper.delete_instance( instance['name'], start, attempts )
          end
        end
      else
        @logger.debug("No zombie instances found")
      end
      #get rid of old disks
      disks = @gce_helper.list_disks(start, attempts)
      if disks
        disks.each do |disk|
          created = Time.parse(disk['creationTimestamp'])
          alive = (now - created ) /60 /60
          if alive >= max_age
            #kill it with fire!
            @logger.debug("Deleting zombie disk #{disk['name']}")
            @gce_helper.delete_disk( disk['name'], start, attempts )
          end
        end
      else
        @logger.debug("No zombie disks found")
      end
      #get rid of non-default firewalls
      firewalls = @gce_helper.list_firewalls( start, attempts)

      if firewalls and not firewalls.empty?
        firewalls.each do |firewall|
          @logger.debug("Deleting non-default firewall #{firewall['name']}")
          @gce_helper.delete_firewall( firewall['name'], start, attempts )
        end
      else
        @logger.debug("No zombie firewalls found")
      end

    end

  end
end
