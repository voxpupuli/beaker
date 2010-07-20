#!/bin/bash

source spec/setup.sh
use_driver "master_and_agent_locally"

module_file "ssh/manifests/init.pp" <<'INIT'
class ssh {
    notify { 'ssh': message => "class = ssh" }
}

class ssh::client inherits ssh {
    notify { 'ssh::client': message => "class = ssh::client" }
}
INIT

execute_manifest <<'PP'
class baseclass {
    include ssh::client
}

node default {
    include baseclass
}
PP

