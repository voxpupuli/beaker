# Very simple test case -- Should pass on all *nix

step "Perform uname on each host"
on hosts,'uname'
