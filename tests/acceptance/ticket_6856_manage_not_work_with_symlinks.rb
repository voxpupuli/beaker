test_name "#6856 File{ links=> manage} doesn't work with dangling symlinks"

step "Prep dirs and symlinks on agents"
on agents, "mkdir /tmp/1 /tmp/2; cd /tmp/1 ; ln -s ../README ./README"

step "Apply manage manifest on agents"
apply_manifest_on agents, %q{
  file { "/tmp/2": 
    source => "/tmp/1", 
    recurse => true, 
    links => manage, 
  } 
}

step "Verify existence of Symlink"
on agents, "test -h /tmp/2/README"

step "Verify Symlink links to non-existant file"
on agents, "ls -l /tmp/2/README"
  fail_test "Symlink does not appear to be created" unless 
    stdout.include? '../README'
