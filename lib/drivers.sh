#!/bin/bash
source lib/util.sh

driver_standalone() {
  execute_manifest() {
    mkdir -p /tmp/puppet-$$-standalone/manifests
    cat | puppet apply --confdir /tmp/puppet-$$-standalone \
      --verbose --debug \
      --color false \
      --manifestdir /tmp/puppet-$$-standalone/manifests \
      --modulepath /tmp/puppet-$$-standalone/modules "$@"
  }

  puppet_conf() {
    cat > /tmp/puppet-$$/puppet.conf
  }

  manifest_file() {
    mkdir -p /tmp/puppet-$$-standalone/manifests
    cat > /tmp/puppet-$$-standalone/manifests/$1
  }

  module_file() {
    mkdir -p $(dirname /tmp/puppet-$$-standalone/modules/$1)
    cat > /tmp/puppet-$$-standalone/modules/$1
  }
}

driver_standalone_using_files() {
  driver_standalone # sort of like inherits

  execute_manifest() {
    cat > /tmp/manifest-$$.pp
    mkdir -p /tmp/puppet-$$-standalone/manifests
    puppet apply --confdir /tmp/puppet-$$-standalone \
      --debug  \
      --manifestdir /tmp/puppet-$$-standalone/manifests \
      --modulepath /tmp/puppet-$$-standalone/modules \
      "$@" /tmp/manifest-$$.pp
  }

}

driver_master_and_agent_locally() {
  mkdir -p /tmp/puppet-$$-master/manifests/
  mkdir -p /tmp/puppet-$$-agent

  execute_manifest() {
    start_puppet_master
    cat > /tmp/puppet-$$-master/manifests/site.pp
    start_puppet_agent "$@"
    stop_puppet_master
  }

  manifest_file() {
    mkdir -p /tmp/puppet-$$-master/manifests
    cat > /tmp/puppet-$$-master/manifests/$1
  }

  module_file() {
    mkdir -p `dirname /tmp/puppet-$$-master/modules/$1`
    cat > /tmp/puppet-$$-master/modules/$1
  }

  puppet_conf() {
    cat | tee /tmp/puppet-$$-master/puppet.conf \
      > /tmp/puppet-$$-agent/puppet.conf
  }

  module_file() {
    mkdir -p $(dirname /tmp/puppet-$$-master/modules/$1)
    cat > /tmp/puppet-$$-master/modules/$1
  }
}

driver_master_and_agent_locally_using_old_executables() {
  driver_master_and_agent_locally # sort of like inherits

  execute_manifest() {
    start_puppetmasterd
    cat > /tmp/puppet-$$-master/manifests/site.pp
    start_puppetd "$@"
    stop_puppetmasterd
  }
}

env_driver() {
  if [ -z "${PUPPET_ACCEPTANCE_DRIVER:-}" ] ; then
    PUPPET_ACCEPTANCE_DRIVER=standalone
  fi
  driver_$PUPPET_ACCEPTANCE_DRIVER
}

use_driver() { 
  local driver="${PUPPET_ACCEPTANCE_DRIVER}"
  if [ -z "$driver" -o "$driver" == "$1" ]; then
    driver_$1
  else
    NOT_APPLICABLE
  fi
}

