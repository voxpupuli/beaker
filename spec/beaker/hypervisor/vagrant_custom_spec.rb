require 'spec_helper'

describe Beaker::VagrantCustom do
  let( :options ) { make_opts.merge({ :hosts_file => 'sample.cfg', 'logger' => double().as_null_object }) }
  let( :vagrant ) { Beaker::VagrantCustom.new( @hosts, options ) }

  let(:test_dir) { 'tmp/tests' }
  let(:custom_vagrant_file_path)  { File.expand_path(test_dir + '/CustomVagrantfile')   }

  before :each do
    @hosts = make_hosts()
  end

  it "uses the vagrant_custom provider for provisioning" do
    @hosts.each do |host|
      host_prev_name = host['user']
      expect( vagrant ).to receive( :set_ssh_config ).with( host, 'vagrant' ).once
      expect( vagrant ).to receive( :copy_ssh_to_root ).with( host, options ).once
      expect( vagrant ).to receive( :set_ssh_config ).with( host, host_prev_name ).once
    end
    expect( vagrant ).to receive( :hack_etc_hosts ).with( @hosts, options ).once
    FakeFS.activate!
    expect( vagrant ).to receive( :vagrant_cmd ).with( "up" ).once
    vagrant.provision
  end

  context 'takes vagrant configuration from existing file' do
    it 'writes the vagrant file to the correct location' do
      options.merge!({ :vagrantfile_path => custom_vagrant_file_path })

      create_files([custom_vagrant_file_path])

      vagrant_file_contents = <<-EOF
FOO
      EOF
      File.open(custom_vagrant_file_path, 'w') { |file| file.write(vagrant_file_contents) }

      vagrant_copy_location = "#{test_dir}/NewVagrantLocation"
      vagrant.instance_variable_set(:@vagrant_file, vagrant_copy_location)
      vagrant.make_vfile(@hosts, options)
      vagrant_copy_file = File.open(vagrant_copy_location, 'r')
      expect(vagrant_copy_file.read).to be === vagrant_file_contents
    end

  end
end
