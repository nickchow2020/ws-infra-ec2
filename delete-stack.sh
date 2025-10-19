#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="ws-api-infrastructure"
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

Delete WebSocket API infrastructure CloudFormation stack

OPTIONS:
    -r, --region REGION         AWS Region - default: us-east-1
    -s, --stack-name NAME       CloudFormation stack name - default: ws-api-infrastructure
    -f, --force                 Skip confirmation prompt
    -h, --help                  Show this help message

EXAMPLES:
    $0
    $0 --region us-west-2
    $0 --stack-name my-custom-stack --force

EOF
    exit 1
}

# Parse command line arguments
REGION="$DEFAULT_REGION"
FORCE=false

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
        -f|--force)
            FORCE=true
            shift
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

# Display deletion information
print_warning "================================================"
print_warning "CloudFormation Stack Deletion"
print_warning "================================================"
print_warning "Stack Name:     $STACK_NAME"
print_warning "Region:         $REGION"
print_warning "================================================"

# Check if stack exists
print_info "Checking if stack exists..."
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION > /dev/null 2>&1

if [ $? -ne 0 ]; then
    print_error "Stack not found: $STACK_NAME"
    exit 1
fi

# Show current stack resources
print_info "Current stack resources:"
aws cloudformation list-stack-resources \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'StackResourceSummaries[*].[ResourceType,LogicalResourceId]' \
    --output table

echo ""

# Confirm deletion
if [ "$FORCE" = false ]; then
    print_warning "WARNING: This will delete all resources in the stack!"
    read -p "Are you sure you want to delete the stack? Type 'DELETE' to confirm: " -r
    echo
    if [[ $REPLY != "DELETE" ]]; then
        print_info "Deletion cancelled"
        exit 0
    fi
fi

# Delete stack
print_info "Deleting CloudFormation stack: $STACK_NAME"
aws cloudformation delete-stack \
    --stack-name $STACK_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    print_info "Stack deletion initiated"
    print_info "Waiting for stack deletion to complete..."

    aws cloudformation wait stack-delete-complete \
        --stack-name $STACK_NAME \
        --region $REGION

    if [ $? -eq 0 ]; then
        print_info "Stack deleted successfully!"
    else
        print_error "Stack deletion failed or timed out"
        print_info "Check the CloudFormation console for details"
        exit 1
    fi
else
    print_error "Failed to initiate stack deletion"
    exit 1
fi
