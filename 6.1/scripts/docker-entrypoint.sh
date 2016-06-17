#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
    set -- solr "$@"
fi

if [[ "$VERBOSE" = "yes" ]]; then
    set -x
fi

INIT_LOG=${INIT_LOG:-/opt/docker-solr/init.log}

# configure Solr to run on the local interface, and start it running in the background
function initial_solr_begin {
    echo "Configuring Solr to bind to 127.0.0.1"
    cp /opt/solr/bin/solr.in.sh /opt/solr/bin/solr.in.sh.orig
    echo "SOLR_OPTS=-Djetty.host=127.0.0.1" >> /opt/solr/bin/solr.in.sh
    echo "Running solr in the background. Logs are in /opt/solr/server/logs"
    /opt/solr/bin/solr start
    max_try=${MAX_TRY:-12}
    wait_seconds=${WAIT_SECONDS:-5}
    if ! /opt/docker-solr/scripts/wait-for-solr.sh "$max_try" "$wait_seconds"; then
        echo "Could not start Solr."
        if [ -f /opt/solr/server/logs/solr.log ]; then
            echo "Here is the log:"
            cat /opt/solr/server/logs/solr.log
        fi
        exit 1
    fi
}

# stop the background Solr, and restore the normal configuration
function initial_solr_end {
    echo "Shutting down the background Solr"
    /opt/solr/bin/solr stop
    echo "Restoring Solr configuration"
    mv /opt/solr/bin/solr.in.sh.orig /opt/solr/bin/solr.in.sh
    echo "Running Solr in the foreground"
}

if [[ "$1" = 'solr' ]]; then
    # execute files in /docker-entrypoint-initdb.d before starting solr
    # for an example see docs/set-heap.sh
    shopt -s nullglob
    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" ;;
            *)        echo "$0: ignoring $f" ;;
        esac
        echo
    done

    shift; set -- solr -f "$@"
elif [[ "$1" = 'solr-create' ]]; then
    # arguments are passed to "solr create"
    # To simply create a core:
    #      docker run -P -d solr solr-create -c mycore
    # To create a core from mounted config:
    #      docker run -P -d -v $PWD/myconfig:/myconfig solr solr-create -c mycore -d /myconfig
    # To create a core in a mounted directory:
    #      mkdir mycores; chown 8983:8983
    #      docker run -it --rm -P -v $PWD/mycores:/opt/solr/server/solr/mycores solr solr-create -c mycore
    echo "Executing $1 command"
    sentinel=/opt/docker-solr/core_created
    if [ -f $sentinel ]; then
        echo "skipping core creation"
    else
        initial_solr_begin
        echo "Creating core with: ${@:2}"
        /opt/solr/bin/solr create "${@:2}"

        # See https://github.com/docker-solr/docker-solr/issues/27
        echo "Checking core"
        if ! wget -O - 'http://localhost:8983/solr/admin/cores?action=STATUS' | grep -q instanceDir; then
          echo "Could not find any cores"
          exit 1
        fi

        echo "Created core with: ${@:2}"
        initial_solr_end
        touch $sentinel
    fi
    set -- solr -f
elif [[ "$1" = 'solr-precreate' ]]; then
    # arguments are: corename configdir
    # To simply create a core:
    #      docker run -P -d solr solr-precreate mycore
    # To create a core from mounted config:
    #      docker run -P -d -v $PWD/myconfig:/myconfig solr solr-precreate mycore /myconfig
    # To create a core in a mounted directory:
    #      mkdir mycores; chown 8983:8983
    #      docker run -it --rm -P -v $PWD/mycores:/opt/solr/server/solr/mycores solr solr-precreate mycore
    echo "Executing $1 command"
    CORE=${2:-gettingstarted}
    CONFIG_SOURCE=${3:-'/opt/solr/server/solr/configsets/basic_configs'}
    coresdir="/opt/solr/server/solr/mycores"
    mkdir -p $coresdir
    coredir="$coresdir/$CORE"
    if [[ ! -d $coredir ]]; then
        cp -r $CONFIG_SOURCE/ $coredir
        touch "$coredir/core.properties"
        echo created "$CORE"
    else
        echo "core $CORE already exists"
    fi
    set -- solr -f
elif [[ "$1" = 'solr-demo' ]]; then
    # for example: docker run -P -d solr solr-demo
    echo "Executing $1 command"
    sentinel=/opt/docker-solr/demo_created
    if [ -f $sentinel ]; then
    echo "skipping demo creation"
    else
        CORE=demo
        initial_solr_begin
        echo "Creating $CORE"
        /opt/solr/bin/solr create -c "$CORE"
        echo "Created $CORE"
        echo "Loading example data"
        /opt/solr/bin/post -c $CORE example/exampledocs/manufacturers.xml
        /opt/solr/bin/post -c $CORE example/exampledocs/*.xml
        /opt/solr/bin/post -c $CORE example/exampledocs/books.json
        /opt/solr/bin/post -c $CORE example/exampledocs/books.csv
        echo "Loaded example data"
        initial_solr_end
        touch $sentinel
    fi
    set -- solr -f
fi

exec "$@"
