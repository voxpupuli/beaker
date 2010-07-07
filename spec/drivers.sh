#!/bin/bash
. `dirname $0`/util.sh

function driver_standalone {
        function execute_manifest {
                cat | $BIN/puppet apply --confdir /tmp/puppet-$$-standalone --debug "$@" 
        }

        function puppet_conf {
                cat > /tmp/puppet-$$/puppet.conf
        }
}

function driver_standalone_using_files {
        driver_standalone # sort of like inherits
        function execute_manifest {
                cat > /tmp/manifest-$$.pp
                $BIN/puppet apply --confdir /tmp/puppet-$$-standalone --debug "$@" /tmp/manifest-$$.pp
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

        function puppet_conf {
                cat | tee /tmp/puppet-$$-master/puppet.conf > /tmp/puppet-$$-agent/puppet.conf
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
        if [ -z "${PUPPET_SPEC_DRIVER:-}" ] ; then
                PUPPET_SPEC_DRIVER=standalone
        fi
        driver_$PUPPET_SPEC_DRIVER
}
