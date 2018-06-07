# Beaker Installation

In most cases, beaker is running on a system separate from the SUT; we will commonly refer to this system as the beaker coordinator. This page outlines how to install requirements for the beaker coordinator and options for the installation of beaker itself.

## Beaker Requirements

* Ruby >= 2.1.8 (but we [only test on >= 2.2.5](installation.md#ruby-version))
* libxml2, libxslt (needed for the [Nokogiri](http://nokogiri.org/tutorials/installing_nokogiri.html) gem)
* g++ (needed for the [unf_ext](http://rubydoc.info/gems/unf_ext/) gem)
* curl (needed for some DSL functions to be able to execute successfully)

On a Debian or Ubuntu system you can install these using the command

```console
  $ sudo apt-get install ruby-dev libxml2-dev libxslt1-dev g++ zlib1g-dev
```

On an EL or Fedora system use:

```console
  $ sudo yum install make gcc gcc-c++ libxml2-devel libxslt-devel ruby-devel
```

## Installing Beaker

These instructions apply to installing Beaker for use; to set up a development environment for Beaker itself, [see below](#for-development).

### From Gem (Preferred)

```console
  $ gem install beaker
  $ beaker --help
```

### From Latest Git

If you need the latest and greatest (and mostly likely broken/untested/no warranty) beaker code.

* Uses <a href = "http://bundler.io/">bundler</a>

```console
  $ git clone https://github.com/puppetlabs/beaker
  $ cd beaker
  $ bundle install
  $ bundle exec beaker --help
```

### From Latest Git, As Installed Gem

If you need the latest and greatest, but prefer to work from gem instead of through bundler.

```console
    $ gem uninstall beaker
    $ git clone https://github.com/puppetlabs/beaker
    $ cd beaker
    $ gem build beaker.gemspec
    $ gem install ./beaker-*.gem
```

### Special Case Installation

The beaker gem can be built and installed in the context of the current test suite by adding the github repos as the source in the Gemspec file (see <a href = "http://bundler.io/git.html">bundler git documentation</a>).

```ruby
    source 'https://rubygems.org'
    group :testing do
      gem 'cucumber', '~> 1.3.6'
      gem 'site_prism'
      gem 'selenium-webdriver'
      gem 'chromedriver2-helper'
      gem 'beaker', :github => 'puppetlabs/beaker', :branch => 'master', :ref => 'fffe7'
    end
```

## For Development

If you intend to make changes to Beaker itself, follow these instructions.

### Recommended Tools

It may be necessary to test Beaker against multiple versions of Ruby. The maintainers use [`rbenv`](https://github.com/rbenv/rbenv) to manage multiple Ruby versions; you can install it with Homebrew. You'll also want [`rbenv-bundler`](https://github.com/carsomyr/rbenv-bundler) to keep Gem dependencies from conflicting.

### Setup for Development

While most users will use Beaker as a Gem installed from some repository, you will need a live repo to work with. Here's how to configure Beaker and its dependencies so you can start contributing:

* Clone your fork of Beaker
* Install Beaker's dependencies into `vendor/bundle`:
  ```console
    $ cd beaker/
    $ bundle install --path vendor/bundle
  ```
  * Installing the dependencies globally ~~may~~ *will probably* cause conflicts and is not recommended.
  * Please use `vendor/bundle`, not `_vendor` or `.vendor`.
* Test your new environment by seeing if the spec tests pass (beaker/master is maintained in an always-passing state):
  ```console
    $ rake test:spec # assuming you have rbenv-bundler
    # or
    $ bundle exec rake test:spec # if you're *sure* your dependencies are tidy
  ```

### Contributing

Contributions to Beaker are welcomed, see [CONTRIBUTING.md](/CONTRIBUTING.md)) for instructions.

## Ruby Version

In moving to beaker 3.0, we added in a hard requirement that a beaker test writer be using Ruby 2.2.5 or higher. Since Puppet has versions that support earlier versions of Ruby, this made writing tests more difficult than it needed to be.

In order to make this easier, in beaker 3.13.0 we've relaxed this requirement to Ruby 2.1.8. Note that the beaker team does not internally test Ruby versions below 2.2.5, and that if bugs are submitted that are found to be specific to versions below 2.2.5, they will not be worked on by the beaker team. This doesn't mean we won't merge fixes to bugs that are specific to those versions that are submitted by the community, however.
