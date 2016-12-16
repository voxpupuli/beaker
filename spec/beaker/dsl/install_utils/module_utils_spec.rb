require 'spec_helper'

class ClassMixedWithDSLInstallUtils
  include Beaker::DSL::InstallUtils
  include Beaker::DSL::Wrappers
  include Beaker::DSL::Helpers
  include Beaker::DSL::Structure
  include Beaker::DSL::Roles
  include Beaker::DSL::Patterns

  def logger
    @logger ||= RSpec::Mocks::Double.new('logger').as_null_object
  end
end

describe ClassMixedWithDSLInstallUtils do
  let(:presets)       { Beaker::Options::Presets.new }
  let(:opts)          { presets.presets.merge(presets.env_vars) }
  let(:basic_hosts)   { make_hosts( { :pe_ver => '3.0',
                                       :platform => 'linux',
                                       :roles => [ 'agent' ] }, 4 ) }
  let(:hosts)         { basic_hosts[0][:roles] = ['master', 'database', 'dashboard']
                        basic_hosts[1][:platform] = 'windows'
                        basic_hosts[2][:platform] = 'osx-10.9-x86_64'
                        basic_hosts[3][:platform] = 'eos'
                        basic_hosts  }
  let(:hosts_sorted)  { [ hosts[1], hosts[0], hosts[2], hosts[3] ] }



  describe '#install_dev_puppet_module_on' do
    context 'having set allow( a ).to receive forge' do
      it 'stubs the forge on the host' do
        master = hosts.first
        allow( subject ).to receive( :options ).and_return( {:forge_host => 'ahost.com'} )

        expect( subject ).to receive( :with_forge_stubbed_on )

        subject.install_dev_puppet_module_on( master, {:source => '/module', :module_name => 'test'} )
      end

      it 'installs via #install_puppet_module_via_pmt' do
        master = hosts.first
        allow( subject ).to receive( :options ).and_return( {:forge_host => 'ahost.com'} )
        allow( subject ).to receive( :with_forge_stubbed_on ).and_yield

        expect( subject ).to receive( :install_puppet_module_via_pmt_on )

        subject.install_dev_puppet_module_on( master, {:source => '/module', :module_name => 'test'} )
      end
    end
    context 'without allow( a ).to receive forge (default)' do
      it 'calls copy_module_to to get the module on the SUT' do
        master = hosts.first
        allow( subject ).to receive( :options ).and_return( {} )

        expect( subject ).to receive( :copy_module_to )

        subject.install_dev_puppet_module_on( master, {:source => '/module', :module_name => 'test'} )
      end
    end
  end

  describe '#install_dev_puppet_module' do
    it 'delegates to #install_dev_puppet_module_on with the hosts list' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      allow( subject ).to receive( :options ).and_return( {} )

      hosts.each do |host|
        expect( subject ).to receive( :install_dev_puppet_module_on ).
          with( host, {:source => '/module', :module_name => 'test'})
      end

      subject.install_dev_puppet_module( {:source => '/module', :module_name => 'test'} )
    end
  end

  describe '#install_puppet_module_via_pmt_on' do
    it 'installs module via puppet module tool' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      master = hosts.first

      allow( subject ).to receive( :on ).once
      expect( subject ).to receive( :puppet ).with('module install test ', {}).once

      subject.install_puppet_module_via_pmt_on( master, {:module_name => 'test'} )
    end

    it 'takes the trace option and passes it down correctly' do
      allow( subject ).to receive( :hosts ).and_return( hosts )
      master = hosts.first
      trace_opts = { :trace => nil }
      master['default_module_install_opts'] = trace_opts

      allow( subject ).to receive( :on ).once
      expect( subject ).to receive( :puppet ).with('module install test ', trace_opts).once

      subject.install_puppet_module_via_pmt_on( master, {:module_name => 'test'} )
    end
  end

  describe '#install_puppet_module_via_pmt' do
    it 'delegates to #install_puppet_module_via_pmt with the hosts list' do
      allow( subject ).to receive( :hosts ).and_return( hosts )

      expect( subject ).to receive( :install_puppet_module_via_pmt_on ).with( hosts, {:source => '/module', :module_name => 'test'}).once

      subject.install_puppet_module_via_pmt( {:source => '/module', :module_name => 'test'} )
    end
  end

  describe 'copy_module_to' do
    let(:ignore_list) { Beaker::DSL::InstallUtils::ModuleUtils::PUPPET_MODULE_INSTALL_IGNORE }
    let(:source){ File.expand_path('./')}
    let(:target){'/etc/puppetlabs/puppet/modules/testmodule'}
    let(:module_parse_name){'testmodule'}

    shared_examples 'copy_module_to' do  |opts|
      it{
        host = double("host")
        allow( host ).to receive(:[]).with('distmoduledir').and_return('/etc/puppetlabs/puppet/modules')
        allow( host ).to receive(:is_powershell?).and_return(false)
        result = double
        stdout = target.split('/')[0..-2].join('/') + "\n"
        allow( result ).to receive(:stdout).and_return( stdout )
        expect( subject ).to receive(:on).with(host, "echo #{File.dirname(target)}" ).and_return(result )
        allow( Dir ).to receive(:getpwd).and_return(source)

        allow( subject ).to receive(:parse_for_moduleroot).and_return(source)
        if module_parse_name
          allow( subject ).to receive(:parse_for_modulename).with(any_args()).and_return(module_parse_name)
        else
          expect( subject).to_not receive(:parse_for_modulename)
        end

        allow( File ).to receive(:exists?).with(any_args()).and_return(false)
        allow( File ).to receive(:directory?).with(any_args()).and_return(false)

        expect( subject ).to receive(:scp_to).with(host,source, File.dirname(target), {:ignore => ignore_list})
        expect( host ).to receive(:mv).with(File.join(File.dirname(target), File.basename(source)), target)
        if opts.nil?
          subject.copy_module_to(host)
        else
          subject.copy_module_to(host,opts)
        end
      }
    end

    describe 'should call scp with the correct info, with only providing host' do
      let(:target){'/etc/puppetlabs/puppet/modules/testmodule'}

      it_should_behave_like 'copy_module_to', :module_name => 'testmodule'
    end

    describe 'should call scp with the correct info, when specifying the modulename' do
      let(:target){'/etc/puppetlabs/puppet/modules/bogusmodule'}
      let(:module_parse_name){false}
      it_should_behave_like 'copy_module_to', {:module_name =>'bogusmodule'}
    end

    describe 'should call scp with the correct info, when specifying the target to a different path' do
      target = '/opt/shared/puppet/modules'
      let(:target){"#{target}/testmodule"}
      it_should_behave_like 'copy_module_to', {:target_module_path => target, :module_name => 'testmodule'}
    end

    describe 'should accept multiple hosts when' do
      it 'used in a default manner' do
        allow( subject ).to receive( :build_ignore_list ).and_return( [] )
        allow( subject ).to receive( :parse_for_modulename ).and_return( [nil, 'modulename'] )
        allow( subject ).to receive( :on ).and_return( double.as_null_object )

        expect( subject ).to receive( :scp_to ).exactly(4).times
        subject.copy_module_to( hosts )
      end
    end

    describe 'non-cygwin windows' do
      it 'should have different commands than cygwin' do
        host = double("host")
        allow( host ).to receive(:[]).with('platform').and_return('windows')
        allow( host ).to receive(:[]).with('distmoduledir').and_return('C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules')
        allow( host ).to receive(:is_powershell?).and_return(true)

        result = double
        allow( result ).to receive(:stdout).and_return( 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules' )

        expect( subject ).to receive(:on).with(host, "echo C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules" ).and_return( result )

        expect( subject ).to receive(:scp_to).with(host, "/opt/testmodule2", "C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules", {:ignore => ignore_list})
        expect( host ).to receive(:mv).with('C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules\\testmodule2', 'C:\\ProgramData\\PuppetLabs\\puppet\\etc\\modules\\testmodule')

        subject.copy_module_to(host, {:module_name => 'testmodule', :source => '/opt/testmodule2'})
      end
    end
  end

  describe 'split_author_modulename' do
    it 'should return a correct modulename' do
      result =  subject.split_author_modulename('myname-test_43_module')
      expect(result[:author]).to eq('myname')
      expect(result[:module]).to eq('test_43_module')
    end
  end

  describe 'get_module_name' do
    it 'should return an array of author and modulename' do
      expect(subject.get_module_name('myname-test_43_module')).to eq(['myname', 'test_43_module'])
    end
    it 'should return nil for invalid names' do
      expect(subject.get_module_name('myname-')).to eq(nil)
    end
  end

  describe 'parse_for_modulename' do
    directory = '/testfilepath/myname-testmodule'
    it 'should return name from metadata.json' do
      allow( File ).to receive(:exists?).with("#{directory}/metadata.json").and_return(true)
      allow( File ).to receive(:read).with("#{directory}/metadata.json").and_return(" {\"name\":\"myname-testmodule\"} ")
      expect( subject.logger ).to receive(:debug).with("Attempting to parse Modulename from metadata.json")
      expect(subject.logger).to_not receive(:debug).with('Unable to determine name, returning null')
      expect(subject.parse_for_modulename(directory)).to eq(['myname', 'testmodule'])
    end
    it 'should return name from Modulefile' do
      allow( File ).to receive(:exists?).with("#{directory}/metadata.json").and_return(false)
      allow( File ).to receive(:exists?).with("#{directory}/Modulefile").and_return(true)
      allow( File ).to receive(:read).with("#{directory}/Modulefile").and_return("name    'myname-testmodule'  \nauthor   'myname'")
      expect( subject.logger ).to receive(:debug).with("Attempting to parse Modulename from Modulefile")
      expect(subject.logger).to_not receive(:debug).with("Unable to determine name, returning null")
      expect(subject.parse_for_modulename(directory)).to eq(['myname', 'testmodule'])
    end
  end

  describe 'parse_for_module_root' do
    directory = '/testfilepath/myname-testmodule'
    describe 'stops searching when either' do
      it 'finds a Modulefile' do
        allow( File ).to receive(:exists?).and_return(false)
        allow( File ).to receive(:exists?).with("#{directory}/Modulefile").and_return(true)

        expect( subject.logger ).to_not receive(:debug).with("At root, can't parse for another directory")
        expect( subject.logger ).to receive(:debug).with("No Modulefile or metadata.json found at #{directory}/acceptance, moving up")
        expect(subject.parse_for_moduleroot("#{directory}/acceptance")).to eq(directory)
      end
      it 'finds a metadata.json file' do
        allow( File ).to receive(:exists?).and_return(false)
        allow( File ).to receive(:exists?).with("#{directory}/metadata.json").and_return(true)

        expect( subject.logger ).to_not receive(:debug).with("At root, can't parse for another directory")
        expect( subject.logger ).to receive(:debug).with("No Modulefile or metadata.json found at #{directory}/acceptance, moving up")
        expect(subject.parse_for_moduleroot("#{directory}/acceptance")).to eq(directory)
      end
    end
    it 'should recersively go up the directory to find the module files' do
      allow( File ).to receive(:exists?).and_return(false)
      expect( subject.logger ).to receive(:debug).with("No Modulefile or metadata.json found at #{directory}, moving up")
      expect( subject.logger ).to receive(:error).with("At root, can't parse for another directory")
      expect(subject.parse_for_moduleroot(directory)).to eq(nil)
    end
  end
end
