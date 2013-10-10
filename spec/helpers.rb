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
  DEFAULTS = { :platform => 'unix',
               :snapshot => 'pe',
               :box => 'box_name',
               :roles => ['agent'],
               :snapshot => 'snap',
               :ip => 'default.ip.address',
               :box => 'default_box_name',
               :box_url => 'http://default.box.url',
  }

  NAME     = "vm%d"
  SNAPSHOT = "snapshot%d"
  IP       = "ip.address.for.%s"
  BOX      = "%s_of_my_box"
  BOX_URL  = "http://address.for.my.box.%s"
  @@logger = nil
  @@options =  nil

  def logger
    @@logger ||= double( 'logger' ).as_null_object
  end

  def make_opts
     @@options ||= Beaker::Options::Presets.presets.merge( { :logger => logger, 
                                                             :host_config => 'sample.config' } )
  end

  def make_host_opts name, opts
    make_opts.merge( { 'HOSTS' => { name => opts } } )
  end

  def make_host name, opts
    opts = DEFAULTS.merge(opts) 

    host = Beaker::Host.create( name, make_host_opts(name, opts) )
    host.stub( :exec ).and_return( name )
    host
  end

  def make_hosts preset_opts = {}, amt = 3
    hosts = []
    (1..amt).each do |num|
      name = NAME % num
      opts = { :snapshot => SNAPSHOT % num,
               :ip => IP % name,
               :box => BOX % name,
               :box_url => BOX_URL % name }.merge( preset_opts )
      hosts << make_host(name, opts)
    end
    hosts
  end

end
