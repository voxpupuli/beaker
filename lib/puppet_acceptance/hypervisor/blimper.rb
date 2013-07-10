module PuppetAcceptance 
  class Blimper < PuppetAcceptance::Hypervisor

    def amiports(host)
      roles = host['roles']
      ports = [22]

      if roles.include? 'database'
        ports << 8080
        ports << 8081
      end

      if roles.include? 'master'
        ports << 8140
      end

      if roles.include? 'dashboard'
        ports << 443
      end

      ports
    end

  def initialize(blimpy_hosts, options, config)
    @options = options
    @config = config['CONFIG'].dup
    @logger = options[:logger]
    @blimpy_hosts = blimpy_hosts
    require 'rubygems' unless defined?(Gem)
    require 'yaml' unless defined?(YAML)
    begin
      require 'blimpy'
    rescue LoadError
      raise "Unable to load Blimpy, please ensure its installed"
    end
    ami_spec= YAML.load_file('config/image_templates/ec2.yaml')["AMI"]

    fleet = Blimpy.fleet do |fleet|
      @blimpy_hosts.each do |host|
        amitype = host['vmname'] || host['platform']
        amisize = host['amisize'] || 'm1.small'
        #use snapshot provided for this host 
        image_type = host['snapshot'] 
        if not image_type
          raise "No snapshot/image_type provided for blimpy provisioning"
        end
        ami = ami_spec[amitype]
        fleet.add(:aws) do |ship|
          ship.name = host.name
          ship.ports = amiports(host)
          ship.image_id = ami[:image][image_type.to_sym]
          if not ship.image_id
            raise "No image_id found for host #{ship.name} (#{amitype}:#{amisize}) using snapshot/image_type #{image_type}"
          end
          ship.flavor = amisize
          ship.region = ami[:region]
          ship.username = 'root'
        end
        @logger.debug "Added #{host.name} (#{amitype}:#{amisize}) using snapshot/image_type #{image_type} to blimpy fleet"
      end
    end

    # Attempt to start the fleet, we wrap it with some error handling that deals
    # with generic Fog errors and retrying in case these errors are transient.
    fleet_retries = 0
    begin
      fleet.start
    rescue Fog::Errors::Error => ex
      fleet_retries += 1
      if fleet_retries <= 3
        sleep_time = rand(10) + 10
        @logger.notify("Calling fleet.destroy, sleeping #{sleep_time} seconds and retrying fleet.start due to Fog::Errors::Error (#{
ex.message}), retry attempt #{fleet_retries}.")
        begin
          timeout(30) do
            fleet.destroy
          end
        rescue
        end
        sleep sleep_time
        retry
      else
        @logger.error("Retried Fog #{fleet_retries} times, giving up and throwing the exception")
        raise ex
      end
    end

    # Configure our nodes to match the blimp fleet
    # Also generate hosts entries for the fleet, since we're iterating
    etc_hosts = "127.0.0.1\tlocalhost localhost.localdomain\n"
    fleet.ships.each do |ship|
      ship.wait_for_sshd
      name = ship.name
      host = @blimpy_hosts.select { |host| host.name == name }[0]
      host['ip'] = ship.dns
      host.exec(Command.new("hostname #{name}"))
      ip = get_ip(host) 
      domain = get_domain_name(host)
      etc_hosts += "#{ip}\t#{name}\t#{name}.#{domain}\n"
    end

    # Send our hosts information to the nodes
    @blimpy_hosts.each do |host|
      set_etc_hosts(host, etc_hosts)
    end

    end #revert_blimpy

    def cleanup
      fleet = Blimpy.fleet do |fleet|
        @blimpy_hosts.each do |host|
          fleet.add(:aws) do |ship|
            ship.name = host.name
          end
        end
      end

      @logger.notify "Destroying Blimpy boxes"
      fleet.destroy
    end

  end
end
