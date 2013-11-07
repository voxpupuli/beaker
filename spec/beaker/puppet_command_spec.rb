require 'spec_helper'

module Beaker
  #most testing already covered in Command, just need to cover env variable handling
  describe PuppetCommand do
    let(:command) { @command || '/bin/ls' }
    let(:args)    { @args    || Array.new }
    let(:options) { @options || {} }
    subject(:cmd) { PuppetCommand.new( command, args, options ) }
    let(:host)    { make_host( 'name', { :platform => @platform } ) }

    let( :nix_path ) { %q[PATH="/usr/bin:/opt/puppet-git-repos/hiera/bin:${PATH}"] }
    let( :nix_lib  ) { %q[RUBYLIB="/opt/puppet-git-repos/hiera/lib:/opt/puppet-git-repos/hiera-puppet/lib:${RUBYLIB}"] }

    it 'creates a Windows env for a Windows host' do
      @platform = 'windows'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar' }

      expect( host ).to be_a_kind_of Windows::Host
      expect( cmd.options ).to be == options
      expect( cmd.args    ).to be == [@args]
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'

      win_path  = %q[PATH="/opt/puppet-git-repos/hiera/bin:${PATH}"]
      win_lib   = %q[RUBYLIB="`cygpath -w /opt/puppet-git-repos/hiera/lib`;`cygpath -w /opt/puppet-git-repos/hiera-puppet/lib`;${RUBYLIB}"]
      cmd_exe   = %q[cmd.exe /c]

      command_line = cmd.environment_string_for( host, cmd.environment )
      expect( command_line ).to include( win_path )
      expect( command_line ).to include( win_lib )
      expect( command_line ).to include( cmd_exe )
    end

    it 'creates a Unix env for a Unix host' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar' }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == [@args]
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'

      command_line = cmd.environment_string_for( host, cmd.environment )
      expect( command_line ).to include( nix_path )
      expect( command_line ).to include( nix_lib )
    end

    it 'creates an AIX env for an AIX host' do
      @platform = 'aix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar' }

      expect( host ).to be_a_kind_of Aix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == [@args]
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'

      command_line = cmd.environment_string_for( host, cmd.environment )
      expect( command_line ).to include( nix_path )
      expect( command_line ).to include( nix_lib )
    end

    it 'correctly adds additional ENV to default ENV' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar', 'ENV' => {'PATH' => '/STRING_ENV/bin'} }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == [@args]
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      custom = %q[PATH="/STRING_ENV/bin"]

      command_line = cmd.environment_string_for( host, cmd.environment )
      expect( command_line ).to include( nix_path )
      expect( command_line ).to include( nix_lib )
      expect( command_line ).to include( custom )
    end

    it 'correctly adds additional :ENV to default ENV' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar', :ENV => {'PATH' => '/SYMBOL_ENV/bin'} }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == [@args]
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'

      custom = %q[PATH="/SYMBOL_ENV/bin"]
      command_line = cmd.environment_string_for( host, cmd.environment )
      expect( command_line ).to include( nix_path )
      expect( command_line ).to include( nix_lib )
      expect( command_line ).to include( custom )
    end

    it 'correctly adds additional :environment to default ENV' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar', :environment => {'PATH' => '/SYMBOL_ENVIRONMENT/bin'} }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == [@args]
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'

      custom = %q[PATH="/SYMBOL_ENVIRONMENT/bin"]
      command_line = cmd.environment_string_for( host, cmd.environment )
      expect( command_line ).to include( nix_path )
      expect( command_line ).to include( nix_lib )
      expect( command_line ).to include( custom )
    end

    it 'correctly adds additional environment to default ENV' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar', 'environment' => {'PATH' => '/STRING_ENVIRONMENT/bin'} }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == [@args]
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'

      custom = %q[PATH="/STRING_ENVIRONMENT/bin"]
      command_line = cmd.environment_string_for( host, cmd.environment )
      expect( command_line ).to include( nix_path )
      expect( command_line ).to include( nix_lib )
      expect( command_line ).to include( custom )
    end
  end
end
