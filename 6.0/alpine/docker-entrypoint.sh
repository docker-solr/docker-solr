#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
    set -- solr "$@"
fi

if [[ "$VERBOSE" -eq "yes" ]]; then
    set -x
fi

INIT_LOG=${INIT_LOG:-/opt/docker-solr/init.log}

function run_solr {
    echo "Running Solr"
    exec /opt/solr/bin/solr -f
}

if [[ "$1" = 'solr' ]]; then
    # execute files in /docker-entrypoint-initdb.d before starting solr
    # for an example see docs/print-status.sh
    shopt -s nullglob
    for f in /docker-entrypoint-initdb.d/*; do
        case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" ;;
            *)        echo "$0: ignoring $f" ;;
        esac
        echo
    done

    run_solr
elif [[ "$1" = 'solr-create' ]]; then
    # arguments are passed to "solr create"
    # To simply create a core:
    #      docker run -P -d solr solr-create -c mycore
    # To create a core from mounted config:
    #      docker run -P -d -c $PWD/myconfig:/myconfig solr solr-create -c mycore -d /myconfig
    # To create a core in a mounted directory:
    #      mkdir mycores; chown 8983:8983
    #      docker run -it --rm -P -v $PWD/mycores:/opt/solr/server/solr/mycores solr solr-create -c mycore
    echo "Executing $1 command; logging to $INIT_LOG"
    {
        /opt/docker-solr/scripts/wait-for-solr.sh
        echo "creating core with: ${@:2}"
        /opt/solr/bin/solr create "${@:2}"
        echo "created core with: ${@:2}"
    } </dev/null >$INIT_LOG 2>&1 &
    run_solr
elif [[ "$1" = 'solr-precreate' ]]; then
    # arguments are: corename configdir
    # To simply create a core:
    #      docker run -P -d solr solr-precreate mycore
    # To create a core from mounted config:
    #      docker run -P -d -c $PWD/myconfig:/myconfig solr solr-precreate mycore /myconfig
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
    run_solr
elif [[ "$1" = 'solr-demo' ]]; then
    # for example: docker run -P -d solr solr-demo
    echo "Executing $1 command; logging to $INIT_LOG"
    {
        CORE=demo
        /opt/docker-solr/scripts/wait-for-solr.sh
        echo "creating $CORE"
        /opt/solr/bin/solr create -c $CORE
        echo "created $CORE"
        echo "loading example data"
        /opt/solr/bin/post -c $CORE example/exampledocs/manufacturers.xml
        /opt/solr/bin/post -c $CORE example/exampledocs/*.xml
        /opt/solr/bin/post -c $CORE example/exampledocs/books.json
        /opt/solr/bin/post -c $CORE example/exampledocs/books.csv
        echo "loaded example data"
    } </dev/null >$INIT_LOG 2>&1 &
    run_solr
fi

exec "$@"
