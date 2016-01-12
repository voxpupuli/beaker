require 'spec_helper'

module Mac
  describe Host do
    let(:options)  { @options ? @options : {} }
    let(:platform) {
      if @platform
        { :platform => Beaker::Platform.new( @platform) }
      else
        { :platform => Beaker::Platform.new( 'osx-10.9-x86_64' ) }
      end
    }
    let(:host)    { make_host( 'name', options.merge(platform) ) }

    describe '#puppet_agent_dev_package_info' do
      it 'raises an error if puppet_collection isn\'t passed' do
        expect { host.puppet_agent_dev_package_info(nil, 'maybe') }.to raise_error(ArgumentError)
      end

      it 'raises as error if puppet_agent_version isn\'t passed' do
        expect { host.puppet_agent_dev_package_info('maybe', nil) }.to raise_error(ArgumentError)
      end

      it 'returns two strings that include the passed parameters' do
        allow( host ).to receive( :link_exists? ) { true }
        return1, return2 = host.puppet_agent_dev_package_info( 'pc1', 'pav1' )
        expect( return1 ).to match( /pc1/ )
        expect( return2 ).to match( /pav1/ )
      end

      it 'gets the correct file type' do
        allow( host ).to receive( :link_exists? ) { true }
        _, return2 = host.puppet_agent_dev_package_info( 'pc1', 'pav1' )
        expect( return2 ).to match( /\.dmg$/ )
      end

      it 'adds the version dot correctly if not supplied' do
        @platform = 'osx-109-x86_64'
        allow( host ).to receive( :link_exists? ) { true }
        release_path_end, release_file = host.puppet_agent_dev_package_info( 'PC3', 'pav3' )
        expect( release_path_end ).to match( /10\.9/ )
        expect( release_file ).to match( /10\.9/ )
      end

      it 'runs the correct install for osx platforms (newest link format)' do
        allow( host ).to receive( :link_exists? ) { true }

        release_path_end, release_file = host.puppet_agent_dev_package_info( 'PC4', 'pav4' )
        # verify the mac package name starts the name correctly
        expect( release_file ).to match( /^puppet-agent-pav4-/ )
        # verify the "newest hotness" is set correctly for the end of the mac package name
        expect( release_file ).to match( /#{Regexp.escape("-1.osx10.9.dmg")}$/ )
        # verify the release path end is set correctly
        expect( release_path_end ).to be === "apple/10.9/PC4/x86_64"
      end

      it 'runs the correct install for osx platforms (new link format)' do
        allow( host ).to receive( :link_exists? ).and_return( false, true )

        release_path_end, release_file = host.puppet_agent_dev_package_info( 'PC7', 'pav7' )
        # verify the mac package name starts the name correctly
        expect( release_file ).to match( /^puppet-agent-pav7-/ )
        # verify the "new hotness" is set correctly for the end of the mac package name
        expect( release_file ).to match( /#{Regexp.escape("-1.mavericks.dmg")}$/ )
        # verify the release path end isn't changed in the "new hotness" case
        expect( release_path_end ).to be === "apple/10.9/PC7/x86_64"
      end

      it 'runs the correct install for osx platforms (old link format)' do
        allow( host ).to receive( :link_exists? ) { false }

        release_path_end, release_file = host.puppet_agent_dev_package_info( 'PC8', 'pav8' )
        # verify the mac package name starts the name correctly
        expect( release_file ).to match( /^puppet-agent-pav8-/ )
        # verify the old way is set correctly for the end of the mac package name
        expect( release_file ).to match( /#{Regexp.escape("-osx-10.9-x86_64.dmg")}$/ )
        # verify the release path end is set correctly to the older method
        expect( release_path_end ).to be === "apple/PC8"
      end
    end
  end
end