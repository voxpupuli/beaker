#!/bin/bash
source spec/util.sh

driver_standalone() {
  execute_manifest() {
    cat | puppet apply --confdir /tmp/puppet-$$-standalone --debug "$@"
  }

  puppet_conf() {
    cat > /tmp/puppet-$$/puppet.conf
  }
}

driver_standalone_using_files() {
  driver_standalone # sort of like inherits
  execute_manifest() {
    cat > /tmp/manifest-$$.pp
    puppet apply --confdir /tmp/puppet-$$-standalone --debug "$@" /tmp/manifest-$$.pp
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

  puppet_conf() {
    cat | tee /tmp/puppet-$$-master/puppet.conf \
      > /tmp/puppet-$$-agent/puppet.conf
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
  driver_${PUPPET_SPEC_DRIVER:=standalone}
}
