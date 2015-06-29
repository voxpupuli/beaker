require 'aws/ec2'
require 'set'
require 'zlib'
require 'beaker/hypervisor/ec2_helper'

module Beaker
  # This is an alternate EC2 driver that implements direct API access using
  # Amazon's AWS-SDK library: {http://aws.amazon.com/documentation/sdkforruby/ SDK For Ruby}
  #
  # It is built for full control, to reduce any other layers beyond the pure
  # vendor API.
  class AwsSdk < Beaker::Hypervisor
    ZOMBIE = 3 #anything older than 3 hours is considered a zombie
    PING_SECURITY_GROUP_NAME = 'beaker-ping'

    # Initialize AwsSdk hypervisor driver
    #
    # @param [Array<Beaker::Host>] hosts Array of Beaker::Host objects
    # @param [Hash<String, String>] options Options hash
    def initialize(hosts, options)
      @hosts = hosts
      @options = options
      @logger = options[:logger]

      # Get fog credentials from the local .fog file
      creds = load_fog_credentials(@options[:dot_fog])

      config = {
        :access_key_id => creds[:access_key],
        :secret_access_key => creds[:secret_key],
        :logger => Logger.new($stdout),
        :log_level => :debug,
        :log_formatter => AWS::Core::LogFormatter.colored,
        :max_retries => 12,
      }
      AWS.config(config)

      @ec2 = AWS::EC2.new()
    end

    # Provision all hosts on EC2 using the AWS::EC2 API
    #
    # @return [void]
    def provision
      start_time = Time.now

      # Perform the main launch work
      launch_all_nodes()

      # Add metadata tags to each instance
      add_tags()

      # Grab the ip addresses and dns from EC2 for each instance to use for ssh
      populate_dns()

      #enable root if user is not root
      enable_root_on_hosts()

      # Set the hostname for each box
      set_hostnames()

      # Configure /etc/hosts on each host
      configure_hosts()

      @logger.notify("aws-sdk: Provisioning complete in #{Time.now - start_time} seconds")

      nil #void
    end

    # Kill all instances.
    #
    # @param instances [Enumerable<EC2::Instance>]
    # @return [void]
    def kill_instances(instances)
      instances.each do |instance|
        if !instance.nil? and instance.exists?
          @logger.notify("aws-sdk: killing EC2 instance #{instance.id}")
          instance.terminate
        end
      end
      nil
    end

    # Cleanup all earlier provisioned hosts on EC2 using the AWS::EC2 library
    #
    # It goes without saying, but a #cleanup does nothing without a #provision
    # method call first.
    #
    # @return [void]
    def cleanup
      # Provisioning should have set the host 'instance' values.
      kill_instances(@hosts.map{|h| h['instance']}.select{|x| !x.nil?})
      nil
    end

    # Print instances to the logger. Instances will be from all regions
    # associated with provided key name and limited by regex compared to
    # instance status. Defaults to running instances.
    #
    # @param [String] key The key_name to match for
    # @param [Regex] status The regular expression to match against the instance's status
    def log_instances(key = key_name, status = /running/)
      instances = []
      @ec2.regions.each do |region|
        @logger.debug "Reviewing: #{region.name}"
        @ec2.regions[region.name].instances.each do |instance|
          if (instance.key_name =~ /#{key}/) and (instance.status.to_s =~ status)
            instances << instance
          end
        end
      end
      output = ""
      instances.each do |instance|
        output << "#{instance.id} keyname: #{instance.key_name}, dns name: #{instance.dns_name}, private ip: #{instance.private_ip_address}, ip: #{instance.ip_address}, launch time #{instance.launch_time}, status: #{instance.status}\n"
      end
      @logger.notify("aws-sdk: List instances (keyname: #{key})")
      @logger.notify("#{output}")
    end

    # Provided an id return an instance object.
    # Instance object will respond to methods described here: {http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/Instance.html AWS Instance Object}.
    # @param [String] id The id of the instance to return
    # @return [AWS::EC2::Instance] An AWS::EC2 instance object
    def instance_by_id(id)
      @ec2.instances[id]
    end

    # Return all instances currently on ec2.
    # @see AwsSdk#instance_by_id
    # @return [Array<AWS::EC2::Instance>] An array of AWS::EC2 instance objects
    def instances
      @ec2.instances
    end

    # Provided an id return a VPC object.
    # VPC object will respond to methods described here: {http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/VPC.html AWS VPC Object}.
    # @param [String] id The id of the VPC to return
    # @return [AWS::EC2::VPC] An AWS::EC2 vpc object
    def vpc_by_id(id)
      @ec2.vpcs[id]
    end

    # Return all VPCs currently on ec2.
    # @see AwsSdk#vpc_by_id
    # @return [Array<AWS::EC2::VPC>] An array of AWS::EC2 vpc objects
    def vpcs
      @ec2.vpcs
    end

    # Provided an id return a security group object
    # Security object will respond to methods described here: {http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/SecurityGroup.html AWS SecurityGroup Object}.
    # @param [String] id The id of the security group to return
    # @return [AWS::EC2::SecurityGroup] An AWS::EC2 security group object
    def security_group_by_id(id)
      @ec2.security_groups[id]
    end

    # Return all security groups currently on ec2.
    # @see AwsSdk#security_goup_by_id
    # @return [Array<AWS::EC2::SecurityGroup>] An array of AWS::EC2 security group objects
    def security_groups
      @ec2.security_groups
    end

    # Shutdown and destroy ec2 instances idenfitied by key that have been alive
    # longer than ZOMBIE hours.
    #
    # @param [Integer] max_age The age in hours that a machine needs to be older than to be considered a zombie
    # @param [String] key The key_name to match for
    def kill_zombies(max_age = ZOMBIE, key = key_name)
      @logger.notify("aws-sdk: Kill Zombies! (keyname: #{key}, age: #{max_age} hrs)")
      #examine all available regions
      kill_count = 0
      time_now = Time.now.getgm #ec2 uses GM time
      @ec2.regions.each do |region|
        @logger.debug "Reviewing: #{region.name}"
        # Note: don't use instances.each here as that funtion doesn't allow proper rescue from error states
        instances = @ec2.regions[region.name].instances
        instances.each do |instance|
          begin
            if (instance.key_name =~ /#{key}/)
              @logger.debug "Examining #{instance.id} (keyname: #{instance.key_name}, launch time: #{instance.launch_time}, status: #{instance.status})"
              if ((time_now - instance.launch_time) >  max_age*60*60) and instance.status.to_s !~ /terminated/
                @logger.debug "Kill! #{instance.id}: #{instance.key_name} (Current status: #{instance.status})"
                instance.terminate()
                kill_count += 1
              end
            end
          rescue AWS::Core::Resource::NotFound, AWS::EC2::Errors => e
            @logger.debug "Failed to remove instance: #{instance.id}, #{e}"
          end
        end
      end

      @logger.notify "#{key}: Killed #{kill_count} instance(s)"
    end

    # Destroy any volumes marked 'available', INCLUDING THOSE YOU DON'T OWN!  Use with care.
    def kill_zombie_volumes
      # Occasionaly, tearing down ec2 instances leaves orphaned EBS volumes behind -- these stack up quickly.
      # This simply looks for EBS volumes that are not in use
      # Note: don't use volumes.each here as that funtion doesn't allow proper rescue from error states
      @logger.notify("aws-sdk: Kill Zombie Volumes!")
      volume_count = 0
      @ec2.regions.each do |region|
        @logger.debug "Reviewing: #{region.name}"
        volumes = @ec2.regions[region.name].volumes.map { |vol| vol.id }
        volumes.each do |vol|
          begin
            vol = @ec2.regions[region.name].volumes[vol]
            if ( vol.status.to_s =~ /available/ )
              @logger.debug "Tear down available volume: #{vol.id}"
              vol.delete()
              volume_count += 1
            end
          rescue AWS::EC2::Errors::InvalidVolume::NotFound => e
            @logger.debug "Failed to remove volume: #{vol.id}, #{e}"
          end
        end
      end
      @logger.notify "Freed #{volume_count} volume(s)"

    end

    # Create an EC2 instance for host, tag it, and return it.
    #
    # @return [AWS::EC2::Instance)]
    # @api private
    def create_instance(host, ami_spec, subnet_id)
      amitype = host['vmname'] || host['platform']
      amisize = host['amisize'] || 'm1.small'
      vpc_id = host['vpc_id'] || @options['vpc_id'] || nil

      if vpc_id and !subnet_id
        raise RuntimeError, "A subnet_id must be provided with a vpc_id"
      end

      # Use snapshot provided for this host
      image_type = host['snapshot']
      if not image_type
        raise RuntimeError, "No snapshot/image_type provided for EC2 provisioning"
      end
      ami = ami_spec[amitype]
      ami_region = ami[:region]

      # Main region object for ec2 operations
      region = @ec2.regions[ami_region]

      # If we haven't defined a vpc_id then we use the default vpc for the provided region
      if !vpc_id
        @logger.notify("aws-sdk: filtering available vpcs in region by 'isDefault")
        filtered_vpcs = region.client.describe_vpcs(:filters => [{:name => 'isDefault', :values => ['true']}])
        if !filtered_vpcs[:vpc_set].empty?
          vpc_id = filtered_vpcs[:vpc_set].first[:vpc_id]
        else #there's no default vpc, use nil
          vpc_id = nil
        end
      end

      # Grab the vpc object based upon provided id
      vpc = vpc_id ? region.vpcs[vpc_id] : nil

      # Grab image object
      image_id = ami[:image][image_type.to_sym]
      @logger.notify("aws-sdk: Checking image #{image_id} exists and getting its root device")
      image = region.images[image_id]
      if image.nil? and not image.exists?
        raise RuntimeError, "Image not found: #{image_id}"
      end

      @logger.notify("Image Storage Type: #{image.root_device_type}")

      # Transform the images block_device_mappings output into a format
      # ready for a create.
      block_device_mappings = []
      if image.root_device_type == :ebs
        orig_bdm = image.block_device_mappings()
        @logger.notify("aws-sdk: Image block_device_mappings: #{orig_bdm.to_hash}")
        orig_bdm.each do |device_name, rest|
          block_device_mappings << {
            :device_name => device_name,
            :ebs => {
              # Change the default size of the root volume.
              :volume_size => host['volume_size'] || rest[:volume_size],
              # This is required to override the images default for
              # delete_on_termination, forcing all volumes to be deleted once the
              # instance is terminated.
              :delete_on_termination => true,
            }
          }
        end
      end

      security_group = ensure_group(vpc || region, Beaker::EC2Helper.amiports(host))
      #check if ping is enabled
      ping_security_group = ensure_ping_group(vpc || region)

      msg = "aws-sdk: launching %p on %p using %p/%p%s" %
            [host.name, amitype, amisize, image_type,
             subnet_id ? ("in %p" % subnet_id) : '']
      @logger.notify(msg)
      config = {
        :count => 1,
        :image_id => image_id,
        :monitoring_enabled => true,
        :key_pair => ensure_key_pair(region),
        :security_groups => [security_group, ping_security_group],
        :instance_type => amisize,
        :disable_api_termination => false,
        :instance_initiated_shutdown_behavior => "terminate",
        :subnet => subnet_id,
      }
      config[:block_device_mappings] = block_device_mappings if image.root_device_type == :ebs
      region.instances.create(config)
    end

    # For each host, create an EC2 instance in one of the specified
    # subnets and push it onto instances_created.  Each subnet will be
    # tried at most once for each host, and more than one subnet may
    # be tried if capacity constraints are encountered.  Each Hash in
    # instances_created will contain an :instance and :host value.
    #
    # @param hosts [Enumerable<Host>]
    # @param subnets [Enumerable<String>]
    # @param ami_spec [Hash]
    # @param instances_created Enumerable<Hash{Symbol=>EC2::Instance,Host}>
    # @return [void]
    # @api private
    def launch_nodes_on_some_subnet(hosts, subnets, ami_spec, instances_created)
      # Shuffle the subnets so we don't always hit the same one
      # first, and cycle though the subnets independently of the
      # host, so we stick with one that's working.  Try each subnet
      # once per-host.
      if subnets.nil? or subnets.empty?
        return
      end
      subnet_i = 0
      shuffnets = subnets.shuffle
      hosts.each do |host|
        instance = nil
        shuffnets.length.times do
          begin
            subnet_id = shuffnets[subnet_i]
            instance = create_instance(host, ami_spec, subnet_id)
            instances_created.push({:instance => instance, :host => host})
            break
          rescue AWS::EC2::Errors::InsufficientInstanceCapacity => ex
            @logger.notify("aws-sdk: hit #{subnet_id} capacity limit; moving on")
            subnet_i = (subnet_i + 1) % shuffnets.length
          end
        end
        if instance.nil?
          raise RuntimeError, "unable to launch host in any requested subnet"
        end
      end
    end

    # Create EC2 instances for all hosts, tag them, and wait until
    # they're running.  When a host provides a subnet_id, create the
    # instance in that subnet, otherwise prefer a CONFIG subnet_id.
    # If neither are set but there is a CONFIG subnet_ids list,
    # attempt to create the host in each specified subnet, which might
    # fail due to capacity constraints, for example.  Specifying both
    # a CONFIG subnet_id and subnet_ids will provoke an error.
    #
    # @return [void]
    # @api private
    def launch_all_nodes
      @logger.notify("aws-sdk: launch all hosts in configuration")
      ami_spec = YAML.load_file(@options[:ec2_yaml])["AMI"]
      global_subnet_id = @options['subnet_id']
      global_subnets = @options['subnet_ids']
      if global_subnet_id and global_subnets
        raise RuntimeError, 'Config specifies both subnet_id and subnet_ids'
      end
      no_subnet_hosts = []
      specific_subnet_hosts = []
      some_subnet_hosts = []
      @hosts.each do |host|
        if global_subnet_id or host['subnet_id']
          specific_subnet_hosts.push(host)
        elsif global_subnets
          some_subnet_hosts.push(host)
        else
          no_subnet_hosts.push(host)
        end
      end
      instances = [] # Each element is {:instance => i, :host => h}
      begin
        @logger.notify("aws-sdk: launch instances not particular about subnet")
        launch_nodes_on_some_subnet(some_subnet_hosts, global_subnets, ami_spec,
                                    instances)
        @logger.notify("aws-sdk: launch instances requiring a specific subnet")
        specific_subnet_hosts.each do |host|
          subnet_id = host['subnet_id'] || global_subnet_id
          instance = create_instance(host, ami_spec, subnet_id)
          instances.push({:instance => instance, :host => host})
        end
        @logger.notify("aws-sdk: launch instances requiring no subnet")
        no_subnet_hosts.each do |host|
          instance = create_instance(host, ami_spec, nil)
          instances.push({:instance => instance, :host => host})
        end
        wait_for_status(:running, instances)
      rescue Exception => ex
        @logger.notify("aws-sdk: exception - #{ex}")
        kill_instances(instances.map{|x| x[:instance]})
        raise ex
      end
      # At this point, all instances should be running since wait
      # either returns on success or throws an exception.
      if instances.empty?
        raise RuntimeError, "Didn't manage to launch any EC2 instances"
      end
      # Assign the now known running instances to their hosts.
      instances.each {|x| x[:host]['instance'] = x[:instance]}
      nil
    end

    # Wait until all instances reach the desired state.  Each Hash in
    # instances must contain an :instance and :host value.
    #
    # @param status [Symbol] EC2 state to wait for, :running :stopped etc.
    # @param instances Enumerable<Hash{Symbol=>EC2::Instance,Host}>
    # @return [void]
    # @api private
    def wait_for_status(status, instances)
      # Wait for each node to reach status :running
      @logger.notify("aws-sdk: Waiting for all hosts to be #{status}")
      instances.each do |x|
        name = x[:name]
        instance = x[:instance]
        @logger.notify("aws-sdk: Wait for node #{name} to be #{status}")
        # Here we keep waiting for the machine state to reach ':running' with an
        # exponential backoff for each poll.
        # TODO: should probably be a in a shared method somewhere
        for tries in 1..10
          begin
            if instance.status == status
              # Always sleep, so the next command won't cause a throttle
              backoff_sleep(tries)
              break
            elsif tries == 10
              raise "Instance never reached state #{status}"
            end
          rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
            @logger.debug("Instance #{name} not yet available (#{e})")
          end
          backoff_sleep(tries)
        end
      end
    end

    # Add metadata tags to all instances
    #
    # @return [void]
    # @api private
    def add_tags
      @hosts.each do |host|
        instance = host['instance']

        # Define tags for the instance
        @logger.notify("aws-sdk: Add tags for #{host.name}")
        instance.add_tag("jenkins_build_url", :value => @options[:jenkins_build_url])
        instance.add_tag("Name", :value => host.name)
        instance.add_tag("department", :value => @options[:department])
        instance.add_tag("project", :value => @options[:project])
        instance.add_tag("created_by", :value => @options[:created_by])
      end

      nil
    end

    # Populate the hosts IP address from the EC2 dns_name
    #
    # @return [void]
    # @api private
    def populate_dns
      # Obtain the IP addresses and dns_name for each host
      @hosts.each do |host|
        @logger.notify("aws-sdk: Populate DNS for #{host.name}")
        instance = host['instance']
        host['ip'] = instance.ip_address ? instance.ip_address : instance.private_ip_address
        host['private_ip'] = instance.private_ip_address
        host['dns_name'] = instance.dns_name
        @logger.notify("aws-sdk: name: #{host.name} ip: #{host['ip']} private_ip: #{host['private_ip']} dns_name: #{instance.dns_name}")
      end

      nil
    end

    # Configure /etc/hosts for each node
    #
    # @return [void]
    # @api private
    def configure_hosts
      @hosts.each do |host|
        etc_hosts = "127.0.0.1\tlocalhost localhost.localdomain\n"
        name = host.name
        domain = get_domain_name(host)
        ip = host['private_ip']
        etc_hosts += "#{ip}\t#{name} #{name}.#{domain} #{host['dns_name']}\n"
        @hosts.each do |neighbor|
          if neighbor == host
            next
          end
          name = neighbor.name
          domain = get_domain_name(neighbor)
          ip = neighbor['ip']
          etc_hosts += "#{ip}\t#{name} #{name}.#{domain} #{neighbor['dns_name']}\n"
        end
        set_etc_hosts(host, etc_hosts)
      end
    end

    # Enables root for instances with custom username like ubuntu-amis
    #
    # @return [void]
    # @api private
    def enable_root_on_hosts
      @hosts.each do |host|
        enable_root(host)
      end
    end

    # Enables root access for a host when username is not root
    #
    # @return [void]
    # @api private
    def enable_root(host)
      if host['user'] != 'root'
        if host['platform'] =~ /f5-/
          enable_root_f5(host)
        else
          copy_ssh_to_root(host, @options)
          enable_root_login(host, @options)
          host['user'] = 'root'
        end
        host.close
      end
    end

    # Enables root access for a host on an f5 platform
    # @note This method does not support other platforms
    #
    # @return nil
    # @api private
    def enable_root_f5(host)
      for tries in 1..10
        begin
          #This command is problematic as the F5 is not always done loading
          if host.exec(Command.new("modify sys db systemauth.disablerootlogin value false"), :acceptable_exit_codes => [0,1]).exit_code == 0 \
              and host.exec(Command.new("modify sys global-settings gui-setup disabled"), :acceptable_exit_codes => [0,1]).exit_code == 0 \
              and host.exec(Command.new("save sys config"), :acceptable_exit_codes => [0,1]).exit_code == 0
            backoff_sleep(tries)
            break
          elsif tries == 10
            raise "Instance was unable to be configured"
          end
        rescue Beaker::Host::CommandFailure => e
          @logger.debug("Instance not yet configured (#{e})")
        end
        backoff_sleep(tries)
      end
      host['user'] = 'root'
      host.close
      sha256 = Digest::SHA256.new
      password = sha256.hexdigest((1..50).map{(rand(86)+40).chr}.join.gsub(/\\/,'\&\&'))
      host['ssh'] = {:password => password}
      host.exec(Command.new("echo -e '#{password}\\n#{password}' | tmsh modify auth password admin"))
      @logger.notify("f5: Configured admin password to be #{password}")
    end

    # Set the hostname of all instances to be the hostname defined in the
    # beaker configuration.
    #
    # @return [void]
    # @api private
    def set_hostnames
      @hosts.each do |host|
        if host['platform'] =~ /el-7/
          # on el-7 hosts, the hostname command doesn't "stick" randomly
          host.exec(Command.new("hostnamectl set-hostname #{host.name}"))
        else
          host.exec(Command.new("hostname #{host.name}"))
        end
      end
    end

    # Calculates and waits a back-off period based on the number of tries
    #
    # Logs each backupoff time and retry value to the console.
    #
    # @param tries [Number] number of tries to calculate back-off period
    # @return [void]
    # @api private
    def backoff_sleep(tries)
      # Exponential with some randomization
      sleep_time = 2 ** tries
      @logger.notify("aws-sdk: Sleeping #{sleep_time} seconds for attempt #{tries}.")
      sleep sleep_time
      nil
    end

    # Retrieve the public key locally from the executing users ~/.ssh directory
    #
    # @return [String] contents of public key
    # @api private
    def public_key
      filename = File.expand_path('~/.ssh/id_rsa.pub')
      unless File.exists? filename
        filename = File.expand_path('~/.ssh/id_dsa.pub')
        unless File.exists? filename
          raise RuntimeError, 'Expected either ~/.ssh/id_rsa.pub or ~/.ssh/id_dsa.pub but found neither'
        end
      end

      File.read(filename)
    end

    # Generate a reusable key name from the local hosts hostname
    #
    # @return [String] safe key name for current host
    # @api private
    def key_name
      safe_hostname = Socket.gethostname.gsub('.', '-')
      "Beaker-#{local_user}-#{safe_hostname}"
    end

    # Returns the local user running this tool
    #
    # @return [String] username of local user
    # @api private
    def local_user
      ENV['USER']
    end

    # Returns the KeyPair for this host, creating it if needed
    #
    # @param region [AWS::EC2::Region] region to create the key pair in
    # @return [AWS::EC2::KeyPair] created key_pair
    # @api private
    def ensure_key_pair(region)
      @logger.notify("aws-sdk: Ensure key pair exists, create if not")
      key_pairs = region.key_pairs
      pair_name = key_name()
      kp = key_pairs[pair_name]
      unless kp.exists?
        ssh_string = public_key()
        kp = key_pairs.import(pair_name, ssh_string)
      end

      kp
    end

    # Return a reproducable security group identifier based on input ports
    #
    # @param ports [Array<Number>] array of port numbers
    # @return [String] group identifier
    # @api private
    def group_id(ports)
      if ports.nil? or ports.empty?
        raise ArgumentError, "Ports list cannot be nil or empty"
      end

      unless ports.is_a? Set
        ports = Set.new(ports)
      end

      # Lolwut, #hash is inconsistent between ruby processes
      "Beaker-#{Zlib.crc32(ports.inspect)}"
    end

    # Return an existing group, or create new one
    #
    # Accepts a VPC as input for checking & creation.
    #
    # @param vpc [AWS::EC2::VPC] the AWS vpc control object
    # @return [AWS::EC2::SecurityGroup] created security group
    # @api private
    def ensure_ping_group(vpc)
      @logger.notify("aws-sdk: Ensure security group exists that enables ping, create if not")

      group = vpc.security_groups.filter('group-name', PING_SECURITY_GROUP_NAME).first

      if group.nil?
        group = create_ping_group(vpc)
      end

      group
    end

    # Return an existing group, or create new one
    #
    # Accepts a VPC as input for checking & creation.
    #
    # @param vpc [AWS::EC2::VPC] the AWS vpc control object
    # @param ports [Array<Number>] an array of port numbers
    # @return [AWS::EC2::SecurityGroup] created security group
    # @api private
    def ensure_group(vpc, ports)
      @logger.notify("aws-sdk: Ensure security group exists for ports #{ports.to_s}, create if not")
      name = group_id(ports)

      group = vpc.security_groups.filter('group-name', name).first

      if group.nil?
        group = create_group(vpc, ports)
      end

      group
    end

    # Create a new ping enabled security group
    #
    # Accepts a region or VPC for group creation.
    #
    # @param rv [AWS::EC2::Region, AWS::EC2::VPC] the AWS region or vpc control object
    # @return [AWS::EC2::SecurityGroup] created security group
    # @api private
    def create_ping_group(rv)
      @logger.notify("aws-sdk: Creating group #{PING_SECURITY_GROUP_NAME}")
      group = rv.security_groups.create(PING_SECURITY_GROUP_NAME,
                                        :description => "Custom Beaker security group to enable ping")

      group.allow_ping

      group
    end

    # Create a new security group
    #
    # Accepts a region or VPC for group creation.
    #
    # @param rv [AWS::EC2::Region, AWS::EC2::VPC] the AWS region or vpc control object
    # @param ports [Array<Number>] an array of port numbers
    # @return [AWS::EC2::SecurityGroup] created security group
    # @api private
    def create_group(rv, ports)
      name = group_id(ports)
      @logger.notify("aws-sdk: Creating group #{name} for ports #{ports.to_s}")
      group = rv.security_groups.create(name,
                                        :description => "Custom Beaker security group for #{ports.to_a}")

      unless ports.is_a? Set
        ports = Set.new(ports)
      end

      ports.each do |port|
        group.authorize_ingress(:tcp, port)
      end

      group
    end

    # Return a hash containing the fog credentials for EC2
    #
    # @param dot_fog [String] dot fog path
    # @return [Hash<Symbol, String>] ec2 credentials
    # @api private
    def load_fog_credentials(dot_fog = '.fog')
      fog = YAML.load_file( dot_fog )

      default = fog[:default]

      creds = {}
      creds[:access_key] = default[:aws_access_key_id]
      creds[:secret_key] = default[:aws_secret_access_key]
      raise "You must specify an aws_access_key_id in your .fog file (#{dot_fog}) for ec2 instances!" unless creds[:access_key]
      raise "You must specify an aws_secret_access_key in your .fog file (#{dot_fog}) for ec2 instances!" unless creds[:secret_key]

      creds
    end
  end
end
