#!/bin/bash
set -x
directory=$1
cd $directory
for logfile in *.log.*
do
	gzip $logfile
done

for logzip in *.log.*.gz
do
	d=${logzip#*-}
	d=${d%%.*}
	aws s3 cp $logzip s3://test-logrotate-foo/dt=$d/$logzip
	rm $logzip
done
