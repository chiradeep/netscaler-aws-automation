all: package-lambda

help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  package-lambda      to package the lambda function"
	@echo "  create-lambda       to create the lambda function in AWS"
	@echo "  update-lambda       to update the lambda function in AWS. May be mismatched to the region deployed"
	@echo "  test-local          to test locally"
	@echo "  invoke-lambda       to invoke execution in AWS. May be mismatched to the region"


lifecycle.zip: handler.py 
	zip  -r9 lifecycle.zip handler.py 

package-lambda: lifecycle.zip
	@echo "create/update lambda deployment package (lifecycle.zip)"

update-lambda:  package-lambda
	@echo "update lambda deployment package"
	aws lambda update-function-code  --function-name ${LAMBDA_FUNCTION_NAME} --zip-file fileb://${PWD}/lifecycle.zip

create-lambda: package-lambda
	@echo "Create lambda and associated resources in AWS using Terraform"
	(cd setup/lifecycle_lambda; terraform apply)

test-local:
	@echo "Testing locally"
	python-lambda-local -l lib/ -f lambda_handler -t 50 handler.py event.json

invoke-lambda:
	@echo "Invoking Lambda remote"
	aws lambda invoke --function-name ${LAMBDA_FUNCTION_NAME} --log-type Tail outfile.txt | grep LogResult | awk -F" " '{print $$2}' | sed 's/"//g' | sed 's/,//g'  | base64 --decode
