# Setup Guide

Quick setup guide for deploying the WebSocket API infrastructure.

## Step-by-Step Setup

### Step 1: Prerequisites

1. Install AWS CLI:
   ```bash
   # Windows (using MSI installer)
   https://awscli.amazonaws.com/AWSCLIV2.msi

   # macOS
   brew install awscli

   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. Configure AWS credentials:
   ```bash
   aws configure
   ```

   Enter:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (e.g., us-east-1)
   - Default output format: json

### Step 2: Create EC2 Key Pair

```bash
# Create key pair
aws ec2 create-key-pair \
    --key-name ws-api-key \
    --query 'KeyMaterial' \
    --output text > ws-api-key.pem

# Set permissions (Linux/Mac)
chmod 400 ws-api-key.pem

# Windows: Right-click ws-api-key.pem > Properties > Security
# Remove all users except yourself and set to Read-only
```

### Step 3: Configure Parameters

Edit `parameters.json`:

```json
[
  {
    "ParameterKey": "KeyPairName",
    "ParameterValue": "ws-api-key"  // Change this to your key pair name
  }
]
```

### Step 4: Deploy Infrastructure

**Linux/Mac:**
```bash
chmod +x deploy.sh
./deploy.sh
```

**Windows (Git Bash or WSL):**
```bash
bash deploy.sh
```

**Windows (PowerShell):**
```powershell
aws cloudformation deploy `
    --template-file infrastructure.yaml `
    --stack-name ws-api-infrastructure `
    --parameter-overrides file://parameters.json `
    --capabilities CAPABILITY_IAM `
    --region us-east-1
```

### Step 5: Get Deployment Info

```bash
aws cloudformation describe-stacks \
    --stack-name ws-api-infrastructure \
    --query 'Stacks[0].Outputs'
```

Save the following from outputs:
- PublicIP
- SSHCommand
- WebSocketAPIEndpoint

### Step 6: Deploy Application

1. SSH into instance:
   ```bash
   ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>
   ```

2. Clone your application:
   ```bash
   cd /opt/websocket-api
   git clone https://github.com/yourusername/your-repo.git .
   ```

3. Create environment file:
   ```bash
   cat > .env << EOF
   ASPNETCORE_ENVIRONMENT=Production
   ASPNETCORE_URLS=http://+:8080
   # Add other environment variables
   EOF
   ```

4. Start application:
   ```bash
   docker-compose up -d
   ```

5. Verify:
   ```bash
   docker-compose ps
   docker-compose logs -f
   ```

### Step 7: Test Your API

```bash
# Test health endpoint
curl http://<PUBLIC_IP>:8080/api/healthz

# Test WebSocket (using wscat)
npm install -g wscat
wscat -c ws://<PUBLIC_IP>:8080/ws
```

## Common Issues

### Issue: Key pair not found

**Solution:**
```bash
# List your key pairs
aws ec2 describe-key-pairs

# Create new key pair if needed
aws ec2 create-key-pair --key-name ws-api-key
```

### Issue: Template validation failed

**Solution:**
```bash
# Validate template
aws cloudformation validate-template \
    --template-body file://infrastructure.yaml
```

### Issue: Cannot SSH to instance

**Solutions:**
1. Check security group allows your IP:
   ```bash
   # Get your IP
   curl ifconfig.me

   # Update parameters-dev.json AllowedCIDR to your IP/32
   ```

2. Verify key permissions:
   ```bash
   chmod 400 ws-api-key.pem
   ```

3. Wait for instance to be ready (2-3 minutes after creation)

### Issue: Application not accessible

**Solutions:**
1. Check Docker is running:
   ```bash
   sudo systemctl status docker
   ```

2. Check containers:
   ```bash
   docker ps
   docker-compose logs
   ```

3. Check security group allows port 8080

## Next Steps

- [ ] Set up custom domain name
- [ ] Configure SSL/TLS certificates
- [ ] Set up CloudWatch alarms
- [ ] Configure automated backups
- [ ] Set up CI/CD pipeline
- [ ] Enable application monitoring

## Quick Reference

### Important Commands

```bash
# Deploy
./deploy.sh

# Update stack
./deploy.sh

# Delete stack
./delete-stack.sh

# SSH to instance
ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>

# View logs
docker-compose logs -f

# Restart application
docker-compose restart

# Stop application
docker-compose down

# Start application
docker-compose up -d
```

### Important Files

- `infrastructure.yaml` - CloudFormation template
- `parameters.json` - Stack parameters
- `deploy.sh` - Deployment script
- `delete-stack.sh` - Stack deletion script
- `README.md` - Full documentation
- `SETUP.md` - This setup guide

## Getting Help

1. Check CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events \
       --stack-name ws-api-infrastructure \
       --max-items 20
   ```

2. Check EC2 instance logs:
   ```bash
   # SSH to instance
   # View system logs
   sudo tail -f /var/log/messages

   # View Docker logs
   docker-compose logs -f
   ```

3. AWS Support:
   - AWS Console > CloudFormation > Stack > Events
   - AWS Console > EC2 > Instances > System Log
