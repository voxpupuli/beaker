require 'spec_helper'
require 'puppet_acceptance/dsl/install_utils'

class InstallUtilsTest
  include PuppetAcceptance::DSL::InstallUtils
end

describe InstallUtilsTest do
  context 'extract_repo_info_from' do
    [{:protocol => 'git', :path => 'git://github.com/puppetlabs/project.git'},
     {:protocol => 'ssh', :path => 'git@github.com:puppetlabs/project.git'},
     {:protocol => 'https', :path => 'https://github.com:puppetlabs/project'}
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
      expect(ordered_repos[0][:name]).to be == 'facter'
      expect(ordered_repos[1][:name]).to be == 'puppet'
      expect(ordered_repos[2][:name]).to be == 'puppet_plugin'
    end
  end

  context 'find_git_repo_versions' do
    it 'returns a hash of :name => version' do
      host        = stub('Host')
      repository  = {:name => 'name'}
      path        = '/path/to/repo'
      cmd         = 'cd /path/to/repo/name && git describe || true'
      blah = (Struct.new('Result', :stdout)).new('2')

      subject.stub(:step)
      subject.should_receive(:on).with(host, cmd).and_yield(subject)
      subject.stub(:result).and_return(blah)

      version = subject.find_git_repo_versions(host, path, repository)

      expect(version).to be == {'name' => '2'}
    end
  end

  context 'install_from_git' do
    it 'install_from_git needs refactoring and a lot of testing'
  end
end
