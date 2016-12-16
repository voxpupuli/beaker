{
    :type                 => 'foss',
    :is_puppetserver      => false,
    :puppetservice        => 'puppet.service',
    :pre_suite            => 'acceptance/pre_suite/puppet_pkg/install.rb',
    :tests                => 'acceptance/tests/puppet',
    :'master-start-curl-retries' => 30,
}.merge(eval File.read('acceptance/config/acceptance-options.rb'))
