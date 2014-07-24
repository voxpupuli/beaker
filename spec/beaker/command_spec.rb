require 'spec_helper'

module Beaker
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
      expect( cmd.environment_string_for(host, cmd.environment) ).to be == ''

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
      let(:host) { {'pathseparator' => ':'} }

      it 'returns a blank string if theres no env' do
        expect( subject.environment_string_for(host, {}) ).to be == ''
      end

      it 'takes an env hash with var_name/value pairs' do
        expect( subject.environment_string_for(host, {:HOME => '/'}) ).
          to be == "env HOME=\"/\""
      end

      it 'takes an env hash with var_name/value[Array] pairs' do
        expect( subject.environment_string_for(host, {:LD_PATH => ['/', '/tmp']}) ).
          to be == "env LD_PATH=\"/:/tmp\""
      end
    end

  end
  describe HostCommand do
    let(:command) { @command || '/bin/ls' }
    let(:args)    { @args    || Array.new }
    let(:options) { @options || Hash.new  }
    subject(:cmd) { HostCommand.new( command, args, options ) }
    let(:host)    { Hash.new }

    it 'returns a simple string passed in' do
      @command = "pants"
      expect( cmd.cmd_line host ).to be === @command
    end
    it 'returns single quoted string correctly' do
      @command = "str_p = 'pants'; str_p"
      expect( cmd.cmd_line host ).to be === @command
    end
    it 'returns empty strings when given the escaped version of the same' do
      @command = "\"\""
      expect( cmd.cmd_line host ).to be === ""
    end
  end
end
