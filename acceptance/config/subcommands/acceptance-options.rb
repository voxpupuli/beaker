{
    :pre_suite => 'acceptance/pre_suite/subcommands/',
    :tests => 'acceptance/tests/subcommands/'
}.merge(eval File.read('acceptance/config/acceptance-options.rb'))
