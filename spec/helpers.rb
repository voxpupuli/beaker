module TestFileHelpers
  def create_files file_array
    file_array.each do |f|
      FileUtils.mkdir_p File.dirname(f)
      FileUtils.touch f
    end
  end

  def fog_file_contents
    { :default => { :aws_access_key_id => "IMANACCESSKEY", 
                    :aws_secret_access_key => "supersekritkey", 
                    :aix_hypervisor_server => "aix_hypervisor.labs.net", 
                    :aix_hypervisor_username => "aixer", 
                    :aix_hypervisor_keyfile => "/Users/user/.ssh/id_rsa-acceptance", 
                    :solaris_hypervisor_server => "solaris_hypervisor.labs.net", 
                    :solaris_hypervisor_username => "harness", 
                    :solaris_hypervisor_keyfile => "/Users/user/.ssh/id_rsa-old.private", 
                    :solaris_hypervisor_vmpath => "rpoooool/zs", 
                    :solaris_hypervisor_snappaths => ["rpoooool/USER/z0"], 
                    :vsphere_server => "vsphere.labs.net", 
                    :vsphere_username => "vsphere@labs.com", 
                    :vsphere_password => "supersekritpassword"} }
  end

end

module HostHelpers
  HOST_DEFAULTS = { :platform => 'unix',
                    :snapshot => 'pe',
                    :box => 'box_name',
                    :roles => ['agent'],
                    :snapshot => 'snap',
                    :ip => 'default.ip.address',
                    :box => 'default_box_name',
                    :box_url => 'http://default.box.url',
  }

  HOST_NAME     = "vm%d"
  HOST_SNAPSHOT = "snapshot%d"
  HOST_IP       = "ip.address.for.%s"
  HOST_BOX      = "%s_of_my_box"
  HOST_BOX_URL  = "http://address.for.my.box.%s"

  def logger
    double( 'logger' ).as_null_object
  end

  def make_opts
     Beaker::Options::Presets.presets.merge( { :logger => logger, 
                                                             :host_config => 'sample.config',
                                                             :type => :foss} )
  end

  def make_host_opts name, opts
    make_opts.merge( { 'HOSTS' => { name => opts } } ).merge( opts )
  end

  def make_host name, opts
    opts = HOST_DEFAULTS.merge(opts) 

    host = Beaker::Host.create( name, make_host_opts(name, opts) )
    host.stub( :exec ).and_return( name )
    host
  end

  def make_hosts preset_opts = {}, amt = 3
    hosts = []
    (1..amt).each do |num|
      name = HOST_NAME % num
      opts = { :snapshot => HOST_SNAPSHOT % num,
               :ip => HOST_IP % name,
               :box => HOST_BOX % name,
               :box_url => HOST_BOX_URL % name }.merge( preset_opts )
      hosts << make_host(name, opts)
    end
    hosts
  end

end
