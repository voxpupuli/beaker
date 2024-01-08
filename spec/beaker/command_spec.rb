require 'spec_helper'

module Beaker
  describe Command do
    subject(:cmd) { described_class.new(command, args, options) }

    let(:command) { @command || '/bin/ls' }
    let(:args)    { @args    || [] }
    let(:options) { @options || {} }

    let(:host)    do
      h = {}
      allow(h).to receive(:environment_string).and_return('')
      h
    end

    it 'creates a new Command object' do
      @command = '/usr/bin/blah'
      @args    = %w[to the baz]
      @options = { :foo => 'bar' }

      expect(cmd.options).to eq @options
      expect(cmd.args).to eq @args
      expect(cmd.command).to eq @command

      expect(cmd.args_string).to eq 'to the baz'
      expect(cmd.options_string).to eq '--foo=bar'
    end

    describe '#:prepend_cmds' do
      it 'can prepend commands' do
        @command = '/usr/bin/blah'
        @args    = %w[to the baz]
        @options = { :foo => 'bar' }
        allow(host).to receive(:prepend_commands).and_return('aloha!')
        allow(host).to receive(:append_commands).and_return('')

        expect(cmd.cmd_line(host)).to eq "aloha! /usr/bin/blah --foo=bar to the baz"
      end

      it 'can handle no prepend_cmds' do
        @command = '/usr/bin/blah'
        @args    = %w[to the baz]
        @options = { :foo => 'bar' }
        allow(host).to receive(:prepend_commands).and_return('')
        allow(host).to receive(:append_commands).and_return('')

        expect(cmd.cmd_line(host)).to eq "/usr/bin/blah --foo=bar to the baz"
      end
    end

    describe '#:append_commands' do
      it 'can append commands' do
        @command = '/usr/bin/blah'
        @args    = %w[to the baz]
        @options = { :foo => 'bar' }
        allow(host).to receive(:prepend_commands).and_return('aloha!')
        allow(host).to receive(:append_commands).and_return('moo cow')

        expect(cmd.cmd_line(host)).to eq "aloha! /usr/bin/blah --foo=bar to the baz moo cow"
      end

      it 'can handle no append_cmds' do
        @command = '/usr/bin/blah'
        @args    = %w[to the baz]
        @options = { :foo => 'bar' }
        allow(host).to receive(:prepend_commands).and_return('')
        allow(host).to receive(:append_commands).and_return('')

        expect(cmd.cmd_line(host)).to eq "/usr/bin/blah --foo=bar to the baz"
      end
    end

    describe '#options_string' do
      it 'parses things' do
        subject.options = { :v => nil, :test => nil,
                            :server => 'master', :a => 'answers.txt', }
        expect(subject.options_string).to match(/-v/)
        expect(subject.options_string).to match(/--test/)
        expect(subject.options_string).to match(/--server=master/)
        expect(subject.options_string).to match(/-a=answers\.txt/)
      end
    end

    describe '#args_string' do
      it 'joins an array' do
        subject.args = ['my/command and', nil, 'its args and opts']
        expect(subject.args_string).to eq 'my/command and its args and opts'
      end
    end
  end

  describe HostCommand do
    subject(:cmd) { described_class.new(command, args, options) }

    let(:command) { @command || '/bin/ls' }
    let(:args)    { @args    || [] }
    let(:options) { @options || {} }

    let(:host)    { {} }

    it 'returns a simple string passed in' do
      @command = "pants"
      expect(cmd.cmd_line host).to be === @command
    end

    it 'returns single quoted string correctly' do
      @command = "str_p = 'pants'; str_p"
      expect(cmd.cmd_line host).to be === @command
    end

    it 'returns empty strings when given the escaped version of the same' do
      @command = "\"\""
      expect(cmd.cmd_line host).to be === ""
    end
  end

  describe SedCommand do
    subject(:cmd)     { described_class.new(platform, expression, filename, options) }

    let(:host)        do
      h = {}
      allow(h).to receive(:environment_string).and_return('')
      allow(h).to receive(:prepend_commands).and_return('')
      allow(h).to receive(:append_commands).and_return('')
      h
    end
    let(:platform)    { @platform   || 'unix' }
    let(:expression)  { @expression || 's/b/s/' }
    let(:filename)    { @filename   || '/fakefile' }
    let(:options)     { @options    || {} }

    it 'forms a basic sed command correctly' do
      expect(cmd.cmd_line host).to be === "sed -i -e \"#{expression}\" #{filename}"
    end

    it 'provides the -i option to rewrite file in-place on non-solaris hosts' do
      expect(cmd.cmd_line host).to include('-i')
    end

    describe 'on solaris hosts' do
      it 'removes the -i option correctly' do
        @platform = 'solaris'
        expect(cmd.cmd_line host).not_to include('-i')
      end

      it 'deals with in-place file substitution correctly' do
        @platform = 'solaris'
        default_temp_file = "#{filename}.tmp"
        expect(cmd.cmd_line host).to include(" > #{default_temp_file} && mv #{default_temp_file} #{filename} && rm -f #{default_temp_file}")
      end

      it 'allows you to provide the name of the temp file for in-place file substitution' do
        @platform = 'solaris'
        temp_file = 'mytemp.tmp'
        @options = { :temp_file => temp_file }
        expect(cmd.cmd_line host).to include(" > #{temp_file} && mv #{temp_file} #{filename} && rm -f #{temp_file}")
      end
    end
  end
end
