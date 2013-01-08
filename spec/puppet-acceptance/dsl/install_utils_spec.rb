require 'spec_helper'

class ClassMixedWithDSLInstallUtils
  include PuppetAcceptance::DSL::InstallUtils
  include PuppetAcceptance::DSL::Structure
end

describe ClassMixedWithDSLInstallUtils do
  context 'extract_repo_info_from' do
    [{:protocol => 'git', :path => 'git://github.com/puppetlabs/project.git'},
     {:protocol => 'ssh', :path => 'git@github.com:puppetlabs/project.git'},
     {:protocol => 'https', :path => 'https://github.com:puppetlabs/project'},
     {:protocol => 'file', :path => 'file:///home/example/project'}
    ].each do |type|
      it "handles #{type[:protocol]} uris" do
        uri = "#{type[:path]}#master"
        repo_info = subject.extract_repo_info_from uri
        expect(repo_info[:name]).to be == 'project'
        expect(repo_info[:path]).to be ==  type[:path]
        expect(repo_info[:rev]).to  be == 'master'
      end
    end
  end

  context 'order_packages' do
    it 'orders facter, hiera before puppet, before anything else' do
      named_repos = [
        {:name => 'puppet_plugin'}, {:name => 'puppet'}, {:name => 'facter'}
      ]
      ordered_repos = subject.order_packages named_repos
      expect( ordered_repos[0][:name] ).to be == 'facter'
      expect( ordered_repos[1][:name] ).to be == 'puppet'
      expect( ordered_repos[2][:name] ).to be == 'puppet_plugin'
    end
  end

  context 'find_git_repo_versions' do
    it 'returns a hash of :name => version' do
      host        = stub('Host')
      repository  = {:name => 'name'}
      path        = '/path/to/repo'
      cmd         = 'cd /path/to/repo/name && git describe || true'
      logger = double.as_null_object

      subject.should_receive( :logger ).and_return( logger )
      subject.should_receive( :on ).with(host, cmd).and_yield
      subject.should_receive( :stdout ).and_return( '2' )

      version = subject.find_git_repo_versions(host, path, repository)

      expect(version).to be == {'name' => '2'}
    end
  end

  context 'install_from_git' do
    it 'does a ton of stuff it probably shouldnt' do
      repo = { :name => 'puppet',
               :path => 'git://my.server.net/puppet.git',
               :rev => 'master' }
      path = '/path/to/repos'
      host = { 'platform' => 'debian' }
      logger = double.as_null_object

      subject.should_receive( :logger ).any_number_of_times.and_return( logger )
      subject.should_receive( :on ).exactly( 4 ).times

      subject.install_from_git( host, path, repo )
    end
  end
end
