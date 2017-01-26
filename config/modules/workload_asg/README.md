# Terraform template to create an autoscaling group of apache webservers
Creates an autoscaling group of Apache2 webservers

# Operation
Fetches the latest Ubuntu16 AMI and launches the desired number. Each instance will execute the script in userdata.sh which creates a default homepage that displays the identifying information for the instance
