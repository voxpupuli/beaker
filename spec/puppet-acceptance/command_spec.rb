require 'spec_helper'

module PuppetAcceptance
  describe Command do
    let(:command) { @command || '/bin/ls' }
    let(:args)    { @args    || Array.new }
    let(:options) { @options || Hash.new  }
    subject(:cmd) { Command.new( command, args, options ) }
    let(:host)    { Hash.new }

    it 'creates a new Command object' do
      @command = '/usr/bin/blah'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar' }

      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == @args
      expect( cmd.command ).to be == @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      expect( cmd.environment_string_for(host) ).to be == ''

    end

    describe '#options_string' do
      it 'parses things' do
        subject.options = { :v => nil, :test => nil,
                            :server => 'master', :a => 'answers.txt' }
        expect( subject.options_string ).to match /-v/
        expect( subject.options_string ).to match /--test/
        expect( subject.options_string ).to match /--server=master/
        expect( subject.options_string ).to match /-a=answers\.txt/
      end
    end

    describe '#args_string' do
      it 'joins an array' do
        subject.args = ['my/command and', nil, 'its args and opts']
        expect( subject.args_string ).to be == 'my/command and its args and opts'
      end
    end

    describe '#environment_string_for' do
      it 'returns a blank string if theres no env' do
        expect( subject.environment_string_for({}) ).to be == ''
      end

      it 'takes an env hash with var_name/value pairs' do
        expect( subject.environment_string_for({}, {:HOME => '/'}) ).
          to be == 'env HOME="/"'
      end

      it 'takes an env hash with var_name/value[Array] pairs' do
        expect( subject.environment_string_for({}, {:LD_PATH => ['/', '/tmp']}) ).
          to be == 'env LD_PATH="/:/tmp"'
      end

      it 'takes var_names where there is an array of default values' do
        env = {:PATH => { :default => [ '/bin', '/usr/bin' ] } }
        expect( subject.environment_string_for({}, env) ).
          to be == 'env PATH="/bin:/usr/bin"'

      end

      it 'takes var_names where there is an array of host specific values' do
        host = { 'pe_path' => '/opt/puppet/bin', 'foss_path' => '/usr/bin' }
        env = {:PATH => { :host => [ 'pe_path', 'foss_path' ] } }
        expect( subject.environment_string_for( host, env ) ).
          to be == 'env PATH="/opt/puppet/bin:/usr/bin"'

      end
      it 'when using an array of values it allows to specify the separator' do
        host = { 'whoosits_separator' => ' **sparkles** ' }
        env = {
          :WHOOSITS => {
            :default => [ 'whatsits', 'wonkers' ],
            :opts => {:separator => {:host => 'whoosits_separator' } }
          }
        }
        expect( subject.environment_string_for( host, env ) ).
          to be == 'env WHOOSITS="whatsits **sparkles** wonkers"'
      end
    end

    describe '#parse_env_hash_for' do
      it 'has too many responsiblities' do
        env = { :PATH => { :default => [ '/bin', '/usr/bin' ] } }
        var_array = cmd.parse_env_hash_for host, env
        expect( var_array ).to be == [ 'PATH="/bin:/usr/bin"' ]
      end
    end
  end
end
