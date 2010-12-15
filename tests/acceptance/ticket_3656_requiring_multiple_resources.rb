test_name "#3656: requiring multiple resources"
run_manifest agents, <<'PP'
notify { 'foo':
}

notify { 'bar':
}

notify { 'baz':
    require => [Notify['foo'], Notify['bar']],
}
PP
