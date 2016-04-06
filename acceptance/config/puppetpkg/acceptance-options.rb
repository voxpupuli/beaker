{
    :pre_suite            => 'acceptance/pre_suite/puppet_pkg/install.rb',
    :tests                => 'acceptance/tests/puppet'
}.merge(eval File.read('acceptance/config/acceptance-options.rb'))