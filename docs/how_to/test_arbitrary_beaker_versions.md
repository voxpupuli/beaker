# Test arbitrary beaker versions without modifying test code

In order to adjust the beaker version used without commiting a change to a Gemfile, we at Puppet often use a method in our code that changes the dependency based on the existence of ENV variables in the shell that beaker is executing from. The code itself looks like this:

```ruby
def location_for(place, fake_version = nil)
  if /^(git[:@][^#]*)#(.*)/.match?(place)
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif /^file:\/\/(.*)/.match?(place)
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end
```

Once this method definition is in place in the Gemfile, we can call it in a gem command, like this:

```ruby

gem 'beaker', *location_for(ENV['BEAKER_VERSION'] || '~> 2.0')
```

## Example BEAKER_VERSIONs

### git locations

```
git@github.com:puppetlabs/beaker.git#master
git://github.com/puppetlabs/beaker.git#master
```

### file locations

```
file://../relative/path/to/beaker
```

By adjusting the shell environment that beaker is running in, we can modify what version of beaker is installed by bundler on your test coordinator without modifying any of the test code. This strategy can be used for any gem dependency, and is often used when testing [beaker libraries](../concepts/beaker_libraries.md) at Puppet.
