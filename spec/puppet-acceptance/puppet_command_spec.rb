require 'spec_helper'

module PuppetAcceptance
  #most testing already covered in Command, just need to cover env variable handling
  describe PuppetCommand do
    let(:command) { @command || '/bin/ls' }
    let(:args)    { @args    || Array.new }
    let(:options) { @options || Hash.new  }

    subject(:cmd) { PuppetCommand.new( command, *args, options ) }
    let :config do
      MockConfig.new({}, {'name' => {'platform' => @platform}}, @pe)
    end
    let(:host)    { Host.create 'name', {}, config }

    it 'creates a Windows env for a Windows host' do
      @platform = 'windows'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar' }

      expect( host ).to be_a_kind_of Windows::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == @args
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      expect( cmd.environment_string_for(host, cmd.environment) ).to be == "env PATH=\"/opt/puppet-git-repos/hiera/bin:${PATH}\" RUBYLIB=\"`cygpath -w /opt/puppet-git-repos/hiera/lib`;`cygpath -w /opt/puppet-git-repos/hiera-puppet/lib`;${RUBYLIB}\" cmd.exe /c"
    end

    it 'creates a Unix env for a Unix host' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar' }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == @args
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      expect( cmd.environment_string_for(host, cmd.environment) ).to be == "env PATH=\"/usr/bin:/opt/puppet-git-repos/hiera/bin:${PATH}\" RUBYLIB=\"/opt/puppet-git-repos/hiera/lib:/opt/puppet-git-repos/hiera-puppet/lib:${RUBYLIB}\""
    end

    it 'creates an AIX env for an AIX host' do
      @platform = 'aix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar' }

      expect( host ).to be_a_kind_of Aix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == @args
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      expect( cmd.environment_string_for(host, cmd.environment) ).to be == "env PATH=\"/usr/bin:/opt/puppet-git-repos/hiera/bin:${PATH}\" RUBYLIB=\"/opt/puppet-git-repos/hiera/lib:/opt/puppet-git-repos/hiera-puppet/lib:${RUBYLIB}\""
    end

    it 'correctly adds additional ENV to default ENV' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar', 'ENV' => {'PATH' => '/STRING_ENV/bin'} }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == @args
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      expect( cmd.environment_string_for(host, cmd.environment) ).to be == "env PATH=\"/STRING_ENV/bin\" PATH=\"/usr/bin:/opt/puppet-git-repos/hiera/bin:${PATH}\" RUBYLIB=\"/opt/puppet-git-repos/hiera/lib:/opt/puppet-git-repos/hiera-puppet/lib:${RUBYLIB}\""
    end

    it 'correctly adds additional :ENV to default ENV' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar', :ENV => {'PATH' => '/SYMBOL_ENV/bin'} }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == @args
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      expect( cmd.environment_string_for(host, cmd.environment) ).to be == "env PATH=\"/SYMBOL_ENV/bin\" PATH=\"/usr/bin:/opt/puppet-git-repos/hiera/bin:${PATH}\" RUBYLIB=\"/opt/puppet-git-repos/hiera/lib:/opt/puppet-git-repos/hiera-puppet/lib:${RUBYLIB}\""
    end

    it 'correctly adds additional :environment to default ENV' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar', :environment => {'PATH' => '/SYMBOL_ENVIRONMENT/bin'} }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == @args
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      expect( cmd.environment_string_for(host, cmd.environment) ).to be == "env PATH=\"/SYMBOL_ENVIRONMENT/bin\" PATH=\"/usr/bin:/opt/puppet-git-repos/hiera/bin:${PATH}\" RUBYLIB=\"/opt/puppet-git-repos/hiera/lib:/opt/puppet-git-repos/hiera-puppet/lib:${RUBYLIB}\""
    end

    it 'correctly adds additional environment to default ENV' do
      @platform = 'unix'
      @command = 'agent'
      @args    = [ 'to', 'the', 'baz' ]
      @options = { :foo => 'bar', 'environment' => {'PATH' => '/STRING_ENVIRONMENT/bin'} }

      expect( host ).to be_a_kind_of Unix::Host
      expect( cmd.options ).to be == @options
      expect( cmd.args    ).to be == @args
      expect( cmd.command ).to be == "puppet " + @command

      expect( cmd.args_string    ).to be == 'to the baz'
      expect( cmd.options_string ).to be == '--foo=bar'
      expect( cmd.environment_string_for(host, cmd.environment) ).to be == "env PATH=\"/STRING_ENVIRONMENT/bin\" PATH=\"/usr/bin:/opt/puppet-git-repos/hiera/bin:${PATH}\" RUBYLIB=\"/opt/puppet-git-repos/hiera/lib:/opt/puppet-git-repos/hiera-puppet/lib:${RUBYLIB}\""
    end
  end
end
