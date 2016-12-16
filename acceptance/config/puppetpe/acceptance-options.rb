{
    :pre_suite            => 'acceptance/pre_suite/pe/install.rb',
    :tests                => 'acceptance/tests/puppet',
    :pe_dir               => 'http://neptune.puppetlabs.lan/archives/releases/3.7.2'
}.merge(eval File.read('acceptance/config/acceptance-options.rb'))