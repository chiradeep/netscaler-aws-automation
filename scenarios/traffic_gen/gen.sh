#!/bin/bash

IPLIST=52.53.171.73,54.193.122.200,54.215.194.44
fab -H $IPLIST -u ec2-user -i $PRIVATE_KEY_FILE start_traffic_gen:num_clients=100,num_requests=100000,url=$URL
