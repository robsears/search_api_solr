#!/usr/bin/env bash

SOLR_PORT=${SOLR_PORT:-8983}
SOLR_VERSION=${SOLR_VERSION:-4.9.1}
DEBUG=${DEBUG:-0}
SOLR_CORE=${SOLR_CORE:-core0}

download() {
    FILE="$2.tgz"
    if [ -f $FILE ];
    then
       echo "File $FILE exists."
    else
       echo "File $FILE does not exist. Downloading solr from $1..."
       curl -O $1
       tar -zxf $FILE
    fi
    echo "Downloaded!"
}

is_solr_up(){
    echo "Checking if solr is up on http://localhost:$SOLR_PORT/solr/admin/cores"
    http_code=`echo $(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SOLR_PORT/solr/admin/cores")`
    return `test $http_code = "200"`
}

wait_for_solr(){
    while ! is_solr_up; do
        sleep 3
    done
}

run() {
    dir_name=$1
    solr_port=$2
    solr_core=$3
    # Run solr
    echo "Running with folder $dir_name"
    echo "Starting solr on port ${solr_port}..."

    # go to the solr folder
    cd $1/example

    if [ $DEBUG ]
    then
        java -Djetty.port=$solr_port -Dsolr.solr.home=multicore -jar start.jar &
    else
        java -Djetty.port=$solr_port -Dsolr.solr.home=multicore -jar start.jar > /dev/null 2>&1 &
    fi
    wait_for_solr
    cd ../../
    curl "http://localhost:8983/solr/admin/cores?action=CREATE&name=${solr_core}&instanceDir=${solr_core}&config=solrconfig.xml&schema=schema.xml&dataDir=data"
    echo "Started"
}


download_and_run() {
    url="http://archive.apache.org/dist/lucene/solr/$1/apache-solr-$1.tgz"
    dir_name="apache-solr-$1"

    download $url $dir_name
    add_core $dir_name $SOLR_CORE $SOLR_CONFS
    run $dir_name $SOLR_PORT $SOLR_CORE

    if [ -z "${SOLR_DOCS}" ]
    then
        echo "$solr_docs not defined, skipping initial indexing"
    else
        post_documents $dir_name $SOLR_DOCS $SOLR_CORE $SOLR_PORT
    fi
}

add_core() {
    dir_name=$1
    solr_core=$2
    solr_confs=$3
    # prepare our folders
    [[ -d "${dir_name}/example/multicore/${solr_core}" ]] || mkdir $dir_name/example/multicore/$solr_core
    [[ -d "${dir_name}/example/multicore/${solr_core}/conf" ]] || mkdir $dir_name/example/multicore/$solr_core/conf

    # copies custom configurations
    if [ -d "${solr_confs}" ] ; then
      cp -R $solr_confs/* $dir_name/example/multicore/$solr_core/conf/
    else
      for file in $solr_confs
      do
        if [ -f "${file}" ]; then
            cp $file $dir_name/example/multicore/$solr_core/conf
            echo "Copied $file into solr conf directory."
        else
            echo "${file} is not valid";
            exit 1
        fi
      done
    fi
}

post_documents() {
    dir_name=$1
    solr_docs=$2
    solr_core=$3
    solr_port=$4
      # Post documents
    if [ -z "${solr_docs}" ]
    then
        echo "$solr_docs not defined, skipping initial indexing"
    else
        echo "Indexing $solr_docs"
        java -Dtype=application/json -Durl=http://localhost:$solr_port/solr/$solr_core/update/json -jar $dir_name/example/exampledocs/post.jar $solr_docs
    fi
}

download_and_run $SOLR_VERSION