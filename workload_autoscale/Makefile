all: package-lambda

help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  package-lambda      to package the lambda function"
	@echo "  package-config      to package the NetScaler Terraform config"
	@echo "  update-config       to upload the NetScaler Terraform config to S3"
	@echo "  create-lambda       to create the lambda function in AWS"
	@echo "  create-lambda-full  to create the lambda function AND all required resources such as VPC and ASG in AWS"
	@echo "  update-lambda       to update the lambda function in AWS. May be mismatched to the region deployed"
	@echo "  test-local          to test locally"
	@echo "  invoke-lambda       to invoke execution in AWS. May be mismatched to the region"

dyndbdmutex.py:
	curl -s -R -S -L -f https://github.com/chiradeep/lambda-mutex/releases/download/v0.20/dyndbmutex-0.2.0.tar.gz  -z dyndbmutex.py -o dyndbmutex-0.2.0.tar.gz
	tar --strip-components=2 -xvzf dyndbmutex-0.2.0.tar.gz dyndbmutex-0.2.0/dyndbmutex/dyndbmutex.py
	rm -f dyndbmutex-0.2.0.tar.gz

terraform-binary:
	mkdir -p ./bin
	curl -s -R -S -L -f https://github.com/citrix/terraform-provider-netscaler/releases/download/v0.8.2/terraform-provider-netscaler-linux-amd64.tar.gz -z bin/terraform-provider-netscaler-linux-amd64.tar.gz -o bin/terraform-provider-netscaler-linux-amd64.tar.gz
	curl -s -S -L -f https://releases.hashicorp.com/terraform/0.8.1/terraform_0.8.1_linux_amd64.zip -z bin/terraform_0.8.1_linux_amd64.zip -o bin/terraform_0.8.1_linux_amd64.zip
	(cd bin; tar xvzf terraform-provider-netscaler-linux-amd64.tar.gz)
	(cd bin; unzip -o terraform_0.8.1_linux_amd64.zip)



bundle.zip: handler.py dyndbdmutex.py terraform-binary 
	zip  -r9 bundle.zip handler.py dyndbmutex.py bin/terraform bin/terraform-provider-netscaler

config.zip: config/*
	zip  config.zip config/*

package-lambda: bundle.zip
	@echo "create/update lambda deployment package (bundle.zip)"

package-config: config.zip
	@echo "create/update NetScaler Terraform files (config.zip)"

update-config: package-config
	@echo "update config in S3 bucket"
	aws s3 cp config.zip s3://${S3_TFCONFIG_BUCKET}

update-lambda:  package-lambda
	@echo "update lambda deployment package"
	aws lambda update-function-code  --function-name ${LAMBDA_FUNCTION_NAME} --zip-file fileb://${PWD}/bundle.zip

create-lambda: package-lambda
	@echo "Create lambda and associated resources in AWS using Terraform"
	(cd setup/lambda; terraform apply)

create-lambda-full: package-lambda package-config
	@echo "Create VPC, Autoscaling Group, VPX, lambda and associated resources in AWS using Terraform"
	(cd setup; terraform get; terraform apply)

get-env-vars:
	@echo "export NS_LOGIN=nsroot"
	@echo "export NS_PASSWORD=$$(terraform output -state=setup/terraform.tfstate -module vpx vpx_id)"
	@echo "export NS_VPX_TAG_KEY=Name"
	@echo "export NS_VPX_TAG_VALUE=NetScalerVPX"
	@echo "export NS_VPX_NSIP_ENI_DESCR=\"ENI connected to NSIP subnet\""
	@echo "export NS_VPX_CLIENT_ENI_DESCR=\"ENI connected to Client subnet\""
	@echo "export NS_VPX_SERVER_ENI_DESCR=\"ENI connected to Server subnet\""
	@echo "export NS_VPX_NSIP_SUBNET_IDS=$$(terraform output -state=setup/terraform.tfstate -module vpc private_subnets)"
	@echo "export NS_VPX_CLIENT_SUBNET_IDS=$$(terraform output -state=setup/terraform.tfstate -module vpc public_subnets)"
	@echo "export S3_TFSTATE_BUCKET=$$(terraform output -state=setup/terraform.tfstate -module lambda state_bucket)"
	@echo "export S3_TFCONFIG_BUCKET=$$(terraform output -state=setup/terraform.tfstate -module lambda config_bucket)"
	@echo "export DD_MUTEX_TABLE_NAME=$$(terraform output -state=setup/terraform.tfstate -module lambda mutex_table)"
	@echo "export ASG_NAME=$$(terraform output -state=setup/terraform.tfstate -module asg asg_name)"

test-local:
	@echo "Testing locally"
	python-lambda-local -l lib/ -f handler -t 50 handler.py event.json

invoke-lambda:
	@echo "Invoking Lambda remote"
	aws lambda invoke --function-name ${LAMBDA_FUNCTION_NAME} --log-type Tail outfile.txt | grep LogResult | awk -F" " '{print $$2}' | sed 's/"//g' | sed 's/,//g'  | base64 --decode
