#!/bin/bash
cd "`dirname $0`"

bindhost="0.0.0.0"
callhost=`hostname`.local
containername=yacy_grid_crawler
imagename=${containername}

usage() { echo "usage: $0 [-p | --production]" 1>&2; exit 1; }

args=$(getopt -q -o ph -l production,help -- "$@")
if [ $? != 0 ]; then usage; fi
set -- $args
while true; do
  case "$1" in
    -h | --help ) usage;;
    -p | --production ) bindhost="127.0.0.1"; callhost="localhost"; imagename="yacy/${imagename}:latest"; shift 1;;
    --) break;;
  esac
done

containerRuns=$(docker ps | grep -i "${containername}" | wc -l ) 
containerExists=$(docker ps -a | grep -i "${containername}" | wc -l ) 
if [ ${containerRuns} -gt 0 ]; then
  echo "Crawler container is already running"
elif [ ${containerExists} -gt 0 ]; then
  docker start ${containername}
  echo "Crawler container re-started"
else
  if [[ $imagename != "yacy/"*":latest" ]] && [[ "$(docker images -q ${imagename} 2> /dev/null)" == "" ]]; then
      cd ..
      docker build -t ${containername} .
      cd bin
  fi
  docker run -d --restart=unless-stopped -p ${bindhost}:8300:8300 \
	 --link yacy_grid_minio --link yacy_grid_rabbitmq --link yacy_grid_elasticsearch --link yacy_grid_mcp \
	 -e YACYGRID_GRID_S3_ADDRESS=admin:12345678@yacy_grid_minio:9000 \
	 -e YACYGRID_GRID_BROKER_ADDRESS=guest:guest@yacy_grid_rabbitmq:5672 \
	 -e YACYGRID_GRID_ELASTICSEARCH_ADDRESS=yacy_grid_elasticsearch:9300 \
	 -e YACYGRID_GRID_MCP_ADDRESS=yacy_grid_mcp \
	 --name ${containername} ${imagename}
  echo "Crawler started."
fi
echo "To get the app status, open http://${callhost}:8300/yacy/grid/mcp/info/status.json"
