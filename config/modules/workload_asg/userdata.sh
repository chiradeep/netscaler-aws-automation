#!/bin/bash -v
apt-get update -y
apt-get install -y apache2 > /tmp/apache.log

localhostname=$(curl -s  http://169.254.169.254/latest/meta-data/local-hostname)
instanceid=$(curl -s  http://169.254.169.254/latest/meta-data/instance-id)
launchindex=$(curl -s  http://169.254.169.254/latest/meta-data/ami-launch-index)
az=$(curl -s  http://169.254.169.254/latest/meta-data/placement/availability-zone)
ipv4=$(curl  -s http://169.254.169.254/latest/meta-data/local-ipv4)

mv /var/www/html/index.html /var/www/html/default.apache2.index.html
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
<title>Welcome to NetScaler!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to NetScaler!</h1>
<p>I am being served from: </p>
<p> Host: <em>$localhostname </em></p>
<p> AZ: $az </p>
<p> Instance: <em>$instanceid</em> </p>
<p> Private Ipv4: <em>$ipv4</em> </p>


Commercial support is available at
<a href="https://citrix.com/">citrix.com</a>.</p>

<p><em>Thank you for using NetScaler.</em></p>
</body>
</html>
EOF

