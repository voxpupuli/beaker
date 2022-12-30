require 'spec_helper'

module Beaker
  module Shared
    describe FogCredentials do
      describe "#get_fog_credentials" do
        it 'raises ArgumentError when fog file is missing' do
          expect{ get_fog_credentials( '/path/that/does/not/exist/.fog' ) }.to raise_error( ArgumentError )
        end

        it 'raises ArgumentError when fog file is empty' do
          expect( File ).to receive( :open ).and_return("")

          expect{ get_fog_credentials( '/path/that/does/not/exist/.fog') }.to raise_error( ArgumentError )
        end

        it 'raises ArgumentError when fog file does not contain "default" section and no section is specified' do
          data = { :some => { :other => :data } }

          expect( YAML ).to receive( :load_file ) { data }

          expect{ get_fog_credentials( '/path/that/does/not/exist/.fog' ) }.to raise_error( ArgumentError )
        end

        it 'raises ArgumentError when fog file does not contain another section passed by argument' do
          data = { :some => { :other => :data } }

          expect( YAML ).to receive( :load_file ) { data }

          expect{ get_fog_credentials( '/path/that/does/not/exist/.fog', :other_credential ) }.to raise_error( ArgumentError )
        end

        it 'raises ArgumentError when there are formatting errors in the fog file' do
          data = { "'default'" => { :vmpooler_token => "b2wl8prqe6ddoii70md" } }

          expect( YAML ).to receive( :load_file ) { data }

          expect{ get_fog_credentials( '/path/that/does/not/exist/.fog' ) }.to raise_error( ArgumentError )
        end

        it 'raises ArgumentError when there are syntax errors in the fog file' do
          data = ";default;\n  :vmpooler_token: z2wl8prqe0ddoii707d"

          allow( File ).to receive( :open ).and_yield( StringIO.new( data ) )

          expect{ get_fog_credentials( '/path/that/does/not/exist/.fog' ) }.to raise_error( ArgumentError, /Psych::SyntaxError/ )
        end

        it 'returns the named credential section' do
          data = {
            :default          => { :vmpooler_token => "wrong_token"},
            :other_credential => { :vmpooler_token => "correct_token" }
          }

          expect( YAML ).to receive( :load_file ) { data }

          expect( get_fog_credentials( '/path/that/does/not/exist/.fog', :other_credential )[:vmpooler_token] ).to eq( "correct_token" )
        end

        it 'returns the named credential section from ENV["FOG_CREDENTIAL"]' do
          ENV['FOG_CREDENTIAL'] = 'other_credential'
          data = {
            :default         => { :vmpooler_token => "wrong_token"},
            :other_credential => { :vmpooler_token => "correct_token" }
          }

          expect( YAML ).to receive( :load_file ) { data }

          expect( get_fog_credentials( '/path/that/does/not/exist/.fog' )[:vmpooler_token] ).to eq( "correct_token" )
          ENV.delete( 'FOG_CREDENTIAL' )
        end

        it 'returns the named credential section from ENV["FOG_CREDENTIAL"] even when an argument is provided' do
          ENV['FOG_CREDENTIAL'] = 'other_credential'
          data = {
            :default         => { :vmpooler_token => "wrong_token"},
            :other_credential => { :vmpooler_token => "correct_token" }
          }

          expect( YAML ).to receive( :load_file ) { data }

          expect( get_fog_credentials( '/path/that/does/not/exist/.fog', :default )[:vmpooler_token] ).to eq( "correct_token" )
          ENV.delete( 'FOG_CREDENTIAL' )
        end

        it 'returns the named credential section from ENV["FOG_RC"] path' do
          ENV['FOG_RC'] = '/some/other/path/to/.fog'
          data = {
            :default         => { :vmpooler_token => "correct_token"},
            :other_credential => { :vmpooler_token => "wrong_token" }
          }

          expect( YAML ).to receive( :load_file ).with( '/some/other/path/to/.fog' ) { data }

          expect( get_fog_credentials( '/path/that/does/not/exist/.fog', :default )[:vmpooler_token] ).to eq( "correct_token" )
        end
      end
    end
  end
end
