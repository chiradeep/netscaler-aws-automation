# Terraform config to create a pool of traffic generators
Creates a pool of Amazon linux instances, with [Apache Bench (ab)](https://httpd.apache.org/docs/2.4/programs/ab.html) installed on them. Use `fabric` [automation](http://fabfile.org) to control the execution of Apache bench

# Pre-requisites
Install `fabric`:

```
sudo pip install fabric
```

# Sample usage

```
module "traffic_gen" {
  source = "../../config/modules/traffic_gen"

  base_name                  = "tgen0"
  vpc_id                     = "${var.vpc_id}"
  key_name                   = "${var.key_name}"
  public_subnet              = "${var.public_subnet}"
  traffic_gen_instance_count = 3
}

$ terraform apply

# Get the list of public ips of the traffic gen instances
$ ips=$(terraform output -module traffic_gen traffic_gen_publicips)

#remove whitespace
$ IPS=$(echo $ips| sed 's/ //g')

# Get url of VPX /VPX cluster as $URL
# Example: URL=$(terraform output vpx_loadbalanced_url)

# Start the load test
$ fab -H $IPLIST -u ec2-user -i $PRIVATE_KEY_FILE start_traffic_gen:num_clients=100,num_requests=100000,url=$URL

# Tear down
$ terraform destroy

```
