require "spec_helper"

module PuppetAcceptance
  describe Options do
    repo = Options.repo?
    it "has repo set to git://github.com/puppetlabs" do
      expect repo == 'git://github.com/puppetlabs'
    end

    #test parse_install_options
    it "can transform --install PUPPET/3.1 into #{repo}/puppet.git#3.1" do
      opts = ["PUPPET/3.1"]
      expect(Options.parse_install_options(opts)).to be === ["#{repo}/puppet.git#3.1"] 
    end
    it "can transform --install FACTER/v.1.0 into #{repo}/facter.git#v.1.0" do
      opts = ["FACTER/v.1.0"]
      expect(Options.parse_install_options(opts)).to be === ["#{repo}/facter.git#v.1.0"] 
    end
    it "can transform --install HIERA/xyz into #{repo}/hiera.git#xyz" do
      opts = ["HIERA/xyz"]
      expect(Options.parse_install_options(opts)).to be === ["#{repo}/hiera.git#xyz"] 
    end
    it "can transform --install HIERA-PUPPET/path/to/repo into #{repo}/hiera-puppet.git#path/to/repo" do
      opts = ["HIERA-PUPPET/path/to/repo"]
      expect(Options.parse_install_options(opts)).to be === ["#{repo}/hiera-puppet.git#path/to/repo"] 
    end
    it "can transform --install PUPPET/3.1,FACTER/v.1.0 into #{repo}/puppet.git#3.1,#{repo}/facter.git#v.1.0" do
      opts = ["PUPPET/3.1", "FACTER/v.1.0"]
      expect(Options.parse_install_options(opts)).to be === ["#{repo}/puppet.git#3.1", "#{repo}/facter.git#v.1.0"] 
    end
    it "can leave --install git://github.com/puppetlabs/puppet.git#my/full/path alone" do
      opts = ["git://github.com/puppetlabs/puppet.git#my/full/path"]
      expect(Options.parse_install_options(opts)).to be === ["git://github.com/puppetlabs/puppet.git#my/full/path"]
    end

  end
end
