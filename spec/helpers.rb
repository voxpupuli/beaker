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
                    :roles => ['agent'],
                    :snapshot => 'snap',
                    :ip => 'default.ip.address',
                    :private_ip => 'private.ip.address',
                    :dns_name => 'default.box.tld',
                    :box => 'default_box_name',
                    :box_url => 'http://default.box.url',
                    :image => 'default_image',
                    :flavor => 'm1.large',
                    :user_data => '#cloud-config\nmanage_etc_hosts: true\nfinal_message: "The host is finally up!"'
  }

  HOST_NAME     = "vm%d"
  HOST_SNAPSHOT = "snapshot%d"
  HOST_IP       = "ip.address.for.%s"
  HOST_BOX      = "vm2%s_of_my_box"
  HOST_BOX_URL  = "http://address.for.my.box.%s"
  HOST_DNS_NAME = "%s.box.tld"
  HOST_TEMPLATE = "%s_has_a_template"
  HOST_PRIVATE_IP = "private.ip.for.%s"

  def logger
    double( 'logger' ).as_null_object
  end

  def make_opts
    opts = Beaker::Options::Presets.new
    opts.presets.merge( opts.env_vars ).merge( { :logger => logger,
                                               :host_config => 'sample.config',
                                               :type => nil,
                                               :pooling_api => 'http://vcloud.delivery.puppetlabs.net/',
                                               :datastore => 'instance0',
                                               :folder => 'Delivery/Quality Assurance/Staging/Dynamic',
                                               :resourcepool => 'delivery/Quality Assurance/Staging/Dynamic',
                                               :gce_project => 'beaker-compute',
                                               :gce_keyfile => '/path/to/keyfile.p12',
                                               :gce_password => 'notasecret',
                                               :gce_email => '12345678910@developer.gserviceaccount.com',
                                               :openstack_api_key => "P1as$w0rd",
                                               :openstack_username => "user",
                                               :openstack_auth_url => "http://openstack_hypervisor.labs.net:5000/v2.0/tokens",
                                               :openstack_tenant => "testing",
                                               :openstack_network => "testing",
                                               :openstack_keyname => "nopass", 
                                               :floating_ip_pool => "my_pool",
                                               :security_group => ['my_sg', 'default'] } )
  end

  def generate_result (name, opts )
    result = double( 'result' )
    stdout = opts.has_key?(:stdout) ? opts[:stdout] : name
    stderr = opts.has_key?(:stderr) ? opts[:stderr] : name
    exit_code = opts.has_key?(:exit_code) ? opts[:exit_code] :  0
    exit_code = [exit_code].flatten
    allow( result ).to receive( :stdout ).and_return( stdout )
    allow( result ).to receive( :stderr ).and_return( stderr )
    allow( result ).to receive( :exit_code ).and_return( *exit_code )
    result
  end

  def make_host_opts name, opts
    make_opts.merge( { 'HOSTS' => { name => opts } } ).merge( opts )
  end

  def make_host name, host_hash
    host_hash = Beaker::Options::OptionsHash.new.merge(HOST_DEFAULTS.merge(host_hash))

    host = Beaker::Host.create( name, host_hash, make_opts)

    allow(host).to receive( :exec ).and_return( generate_result( name, host_hash ) )
    allow(host).to receive( :close )
    host
  end

  def make_hosts preset_opts = {}, amt = 3
    hosts = []
    (1..amt).each do |num|
      name = HOST_NAME % num
      opts = { :snapshot => HOST_SNAPSHOT % num,
               :ip => HOST_IP % name,
               :private_ip => HOST_PRIVATE_IP % name,
               :dns_name => HOST_DNS_NAME % name,
               :template => HOST_TEMPLATE % name,
               :box => HOST_BOX % name,
               :box_url => HOST_BOX_URL % name }.merge( preset_opts )
      hosts << make_host(name, opts)
    end
    hosts
  end

  def make_instance instance_data = {}
    OpenStruct.new instance_data
  end

end

module PlatformHelpers

  DEBIANPLATFORMS = ['debian',
                     'ubuntu',
                     'cumulus',
                     'huaweios']


  FEDORASYSTEMD    = (14..29).to_a.collect! { |i| "fedora-#{i}" }

  SYSTEMDPLATFORMS = ['el-7',
                      'centos-7',
                      'redhat-7',
                      'oracle-7',
                      'scientific-7',
                      'eos-7'].concat(FEDORASYSTEMD)

  FEDORASYSTEMV    = (1..13).to_a.collect! { |i| "fedora-#{i}" }

  SYSTEMVPLATFORMS = ['el-',
                      'centos',
                      'fedora',
                      'redhat',
                      'oracle',
                      'scientific',
                      'eos'].concat(FEDORASYSTEMV)
end
