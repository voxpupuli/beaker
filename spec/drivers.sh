. `dirname $0`/util.sh

function driver_standalone {
        function execute_manifest {
                cat | $BIN/puppet apply
        }
}

function driver_master_and_agent_locally {
        function execute_manifest {
                start_puppet_master
                cat > /tmp/puppet-$$/manifests/site.pp
                start_puppet_agent
                stop_puppet_master
        }
}

function env_driver {
        if [ -z "$PUPPET_SPEC_DRIVER" ] ; then
                PUPPET_SPEC_DRIVER=standalone
        fi
        driver_$PUPPET_SPEC_DRIVER
}
