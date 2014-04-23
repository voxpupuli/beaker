require 'aws/ec2'
require 'set'
require 'zlib'
require 'beaker/hypervisor/ec2_helper'

module Beaker
  # This is an alternate EC2 driver that implements direct API access using
  # Amazon's AWS-SDK library: http://aws.amazon.com/documentation/sdkforruby/
  #
  # It is built for full control, to reduce any other layers beyond the pure
  # vendor API.
  class AwsSdk < Beaker::Hypervisor
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

      # Wait for each node to reach status :running
      @logger.notify("aws-sdk: Now wait for all hosts to reach state :running")
      wait_for_status(:running)

      # Grab the ip addresses from EC2 for each instance to use for ssh
      populate_ip()

      # Set the hostname for each box
      set_hostnames()

      # Configure /etc/hosts for all nodes
      hack_etc_hosts @hosts, @options

      @logger.notify("aws-sdk: Provisioning complete in #{Time.now - start_time} seconds")

      nil #void
    end

    # Cleanup all earlier provisioned hosts on EC2 using the AWS::EC2 library
    #
    # It goes without saying, but a #cleanup does nothing without a #provision
    # method call first.
    #
    # @return [void]
    def cleanup
      @logger.notify("aws-sdk: Cleanup, iterating across all hosts and terminating them")
      @hosts.each do |host|
        # This was set previously during provisioning
        instance = host['instance']

        # Only attempt a terminate if the instance actually is set by provision
        # and the instance actually 'exists'.
        if !instance.nil? and instance.exists?
          instance.terminate
        end
      end

      nil #void
    end

    # Launch all nodes
    #
    # This is where the main launching work occurs for each node. Here we take
    # care of feeding the information from the image required into the config
    # for the new host, we perform the launch operation and ensure that the
    # instance is properly tagged for identification.
    #
    # @return [void]
    # @api private
    def launch_all_nodes
      # Load the ec2_yaml spec file
      ami_spec = YAML.load_file(@options[:ec2_yaml])["AMI"]

      # Iterate across all hosts and launch them, adding tags along the way
      @logger.notify("aws-sdk: Iterate across all hosts in configuration and launch them")
      @hosts.each do |host|
        amitype = host['vmname'] || host['platform']
        amisize = host['amisize'] || 'm1.small'

        # Use snapshot provided for this host
        image_type = host['snapshot']
        if not image_type
          raise RuntimeError, "No snapshot/image_type provided for EC2 provisioning"
        end
        ami = ami_spec[amitype]
        ami_region = ami[:region]

        # Main region object for ec2 operations
        region = @ec2.regions[ami_region]

        # Grab image object
        image_id = ami[:image][image_type.to_sym]
        @logger.notify("aws-sdk: Checking image #{image_id} exists and getting its root device")
        image = region.images[image_id]
        if image.nil? and not image.exists?
          raise RuntimeError, "Image not found: #{image_id}"
        end

        # Transform the images block_device_mappings output into a format
        # ready for a create.
        orig_bdm = image.block_device_mappings()
        @logger.notify("aws-sdk: Image block_device_mappings: #{orig_bdm.to_hash}")
        block_device_mappings = []
        orig_bdm.each do |device_name, rest|
          block_device_mappings << {
            :device_name => device_name,
            :ebs => {
              # This is required to override the images default for
              # delete_on_termination, forcing all volumes to be deleted once the
              # instance is terminated.
              :delete_on_termination => true,
            }
          }
        end

        # Launch the node, filling in the blanks from previous work.
        @logger.notify("aws-sdk: Launch instance")
        config = {
          :count => 1,
          :image_id => image_id,
          :monitoring_enabled => true,
          :key_pair => ensure_key_pair(region),
          :security_groups => [ensure_group(region, Beaker::EC2Helper.amiports(host['roles']))],
          :instance_type => amisize,
          :disable_api_termination => false,
          :instance_initiated_shutdown_behavior => "terminate",
          :block_device_mappings => block_device_mappings,
        }
        instance = region.instances.create(config)

        # Persist the instance object for this host, so later it can be
        # manipulated by 'cleanup' for example.
        host['instance'] = instance

        # Define tags for the instance
        @logger.notify("aws-sdk: Add tags")
        instance.add_tag("jenkins_build_url", :value => @options[:jenkins_build_url])
        instance.add_tag("Name", :value => host.name)
        instance.add_tag("department", :value => @options[:department])
        instance.add_tag("project", :value => @options[:project])

        @logger.notify("aws-sdk: Launched #{host.name} (#{amitype}:#{amisize}) using snapshot/image_type #{image_type}")
      end

      nil
    end

    # Waits until all boxes reach the desired status
    #
    # @param status [Symbol] EC2 state to wait for, :running :stopped etc.
    # @return [void]
    # @api private
    def wait_for_status(status)
      # Wait for each node to reach status :running
      @logger.notify("aws-sdk: Now wait for all hosts to reach state #{status}")
      @hosts.each do |host|
        instance = host['instance']
        name = host.name

        @logger.notify("aws-sdk: Wait for status #{status} for node #{name}")

        # Here we keep waiting for the machine state to reach ':running' with an
        # exponential backoff for each poll.
        # TODO: should probably be a in a shared method somewhere
        for tries in 1..10
          if instance.status == status
            # Always sleep, so the next command won't cause a throttle
            backoff_sleep(tries)
            break
          elsif tries == 10
            raise "Instance never reached state #{status}"
          end
          backoff_sleep(tries)
        end

        # Set the IP to be the dns_name of the host, yes I know its not an IP.
        host['ip'] = instance.dns_name
      end
    end

    # Populate the hosts IP address entry from the EC2 dns_name
    #
    # @return [void]
    # @api private
    def populate_ip
      # Obtain the IP addresses for each host
      @hosts.each do |host|
        instance = host['instance']
        # Set the IP to be the dns_name of the host, yes I know its not an IP.
        host['ip'] = instance.dns_name
        @logger.notify("Using temp hostname #{host['ip']} for #{host.name}")
      end

      # Wait until SSH can be established first
      wait_for_ssh()

      @hosts.each do |host|
        host['ip'] = get_ip(host)
        @logger.notify("Now using #{host['ip']} for host #{host.name}")
      end

      nil
    end

    # Set the hostname of all instances to be the hostname defined in the
    # beaker configuration.
    #
    # @return [void]
    # @api private
    def set_hostnames
      @hosts.each do |host|
        host.exec(Command.new("hostname #{host.name}"))
      end
    end

    # Wait for SSH connectivity on all hosts is established.
    #
    # @return [void]
    # @api private
    def wait_for_ssh
      # Wait until each host is responding to SSH, catch any authentication
      # failures and retry them.
      @logger.notify("aws-sdk: Waiting for SSH connectivity ...")
      @hosts.each do |host|
        tries = 0
        begin
          tries += 1
          host.connection
        rescue Net::SSH::AuthenticationFailed => ex
          if tries <= 10
            backoff_sleep(tries)
            retry
          else
            raise ex
          end
        end
      end

      nil
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
    # @param region [AWS::EC2::Region] the AWS region control object
    # @param ports [Array<Number>] an array of port numbers
    # @return [AWS::EC2::SecurityGroup] created security group
    # @api private
    def ensure_group(region, ports)
      @logger.notify("aws-sdk: Ensure security group exists for ports #{ports.to_s}, create if not")
      name = group_id(ports)

      group = region.security_groups.filter('group-name', name).first

      if group.nil?
        group = create_group(region, ports)
      end

      group
    end

    # Create a new security group
    #
    # @param region [AWS::EC2::Region] the AWS region control object
    # @param ports [Array<Number>] an array of port numbers
    # @return [AWS::EC2::SecurityGroup] created security group
    # @api private
    def create_group(region, ports)
      name = group_id(ports)
      @logger.notify("aws-sdk: Creating group #{name} for ports #{ports.to_s}")
      group = region.security_groups.create(name,
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
      creds
    end
  end
end
