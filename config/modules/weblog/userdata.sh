#!/bin/bash -v
exec 1> >(logger -s -t $(basename $0)) 2>&1

NS_PASSWORD=nsroot
NSIP=172.31.23.100

yum -y install expect
(cd /tmp; curl -s -O https://s3-us-west-2.amazonaws.com/netscaler-web-log-client/11/nswl_linux-11.1-51.26.rpm)
yum -y install /tmp/nswl_linux-11.1-51.26.rpm 

adduser nswl -s /sbin/nologin
mkdir -p /home/nswl/logs/
chmod a+rwx /home/nswl/logs/

cat > /etc/weblog_client.conf <<EOF
Filter default 

begin default
	logFormat		W3C %{%Y-%m-%dT%H:%M:%S}t %v %A:%p  %M %s %j %J "%m %S://%v%U" %+{user-agent}i
	logInterval		Hourly
	logFileSizeLimit	10
	logFilenameFormat	/home/nswl/logs/logs%{%y%m%d}t.log
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


cat > /etc/systemd/system/nswl.service << EOF
[Unit]
Description=NSWL Service
After=network.target

[Service]
Type=simple
User=nswl
ExecStart=/usr/local/netscaler/bin/nswl -start -f /etc/weblog_client.conf
Restart=on-abort


[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start nswl
systemctl enable nswl
