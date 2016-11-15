#!/bin/bash
#
# Script to rebuild Solr images in this repository locally, and test them.
# This should probably be replaced with some bashbrew.

set -e

if [[ ! -z $DEBUG ]]; then
  set -x
fi

TAG_LOCAL_BASE=docker-solr/docker-solr

# The organisation on hub.docker.com is "dockersolr".
# It should really have been "docker-solr" for consistency with the organisation
# on github but currently dashes are not allowed, see https://github.com/docker/hub-feedback/issues/373
# The hub user is "dockersolrbuilder".
TAG_PUSH_BASE=dockersolr/docker-solr

VARIANTS="alpine"

versions=()
latest=''

# map full version including variant to the build dir
declare -A dir_for_version
# map full version including variant to the tags
declare -A tags_for_version
# map minimum version to the full_version
declare -A min_versions

function get_versions {
  x_y_dirs=$(ls | grep -E '^[0-9]+\.[0-9]+$' | sort --version-sort)
  latest_dir=$(echo "$x_y_dirs" | tail -n 1)
  for x_y_dir in $x_y_dirs; do
    build_dir="./$x_y_dir"
    full_version="$(grep 'ENV SOLR_VERSION' $build_dir/Dockerfile|awk '{print $3}')"
    versions+=($full_version)
    min_version=$(echo $full_version | sed -e 's/\..*//')
    min_versions["$min_version"]=$full_version
    tags=($full_version $x_y_dir)
    if [[ $x_y_dir = $latest_dir ]]; then
      latest=$full_version
    fi
    dir_for_version["$full_version"]=$build_dir
    tags_for_version["$full_version"]="${tags[@]}"

    for variant in $VARIANTS; do
      build_dir="./$x_y_dir/$variant"
      full_version="$(grep 'ENV SOLR_VERSION' $build_dir/Dockerfile|awk '{print $3}')"
      min_version=$(echo $full_version | sed -e 's/\..*//')
      min_versions["$min_version-$variant"]="$full_version-$variant"
      versions+=("$full_version-$variant")
      tags=("$full_version-$variant" "$x_y_dir-$variant")
      dir_for_version["$full_version-$variant"]=$build_dir
      tags_for_version["$full_version-$variant"]="${tags[@]}"
    done
  done
  for v in "${!min_versions[@]}"; do
    full_version="${min_versions[$v]}"
    tags_for_version["$full_version"]="${tags_for_version["$full_version"]} $v"
  done
  tags_for_version["$latest"]="${tags_for_version["$full_version"]} latest"
}

function print_versions {
  echo "versions found:"
  for full_version in ${versions[@]}; do
    echo "  full_version=$full_version build_dir=${dir_for_version[$full_version]} tags: ${tags_for_version[$full_version]}"
  done
}

function build {
  local full_version=$1
  local build_dir=$2
  shift 2
  local tags=$@
  tag="$TAG_LOCAL_BASE:$full_version"
  # write a build script in the directory, so you can go there and invoke manually for debugging
  # Travis is still on Docker 1.9 at the moment, so do only a single tag during the build,
  # and apply the other tags after.
  cat > $build_dir/build.sh <<EOM
#!/bin/bash
set -e
if [ ! -z "\$SOLR_DOWNLOAD_SERVER" ]; then
  build_arg="--build-arg SOLR_DOWNLOAD_SERVER=\$SOLR_DOWNLOAD_SERVER"
fi
cmd="docker build --pull --rm=true \$build_arg --tag $tag ."
echo "running: \$cmd"
\$cmd
for t in $tags; do
  if [[ "\$t" = "$full_version" ]]; then
    continue
  fi
  cmd="docker tag $tag $TAG_LOCAL_BASE:\$t"
  echo "running: \$cmd"
  \$cmd
done
EOM
  chmod u+x $build_dir/build.sh
  (cd $build_dir; ./build.sh)
  echo
}

function container_cleanup {
  local container_name=$1
  previous=$(docker ps --filter name=$container_name --format '{{.ID}}' --no-trunc)
  if [[ ! -z $previous ]]; then
    echo "killing $container_name"
    docker kill $container_name || true
    sleep 2
    echo "removing $container_name"
    docker rm $container_name || true
  fi
}

