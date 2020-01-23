{
    :pre_suite            => 'acceptance/pre_suite/pe/install.rb',
    :tests                => 'acceptance/tests/puppet',
    :pe_dir               => 'https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/archives/releases/2018.1.11'
}.merge(eval File.read('acceptance/config/acceptance-options.rb'))
