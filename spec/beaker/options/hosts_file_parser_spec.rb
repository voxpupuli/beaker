require "spec_helper"

module Beaker
  module Options
    describe HostsFileParser do

      let(:parser)      {described_class}
      let(:filepath)    {File.join(File.expand_path(File.dirname(__FILE__)), "data", "hosts.cfg")}
      let(:filepath_yaml) {File.join(File.expand_path(File.dirname(__FILE__)), "data", "hosts_preserved.yml")}

      describe '#parse_hosts_file' do
        it "can correctly read a host file" do
          FakeFS.deactivate!
          config = parser.parse_hosts_file(filepath)
          expect(config).to be === {:HOSTS=>{:"pe-ubuntu-lucid"=>{:roles=>["agent", "dashboard", "database", "master"], :vmname=>"pe-ubuntu-lucid", :platform=>"ubuntu-10.04-i386", :snapshot=>"clean-w-keys", :hypervisor=>"fusion"}, :"pe-centos6"=>{:roles=>["agent"], :vmname=>"pe-centos6", :platform=>"el-6-i386", :hypervisor=>"fusion", :snapshot=>"clean-w-keys"}}, :nfs_server=>"none", :consoleport=>443}
        end

        it "can merge CONFIG section into overall hash" do
          FakeFS.deactivate!
          config = parser.parse_hosts_file(filepath)
          expect(config['CONFIG']).to be === nil
          expect(config['consoleport']).to be === 443
        end

        it "returns empty configuration when no file provided" do
          FakeFS.deactivate!
          expect(parser.parse_hosts_file()).to be === { :HOSTS => {} }
        end

        it "raises an error on no file found" do
          FakeFS.deactivate!
          expect{parser.parse_hosts_file("not a valid path")}.to raise_error(/is not a valid path/)
        end

        it "raises an error on bad yaml file" do
          FakeFS.deactivate!
          expect( File ).to receive(:exist?).and_return(true)

          expect { parser.parse_hosts_file("not a valid path") }.to raise_error(Errno::ENOENT)
        end

        it 'returns a #new_host_options hash if given no arguments' do
          host_options = parser.parse_hosts_file
          expect( host_options ).to be === parser.new_host_options
        end

        it 'passes a YAML.load call through to #merge_hosts_yaml' do
          yaml_string = 'not actually yaml, but that wont matter'
          expect( File ).to receive( :exist?).and_return(true)
          expect( File ).to receive( :read ).and_return(yaml_string)
          parser.parse_hosts_file( yaml_string )
        end

        it 'processes ERB in the host YAML successfully' do
          yaml_string = '1 plus 2: <%= 1 + 2 %>'
          expect( File ).to receive( :exist?).and_return(true)
          expect( File ).to receive( :read ).and_return(yaml_string)
          beaker_options_hash = parser.parse_hosts_file( yaml_string )
          expect(beaker_options_hash['1 plus 2']).to eq(3)
        end

        it "can correctly read a hosts_preserved.yml file" do
          FakeFS.deactivate!
          expect{ parser.parse_hosts_file(filepath_yaml) }.not_to raise_error
          expect(parser.parse_hosts_file(filepath_yaml).dig(:HOSTS, :"primary.host")).not_to be_nil
        end
      end

      describe '#parse_hosts_string' do

        it 'will return a #new_host_options hash if given no arguments' do
          host_options = parser.parse_hosts_string
          expect( host_options ).to be === parser.new_host_options
        end

        it 'passes a process_yaml call through to #merge_hosts_yaml' do
          yaml_string = 'not actually yaml, but that wont matter'
          expect(described_class).to receive(:process_yaml).with(yaml_string, instance_of(Binding))

          parser.parse_hosts_string( yaml_string )
        end
      end

      describe '#merge_hosts_yaml' do
        it 'merges yielded block result with host_options argument & returns it' do
          host_options = {}
          yield_to_merge = { :pants => 'truth to the face' }
          block_count = 0
          answer = parser.merge_hosts_yaml( host_options, 'err_msg' ) {
            block_count += 1
            yield_to_merge
          }

          expect( block_count ).to be === 1
          expect( answer ).to be === host_options.merge( yield_to_merge )
        end

        class MockSyntaxError < Psych::SyntaxError
          def initialize
            super( '', 0, 0, 0, '', '' )
          end
        end

        it 'raises an ArgumentError if can\'t process YAML' do
          # allow( parser ).to receive( :merge_hosts_yaml )
          err_value = 'err_msg8797'
          expect {
            parser.merge_hosts_yaml( {}, err_value ) {
              raise MockSyntaxError
            }
          }.to raise_error( ArgumentError, /#{err_value}/ )
        end
      end

      describe '#fix_roles_array' do
        it 'adds a roles array to a host if not present' do
          host_options = { 'HOSTS' => {
            'host1' => {},
            'host2' => {}
          }}

          parser.fix_roles_array( host_options )

          host_options['HOSTS'].each do |_host_name, host_hash|
            expect( host_hash['roles'] ).to be === []
          end
        end
      end
    end
  end
end
