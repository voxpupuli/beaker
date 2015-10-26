## What's Current?

* [Latest Gem Release Notes](https://github.com/puppetlabs/beaker/blob/master/HISTORY.md#LATEST)

##Requirements

* Ruby 1.9+, 2.1.5 or 2.1.6
* libxml2, libxslt (needed for the [Nokogiri](http://nokogiri.org/tutorials/installing_nokogiri.html) gem)
* g++ (needed for the [unf_ext](http://rubydoc.info/gems/unf_ext/) gem)
* curl (needed for some DSL functions to be able to execute successfully)

On a Debian or Ubuntu system you can install these using the command

    sudo apt-get install ruby-dev libxml2-dev libxslt1-dev g++ zlib1g-dev

On an EL or Fedora system use:

    sudo yum install make gcc gcc-c++ libxml2-devel libxslt-devel ruby-devel

##Installing Beaker
###From Gem (Preferred)

    $ gem install beaker
    $ beaker --help

###From Latest Git

If you need the latest and greatest (and mostly likely broken/untested/no warranty) beaker code.

* Uses <a href = "http://bundler.io/">bundler</a>

<!-- end of list -->
    $ git clone https://github.com/puppetlabs/beaker
    $ cd beaker
    $ bundle install
    $ bundle exec beaker --help

###From Latest Git, As Installed Gem

If you need the latest and greatest, but prefer to work from gem instead of through bundler.

    $ gem uninstall beaker
    $ git clone https://github.com/puppetlabs/beaker
    $ cd beaker
    $ gem build beaker.gemspec
    $ gem install ./beaker-*.gem

###Special Case Installation

The beaker gem can be built and installed in the context of the current test suite by adding the github repos as the source in the Gemspec file (see <a href = "http://bundler.io/git.html">bundler git documentation</a>).

    source 'https://rubygems.org'
    group :testing do
      gem 'cucumber', '~> 1.3.6'
      gem 'site_prism'
      gem 'selenium-webdriver'
      gem 'chromedriver2-helper'
      gem 'beaker', :github => 'puppetlabs/beaker', :branch => 'master', :ref => 'fffe7'
    end
