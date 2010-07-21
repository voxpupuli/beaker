#!/bin/bash
. spec/util.sh

function driver_standalone {
    function execute_manifest {
        mkdir -p /tmp/puppet-$$-standalone/manifests
        cat | $BIN/puppet apply --confdir /tmp/puppet-$$-standalone --debug --manifestdir /tmp/puppet-$$-standalone/manifests --modulepath /tmp/puppet-$$-standalone/modules "$@" 
    }

    function puppet_conf {
        cat > /tmp/puppet-$$/puppet.conf
    }
    
    function manifest_file {
        mkdir -p /tmp/puppet-$$-standalone/manifests
        cat > /tmp/puppet-$$-standalone/manifests/$1
    }

    function module_file {
        mkdir -p `dirname /tmp/puppet-$$-standalone/modules/$1`
        cat > /tmp/puppet-$$-standalone/modules/$1
    }
}

function driver_standalone_using_files {
    driver_standalone # sort of like inherits
    
    function execute_manifest {
        cat > /tmp/manifest-$$.pp
        mkdir -p /tmp/puppet-$$-standalone/manifests
        $BIN/puppet apply --confdir /tmp/puppet-$$-standalone --debug  --manifestdir /tmp/puppet-$$-standalone/manifests --modulepath /tmp/puppet-$$-standalone/modules "$@" /tmp/manifest-$$.pp
    }

}

function driver_master_and_agent_locally {
    mkdir -p /tmp/puppet-$$-master/manifests/
    mkdir -p /tmp/puppet-$$-agent
    
    function execute_manifest {
        start_puppet_master
        cat > /tmp/puppet-$$-master/manifests/site.pp
        start_puppet_agent "$@"
        stop_puppet_master
    }

    function manifest_file {
        mkdir -p /tmp/puppet-$$-master/manifests
        cat > /tmp/puppet-$$-master/manifests/$1
    }

    function module_file {
        mkdir -p `dirname /tmp/puppet-$$-master/modules/$1`
        cat > /tmp/puppet-$$-master/modules/$1
    }

    function puppet_conf {
        cat | tee /tmp/puppet-$$-master/puppet.conf > /tmp/puppet-$$-agent/puppet.conf
    }

    function module_file {
        mkdir -p `dirname /tmp/puppet-$$-master/modules/$1`
        cat > /tmp/puppet-$$-master/modules/$1
    }
}

function driver_master_and_agent_locally_using_old_executables {
    driver_master_and_agent_locally # sort of like inherits
    
    function execute_manifest {
        start_puppetmasterd
        cat > /tmp/puppet-$$-master/manifests/site.pp
        start_puppetd "$@"
        stop_puppetmasterd
    }
}


function env_driver {
    if [ -z "${PUPPET_ACCEPTANCE_DRIVER:-}" ] ; then
        PUPPET_ACCEPTANCE_DRIVER=standalone
    fi
    driver_$PUPPET_ACCEPTANCE_DRIVER
}

function use_driver { 
    if [ -z "$PUPPET_ACCEPTANCE_DRIVER" ] || [ "$PUPPET_ACCEPTANCE_DRIVER" = "$1" ] ; then
        driver_$1
    else
        NOT_APPLICABLE
    fi
}

