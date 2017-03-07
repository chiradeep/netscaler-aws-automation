#!/bin/bash -v
exec 1> >(logger -s -t $(basename $0)) 2>&1

NS_INSTANCE_ID=i-098a3c3bead
NS_PASSWORD=$NS_INSTANCE_ID
NSIP=172.31.23.100

yum -y install expect
(cd /tmp; curl -s -O https://s3-us-west-2.amazonaws.com/netscaler-web-log-client/11/nswl_linux-11.1-51.26.rpm)
yum -y install /tmp/nswl_linux-11.1-51.26.rpm 
yum -y install monit

adduser nswl -s /sbin/nologin
mkdir -p /home/nswl/logs/
chmod a+rwx /home/nswl/logs/

cat > /etc/weblog_client.conf <<EOF
Filter default 

begin default
	logFormat		W3C %{%Y-%m-%dT%H:%M:%S}t %v %A:%p  %M %s %j %J "%m %S://%v%U" %+{user-agent}i
	logInterval		Hourly
	logFileSizeLimit	10
	logFilenameFormat	/home/nswl/logs/netscaler-%{%y-%m-%d}t.$NS_INSTANCE_ID.log
end default

EOF
chmod a+rw /etc/weblog_client.conf

cat > /usr/local/bin/addns.exp <<EOF
#!/usr/bin/expect

set timeout -1
set ip [lindex \$argv 0]

set password [lindex \$argv 1]

spawn /usr/local/netscaler/bin/nswl -addns -f /etc/weblog_client.conf

expect "NSIP:"
send -- "\$ip\r"
expect "userid:"
send -- "nsroot\r"
expect "password:"
send -- "\$password\r"
expect "Done !!\r"

EOF

chmod a+x /usr/local/bin/addns.exp

/usr/local/bin/addns.exp $NSIP $NS_PASSWORD

cat > /usr/local/bin/rotate.sh << EOF
#!/bin/bash
set -x
directory=/home/nswl/logs/
cd \$directory
for logfile in *.log.*
do
	gzip \$logfile
done

for logzip in *.log.*.gz
do
	d=\${logzip#*-}
	d=\${d%%.*}
	aws s3 cp \$logzip s3://test-logrotate-foo/dt=\$d/\$logzip
	rm \$logzip
done
EOF
chmod a+x /usr/local/bin/rotate.sh

cat > /etc/cron.d/rotate << EOF
55 * * * * nswl /usr/local/bin/rotate.sh /home/nswl/logs/

EOF

cat > /etc/monit.conf << EOF
set daemon  120           # check services at 2-minute intervals
    with start delay 240  # optional: delay the first check by 4-minutes (by 
                          # default Monit check immediately after Monit start)
set logfile syslog facility log_daemon                       
set idfile /var/.monit.id
set statefile /var/.monit.state
set httpd port 2812 and
    use address localhost  # only accept connection from localhost
    allow localhost        # allow localhost to connect to the server and
    allow admin:monit      # require user 'admin' with password 'monit'
    allow @monit           # allow users of group 'monit' to connect (rw)
    allow @users readonly  # allow users of group 'users' to connect readonly

set daemon 60
include /etc/monit.d/*
EOF

cat > /etc/monit.d/nswl << EOF
CHECK PROCESS nswl MATCHING nswl
   start program = "/usr/local/netscaler/bin/nswl -start -f /etc/weblog_client.conf"
   stop program = "/usr/local/netscaler/bin/nswl -stop -f /etc/weblog_client.conf"
EOF

service monit start
monit start all
