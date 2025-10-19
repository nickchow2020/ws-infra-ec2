# WebSocket API Infrastructure - EC2

AWS CloudFormation infrastructure for deploying WebSocket API on EC2 with Docker support.

## Architecture

This infrastructure creates:
- VPC with public subnet
- Internet Gateway and routing
- Security Group (SSH, HTTP, WebSocket)
- EC2 instance with Docker pre-installed
- IAM role with SSM and CloudWatch access

## Prerequisites

### Required
- AWS CLI installed and configured
- AWS account with appropriate permissions
- EC2 Key Pair created in your target region

### AWS CLI Configuration
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter your default output format (e.g., json)
```

### Create EC2 Key Pair
```bash
# Create a new key pair
aws ec2 create-key-pair \
    --key-name ws-api-key \
    --query 'KeyMaterial' \
    --output text > ws-api-key.pem

# Set appropriate permissions
chmod 400 ws-api-key.pem
```

## Quick Start

### 1. Clone and Configure

```bash
# Clone this repository
git clone <your-repo-url>
cd ws-infra-ec2

# Update parameters file
# Edit parameters.json and replace YOUR_KEY_PAIR_NAME_HERE with your key pair name
```

### 2. Deploy Infrastructure

```bash
# Make deploy script executable (Linux/Mac)
chmod +x deploy.sh

# Deploy infrastructure
./deploy.sh

# Deploy to specific region
./deploy.sh --region us-west-2
```

### 3. Access Your Instance

After deployment completes, you'll see outputs including SSH command:

```bash
# SSH into the instance (use the command from outputs)
ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>
```

## Manual Deployment

### Validate Template

```bash
aws cloudformation validate-template \
    --template-body file://infrastructure.yaml \
    --region us-east-1
```

### Deploy Stack

```bash
aws cloudformation deploy \
    --template-file infrastructure.yaml \
    --stack-name ws-api-infrastructure \
    --parameter-overrides file://parameters.json \
    --capabilities CAPABILITY_IAM \
    --region us-east-1
```

### Get Stack Outputs

```bash
aws cloudformation describe-stacks \
    --stack-name ws-api-infrastructure \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table
```

## Deploying Your Application

Once the infrastructure is ready:

### 1. SSH into Instance

```bash
ssh -i your-key.pem ec2-user@<PUBLIC_IP>
```

### 2. Clone Your Application

```bash
cd /opt/websocket-api
git clone https://github.com/yourusername/ws-api-dotnet.git .
```

### 3. Configure Environment

```bash
# Create .env file
cat > .env << EOF
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://+:8080
JWT_SECRET=your-secret-key
EOF
```

### 4. Start Application

```bash
# Using Docker Compose
docker-compose up -d

# Check logs
docker-compose logs -f

# Check status
docker-compose ps
```

## Stack Management

### Update Stack

```bash
# Update after modifying infrastructure.yaml or parameters
./deploy.sh --env dev
```

### View Stack Status

```bash
aws cloudformation describe-stacks \
    --stack-name ws-api-infrastructure \
    --region us-east-1
```

### View Stack Events

```bash
aws cloudformation describe-stack-events \
    --stack-name ws-api-infrastructure \
    --region us-east-1 \
    --max-items 10
```

### Delete Stack

```bash
# Make delete script executable
chmod +x delete-stack.sh

# Delete stack (with confirmation)
./delete-stack.sh

# Force delete without confirmation
./delete-stack.sh --force

# Delete from specific region
./delete-stack.sh --region us-west-2
```

## Configuration

### Parameters

Edit `parameters.json`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| EnvironmentName | Environment prefix for resources | ws-api |
| InstanceType | EC2 instance type | t3.micro |
| KeyPairName | EC2 Key Pair name | YOUR_KEY_PAIR_NAME_HERE |
| AllowedCIDR | CIDR block for access | 0.0.0.0/0 |

### Security Group Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH access |
| 8080 | TCP | WebSocket API HTTP |
| 8081 | TCP | WebSocket API HTTPS |

### Recommended Production Settings

Update `parameters.json` for production:
- Use larger instance type (t3.small or t3.medium)
- Restrict AllowedCIDR to your organization's IP range
- Enable termination protection in CloudFormation
- Configure automated backups

## Monitoring and Logs

### Connect via AWS Systems Manager

```bash
# No SSH key required
aws ssm start-session \
    --target <INSTANCE_ID> \
    --region us-east-1
```

### View CloudWatch Logs

```bash
# Install CloudWatch agent on instance
sudo yum install amazon-cloudwatch-agent -y

# View application logs
docker-compose logs -f
```

### Monitor Instance

```bash
# CPU and memory usage
top

# Docker containers
docker ps

# Disk usage
df -h
```

## Troubleshooting

### Stack Creation Failed

```bash
# View failure reason
aws cloudformation describe-stack-events \
    --stack-name ws-api-infrastructure \
    --region us-east-1 \
    --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

### Cannot SSH into Instance

1. Check security group allows your IP
2. Verify key pair permissions: `chmod 400 your-key.pem`
3. Ensure instance is running
4. Check public IP is correct

### Application Not Accessible

```bash
# Check if Docker is running
sudo systemctl status docker

# Check if containers are running
docker ps

# Check container logs
docker-compose logs

# Check security group rules
aws ec2 describe-security-groups \
    --group-ids <SG_ID> \
    --region us-east-1
```

## Costs Estimation

### t3.micro Instance (Default)
- EC2 Instance: ~$7.50/month
- Data Transfer: Variable
- EBS Storage: ~$0.80/month (8GB)
- **Total: ~$8-10/month** (excluding data transfer)

### t3.small Instance (Recommended for production)
- EC2 Instance: ~$15/month
- Data Transfer: Variable
- EBS Storage: ~$0.80/month (8GB)
- **Total: ~$16-20/month** (excluding data transfer)

## Best Practices

1. **Security**
   - Use restrictive CIDR blocks in production
   - Regularly update EC2 instance and packages
   - Use secrets manager for sensitive data
   - Enable AWS Config for compliance

2. **Monitoring**
   - Set up CloudWatch alarms
   - Enable detailed monitoring
   - Configure log aggregation
   - Monitor application metrics

3. **Backup**
   - Create AMI snapshots regularly
   - Backup application data
   - Document restore procedures

4. **Updates**
   - Test infrastructure changes in dev first
   - Use change sets for production
   - Keep CloudFormation templates in version control
   - Document all manual changes

## Resources Created

| Resource Type | Name Pattern | Purpose |
|--------------|--------------|---------|
| VPC | {EnvironmentName}-VPC | Network isolation |
| Subnet | {EnvironmentName}-Public-Subnet | Public subnet for EC2 |
| Internet Gateway | {EnvironmentName}-IGW | Internet access |
| Security Group | {EnvironmentName}-WebSocket-SG | Firewall rules |
| EC2 Instance | {EnvironmentName}-WebSocket-API | Application server |
| IAM Role | {EnvironmentName}-EC2-Role | Instance permissions |

## Support

For issues and questions:
- Check AWS CloudFormation documentation
- Review CloudFormation events for error details
- Verify IAM permissions
- Check AWS service health dashboard

## License

MIT License - See LICENSE file for details
