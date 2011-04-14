test_name "#6928: Puppet Master --parseonly should return non-zero on a bad manifest"


# Create good and badly formatted manifests
step "Master: create valid, invalid formatted manifests"

create_remote_file(master, '/tmp/good.pp', %w{notify{good:}} )
create_remote_file(master, '/tmp/bad.pp', 'notify{bad:')

step "Master: --parseonly a valid manifest"
on master, puppet_master( %w{--parseonly /tmp/good.pp} ), :acceptable_exit_codes => [ 0 ]

step "Master: --parseonly an invalid manifest"
on master, puppet_master( %w{--parseonly /tmp/bad.pp} ), :acceptable_exit_codes => [ 0 ]
