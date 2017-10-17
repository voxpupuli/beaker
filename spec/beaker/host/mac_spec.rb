require 'spec_helper'

module Mac
  describe Host do
    let(:options)  { @options ? @options : {} }
    let(:platform) {
      if @platform
        { :platform => Beaker::Platform.new( @platform) }
      else
        { :platform => Beaker::Platform.new( 'osx-10.12-x86_64' ) }
      end
    }
    let(:host)    { make_host( 'name', options.merge(platform) ) }

    describe '#puppet_agent_dev_package_info' do
      it 'raises an error if puppet_collection isn\'t passed' do
        expect { host.puppet_agent_dev_package_info(nil, 'maybe', :download_url => '') }.to raise_error(ArgumentError)
      end

      it 'raises an error if puppet_agent_version isn\'t passed' do
        expect { host.puppet_agent_dev_package_info('maybe', nil, :download_url => '') }.to raise_error(ArgumentError)
      end

      it 'raises an error if opts[:download_url] isn\'t passed' do
        expect { host.puppet_agent_dev_package_info('', '') }.to raise_error(ArgumentError)
      end

      it 'returns two strings that include the passed parameters' do
        allow( host ).to receive( :link_exists? ) { true }
        return1, return2 = host.puppet_agent_dev_package_info( 'pc1', 'pav1', :download_url => '' )
        expect( return1 ).to match( /pc1/ )
        expect( return2 ).to match( /pav1/ )
      end

      it 'gets the correct file type' do
        allow( host ).to receive( :link_exists? ) { true }
        _, return2 = host.puppet_agent_dev_package_info( 'pc2', 'pav2', :download_url => '' )
        expect( return2 ).to match( /\.dmg$/ )
      end

      it 'adds the version dot correctly if not supplied' do
        @platform = 'osx-10.12-x86_64'
        allow( host ).to receive( :link_exists? ) { true }
        release_path_end, release_file = host.puppet_agent_dev_package_info( 'PC3', 'pav3', :download_url => '' )
        expect( release_path_end ).to match( /10\.12/ )
        expect( release_file ).to match( /10\.12/ )
      end

      it 'runs the correct install for osx platforms (newest link format)' do
        allow( host ).to receive( :link_exists? ) { true }

        release_path_end, release_file = host.puppet_agent_dev_package_info( 'PC4', 'pav4', :download_url => '' )
        # verify the mac package name starts the name correctly
        expect( release_file ).to match( /^puppet-agent-pav4-/ )
        # verify the "newest hotness" is set correctly for the end of the mac package name
        expect( release_file ).to match( /#{Regexp.escape("-1.osx10.12.dmg")}$/ )
        # verify the release path end is set correctly
        expect( release_path_end ).to be === "apple/10.12/PC4/x86_64"
      end

      it 'runs the correct install for osx platforms (new link format)' do
        allow( host ).to receive( :link_exists? ).and_return( false, true )

        release_path_end, release_file = host.puppet_agent_dev_package_info( 'PC7', 'pav7', :download_url => '' )
        # verify the mac package name starts the name correctly
        expect( release_file ).to match( /^puppet-agent-pav7-/ )
        # verify the "new hotness" is set correctly for the end of the mac package name
        expect( release_file ).to match( /#{Regexp.escape("-1.sierra.dmg")}$/ )
        # verify the release path end isn't changed in the "new hotness" case
        expect( release_path_end ).to be === "apple/10.12/PC7/x86_64"
      end

      it 'runs the correct install for osx platforms (old link format)' do
        allow( host ).to receive( :link_exists? ) { false }

        release_path_end, release_file = host.puppet_agent_dev_package_info( 'PC8', 'pav8', :download_url => '' )
        # verify the mac package name starts the name correctly
        expect( release_file ).to match( /^puppet-agent-pav8-/ )
        # verify the old way is set correctly for the end of the mac package name
        expect( release_file ).to match( /#{Regexp.escape("-osx-10.12-x86_64.dmg")}$/ )
        # verify the release path end is set correctly to the older method
        expect( release_path_end ).to be === "apple/PC8"
      end
    end
  end
end