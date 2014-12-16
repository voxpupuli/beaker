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
  describe SedCommand do
    let(:host)        { Hash.new }
    let(:platform)    { @platform   || 'unix' }
    let(:expression)  { @expression || 's/b/s/' }
    let(:filename)    { @filename   || '/fakefile' }
    let(:options)     { @options    || Hash.new  }
    subject(:cmd)     { SedCommand.new( platform, expression, filename, options ) }

    it 'forms a basic sed command correctly' do
      expect( cmd.cmd_line host ).to be === "sed -i -e \"#{expression}\" #{filename}"
    end

    it 'provides the -i option to rewrite file in-place on non-solaris hosts' do
      expect( cmd.cmd_line host ).to include('-i')
    end

    describe 'on solaris hosts' do
      it 'removes the -i option correctly' do
        @platform = 'solaris'
        expect( cmd.cmd_line host ).not_to include('-i')
      end

      it 'deals with in-place file substitution correctly' do
        @platform = 'solaris'
        default_temp_file = "#{filename}.tmp"
        expect( cmd.cmd_line host ).to include(" > #{default_temp_file} && mv #{default_temp_file} #{filename} && rm -f #{default_temp_file}")
      end

      it 'allows you to provide the name of the temp file for in-place file substitution' do
        @platform = 'solaris'
        temp_file = 'mytemp.tmp'
        @options = { :temp_file => temp_file }
        expect( cmd.cmd_line host ).to include(" > #{temp_file} && mv #{temp_file} #{filename} && rm -f #{temp_file}")
      end
    end
  end
end
