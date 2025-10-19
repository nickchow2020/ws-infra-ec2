#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="ws-api-infrastructure"
TEMPLATE_FILE="infrastructure.yaml"
PARAMETERS_FILE="parameters.json"
DEFAULT_REGION="us-east-1"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy WebSocket API infrastructure using CloudFormation

OPTIONS:
    -r, --region REGION         AWS Region - default: us-east-1
    -s, --stack-name NAME       CloudFormation stack name - default: ws-api-infrastructure
    -h, --help                  Show this help message

EXAMPLES:
    $0
    $0 --region us-west-2
    $0 --stack-name my-custom-stack

EOF
    exit 1
}

# Parse command line arguments
REGION="$DEFAULT_REGION"

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -s|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check if files exist
if [ ! -f "$TEMPLATE_FILE" ]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

if [ ! -f "$PARAMETERS_FILE" ]; then
    print_error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi

# Check if parameters are properly configured
if grep -q "YOUR_KEY_PAIR_NAME_HERE" "$PARAMETERS_FILE"; then
    print_error "Please update $PARAMETERS_FILE with your EC2 key pair name"
    exit 1
fi

# Display deployment information
print_info "================================================"
print_info "WebSocket API Infrastructure Deployment"
print_info "================================================"
print_info "Stack Name:     $STACK_NAME"
print_info "Region:         $REGION"
print_info "Template:       $TEMPLATE_FILE"
print_info "Parameters:     $PARAMETERS_FILE"
print_info "================================================"

# Confirm deployment
read -p "Do you want to proceed with the deployment? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# Validate template
print_info "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION > /dev/null 2>&1

if [ $? -ne 0 ]; then
    print_error "Template validation failed"
    exit 1
fi
print_info "Template validation successful"

# Deploy stack
print_info "Deploying CloudFormation stack: $STACK_NAME"
aws cloudformation deploy \
    --template-file $TEMPLATE_FILE \
    --stack-name $STACK_NAME \
    --parameter-overrides file://$PARAMETERS_FILE \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --no-fail-on-empty-changeset

if [ $? -eq 0 ]; then
    print_info "Stack deployed successfully!"
    echo ""
    print_info "Getting stack outputs..."
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table

    echo ""
    print_info "================================================"
    print_info "Next Steps:"
    print_info "================================================"
    print_info "1. SSH into the instance using the command from outputs"
    print_info "2. Clone your application repository"
    print_info "3. Configure docker-compose.yml"
    print_info "4. Run: docker-compose up -d"
    print_info "================================================"
else
    print_error "Stack deployment failed!"
    exit 1
fi
