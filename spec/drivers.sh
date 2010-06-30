. `dirname $0`/util.sh

function driver_standalone {
        function execute_manifest {
                cat | $BIN/puppet apply --confdir /tmp/puppet-$$ --debug
        }

        function puppet_conf {
                cat > /tmp/puppet-$$/puppet.conf
        }
}

function driver_master_and_agent_locally {
        mkdir -p /tmp/puppet-$$/manifests/

        function execute_manifest {
                start_puppet_master
                cat > /tmp/puppet-$$/manifests/site.pp
                start_puppet_agent
                stop_puppet_master
        }

        function puppet_conf {
                cat > /tmp/puppet-$$/puppet.conf
        }
}

function env_driver {
        if [ -z "$PUPPET_SPEC_DRIVER" ] ; then
                PUPPET_SPEC_DRIVER=standalone
        fi
        driver_$PUPPET_SPEC_DRIVER
}