# A simple kick-the-tires test to verify that the images
# run as containers, start Solr, and can load some data
function test_simple {
  local tag=$1
  echo "Test $tag"
  container_name='test_'$(echo $tag|tr ':/-' '_')
  echo "Cleaning up left-over containers from previous runs"
  container_cleanup $container_name
  echo "Running $container_name"
  docker run --name $container_name -d $tag
  SLEEP_SECS=5
  echo "Sleeping $SLEEP_SECS seconds..."
  sleep $SLEEP_SECS
  container_status=$(docker inspect --format='{{.State.Status}}' $container_name)
  echo "container $container_name status: $container_status"
  if [[ $container_status == 'exited' ]]; then
    docker logs $container_name
    exit 1
  fi
  echo "Checking that the OS matches the tag '$tag'"
  if echo "$tag" | grep -q -- -alpine; then
    alpine_version=$(docker exec --user=solr $container_name cat /etc/alpine-release || true)
    if [[ -z $alpine_version ]]; then
      echo "Could not get alpine version from container $container_name"
      container_cleanup $container_name
      exit 1
    fi
    echo "Alpine $alpine_version"
  else
    debian_version=$(docker exec --user=solr $container_name cat /etc/debian_version || true)
    if [[ -z $debian_version ]]; then
      echo "Could not get debian version from container $container_name"
      container_cleanup $container_name
      exit 1
    fi
    echo "Debian $debian_version"
  fi

  # check that the version of Solr matches the tag
  changelog_version=$(docker exec --user=solr $container_name bash -c "grep '==========' /opt/solr/CHANGES.txt | head -n 1 |  awk '{print $2}' | tr -d '= '")
  echo "Solr version $changelog_version"
  if [[ $tag = "$TAG_LOCAL_BASE:latest" ]]; then
    solr_version_from_tag=$latest
  else
    solr_version_from_tag=$(echo "$tag" | sed -e 's/^.*://' -e 's/-.*//')
  fi
  if [[ $changelog_version != $solr_version_from_tag ]]; then
    echo "Solr version mismatch"
    container_cleanup $container_name
    exit 1
  fi

  SLEEP_SECS=10
  echo "Sleeping $SLEEP_SECS seconds..."
  sleep $SLEEP_SECS
  echo "Checking Solr is running"
  status=$(docker exec $container_name /opt/docker-solr/scripts/wait-for-solr.sh)
  if ! egrep -q 'solr is running' <<<$status; then
    echo "Test test_simple $tag failed; solr did not start"
    container_cleanup $container_name
    exit 1
  fi
  echo "Creating core"
  docker exec --user=solr $container_name bin/solr create_core -c gettingstarted
  echo "Loading data"
  docker exec --user=solr $container_name bin/post -c gettingstarted example/exampledocs/manufacturers.xml
  sleep 1
  echo "Checking data"
  data=$(docker exec --user=solr $container_name wget -q -O - http://localhost:8983/solr/gettingstarted/select'?q=*:*')
  if ! egrep -q 'Round Rock' <<<$data; then
    echo "Test test_simple $tag failed; data did not load"
    exit 1
  fi
  container_cleanup $container_name

  echo "Test test_simple $tag succeeded"
}

function push {
  push_tag=$1
  # pushing to the docker registry sometimes fails, so retry
  local max_try=3
  local wait_seconds=15
  let i=1
  while true; do
    echo "Pushing $push_tag (attempt $i)"
    if docker push $push_tag; then
      echo "Pushed $push_tag"
      return
    else
      echo "Push $push_tag attempt $i failed"
      if (( $i == $max_try )); then
        echo "Failed to push $push_tag in $max_try attempts; giving up"
        exit 1
      else
        echo "retrying in $wait_seconds seconds"
        sleep $wait_seconds
      fi
    fi
    let "i++"
  done
}

function push_all {
  if [[ $TRAVIS = 'true' ]]; then
    for e in TRAVIS_BRANCH TRAVIS_COMMIT TRAVIS_PULL_REQUEST TRAVIS_PULL_REQUEST_BRANCH TRAVIS_PULL_REQUEST_SHA TRAVIS_REPO_SLUG; do
      eval "echo $e=\${$e}"
    done
    if [[ $TRAVIS_REPO_SLUG != 'docker-solr/docker-solr' ]]; then
      echo "Not pushing because this is not the docker-solr/docker-solr repo"
      return
    fi
    if [[ $TRAVIS_PULL_REQUEST != 'false' ]]; then
      echo "Not pushing because this is a pull request"
      return
    elif [[ $TRAVIS_BRANCH != 'master' ]]; then
      echo "Not pushing because this is not the master branch"
      return
    fi
  fi

  if [[ -z "$DOCKER_EMAIL" ]]; then echo "DOCKER_EMAIL not set"; exit 1; fi
  if [[ -z "$DOCKER_USERNAME" ]]; then echo "DOCKER_USERNAME not set"; exit 1; fi
  if [[ -z "$DOCKER_PASSWORD" ]]; then echo "DOCKER_PASSWORD not set"; exit 1; fi
  docker login -e="$DOCKER_EMAIL" -u="$DOCKER_USERNAME" -p="$DOCKER_PASSWORD"

  echo "current docker-solr images on this machine:"
  docker images | grep docker-solr

  for full_version in ${versions[@]}; do
    for tag in ${tags_for_version[$full_version]}; do
      cmd="docker tag $TAG_LOCAL_BASE:$tag $TAG_PUSH_BASE:$tag"
      echo "tagging: $cmd"
      $cmd
      cmd="push $TAG_PUSH_BASE:$tag"
      echo "pushing: $cmd"
      $cmd
    done
  done
}

function build_all {
  for full_version in ${versions[@]}; do
    build $full_version ${dir_for_version[$full_version]} ${tags_for_version[$full_version]}
  done
  echo "all docker-solr images:"
  docker images | grep docker-solr
}

function build_latest {
  build $latest ${dir_for_version[$latest]} ${tags_for_version[$latest]}
}

function test_all {
  for full_version in ${versions[@]}; do
    test_simple "$TAG_LOCAL_BASE:$full_version"
  done
}

function test_latest {
  test_simple "$TAG_LOCAL_BASE:latest"
}

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
get_versions

if [[ $# -eq 0 ]] ; then
  args="build_all"
else
  args="$@"
fi
for arg in $args; do
  case $arg in
    versions)
      print_versions
      ;;
    build_all)
      build_all
      ;;
    test_all)
      test_all
      ;;
    build_latest)
      build_latest
      ;;
    test_latest)
      test_latest
      ;;
    push_all)
      push_all
      ;;
    *)
      echo "Unknown option $arg"
      exit 1
  esac
done
