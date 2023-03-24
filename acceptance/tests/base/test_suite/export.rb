test_name 'ensure tests can export arbitrary data' do
  step 'export nested hash' do
    export({ 'middle earth' => {
             'Hobbits' => %w[Bilbo Frodo],
             'Elves' => 'Arwen',
             :total => { 'numbers' => 42 },
           } })
    export({ 'another' => 'author' })
  end
end
