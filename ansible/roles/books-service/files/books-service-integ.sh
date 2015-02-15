#!/bin/bash

docker run -t --name books-service-tests \
  -e TEST_TYPE=integ \
  -e DOMAIN="http://172.17.42.1" \
  -v /data/.ivy2:/root/.ivy2 \
  192.168.50.91:5000/books-service-tests
sleep 1
ret=$(docker inspect --format="{{.State.ExitCode}}" books-service-tests)
exit $ret
