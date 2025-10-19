# WebSocket API Infrastructure - EC2

Complete AWS infrastructure setup for deploying a .NET SignalR Chat API on EC2 with Docker.

## Project Overview

This repository contains AWS CloudFormation templates and deployment scripts to create:
- **VPC** with public subnet and Internet Gateway
- **EC2 instance** (t3.micro) with Docker pre-installed
- **Security Groups** for SSH and HTTP/HTTPS access
- **IAM roles** for EC2 with SSM and CloudWatch permissions

**Backend Repository**: [ws-api-dotnet](https://github.com/nickchow2020/ws-api-dotnet)

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Complete Deployment Guide](#complete-deployment-guide)
- [Application Deployment](#application-deployment)
- [Testing the API](#testing-the-api)
- [Stack Management](#stack-management)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)

---

## Prerequisites

### Required Tools
- **AWS CLI** - installed and configured
- **Git** - for cloning repositories
- **SSH client** - for connecting to EC2
- **AWS Account** with appropriate permissions

### AWS CLI Setup

```bash
# Install AWS CLI (if not installed)
# Windows: https://awscli.amazonaws.com/AWSCLIV2.msi
# macOS: brew install awscli
# Linux: See AWS documentation

# Configure AWS credentials
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-2)
# Enter default output format: json
```

### Create AWS Access Keys

1. Log into AWS Console
2. Click your username (top right) → **Security credentials**
3. Scroll to **Access keys** → **Create access key**
4. Choose **Command Line Interface (CLI)**
5. Save both the Access Key ID and Secret Access Key

---

## Quick Start

### Step 1: Create EC2 Key Pair

**Option A: Via AWS CLI**
```bash
aws ec2 create-key-pair \
    --key-name ws-api-key \
    --query 'KeyMaterial' \
    --output text > ws-api-key.pem

# Set permissions (Linux/Mac/Git Bash)
chmod 400 ws-api-key.pem
```

**Option B: Via AWS Console**
1. Go to EC2 → Key Pairs
2. Click "Create key pair"
3. Name: `ws-api-key`
4. Type: RSA, Format: .pem
5. Download and save securely

### Step 2: Configure Parameters

Edit `parameters.json`:
```json
{
  "ParameterKey": "KeyPairName",
  "ParameterValue": "ws-api-key"  // ← Change this to your key pair name
}
```

### Step 3: Deploy Infrastructure

**Windows PowerShell:**
```powershell
aws cloudformation deploy `
    --template-file infrastructure.yaml `
    --stack-name ws-api-infrastructure `
    --parameter-overrides file://parameters.json `
    --capabilities CAPABILITY_IAM `
    --region us-east-2
```

**Linux/Mac:**
```bash
chmod +x deploy.sh
./deploy.sh
```

### Step 4: Get Deployment Outputs

```powershell
aws cloudformation describe-stacks `
    --stack-name ws-api-infrastructure `
    --region us-east-2 `
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' `
    --output table
```

Save these outputs:
- **PublicIP**: Your EC2 instance IP address
- **SSHCommand**: Command to connect via SSH
- **WebSocketAPIEndpoint**: Your API endpoint URL

---

## Complete Deployment Guide

### 1. Infrastructure Deployment (5-10 minutes)

The CloudFormation stack creates:
- VPC (10.0.0.0/16)
- Public Subnet (10.0.1.0/24)
- Internet Gateway
- Security Group (ports 22, 8080, 8081)
- EC2 Instance with Docker installed

### 2. Verify Infrastructure

```bash
# Check stack status
aws cloudformation describe-stacks \
    --stack-name ws-api-infrastructure \
    --region us-east-2

# SSH into instance
ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>
```

---

## Application Deployment

### Complete Step-by-Step Process

Once infrastructure is deployed, deploy your SignalR Chat API:

#### 1. SSH into EC2 Instance

```bash
ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>
```

#### 2. Navigate and Clone Backend

```bash
cd /opt/websocket-api
git clone https://github.com/nickchow2020/ws-api-dotnet.git
cd ws-api-dotnet
ls -la  # Verify files
```

#### 3. Configure CORS (Important!)

Edit `appsettings.Production.json` to allow your frontend:

```bash
nano appsettings.Production.json
```

Update the `AllowedOrigins`:
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedOrigins": [
    "http://localhost:3000",
    "http://localhost:5173",
    "http://127.0.0.1:3000",
    "https://your-frontend-domain.com",
    "null"
  ]
}
```

Save: `Ctrl+X`, `Y`, `Enter`

#### 4. Build Docker Image

```bash
# Build the .NET application image
docker build -t ws-api-dotnet .
```

This takes 2-3 minutes and will:
- Download .NET 9.0 base images
- Restore NuGet packages
- Build and publish your application

#### 5. Run the Container

```bash
# Stop any existing container
docker stop ws-api-dotnet 2>/dev/null || true
docker rm ws-api-dotnet 2>/dev/null || true

# Start the application
docker run -d \
  --name ws-api-dotnet \
  -p 8080:8080 \
  -p 8081:8081 \
  -e ASPNETCORE_ENVIRONMENT=Production \
  -e ASPNETCORE_URLS=http://+:8080 \
  --restart unless-stopped \
  ws-api-dotnet

# Verify it's running
docker ps

# Check logs
docker logs -f ws-api-dotnet
```

Press `Ctrl+C` to exit logs.

#### 6. Test the API

**From EC2 instance:**
```bash
curl http://localhost:8080/api/healthz
# Expected: {"status":"ok"}
```

**From your local machine:**
```bash
curl http://<PUBLIC_IP>:8080/api/healthz
```

---

## Testing the API

### REST API Endpoints

```bash
# Health Check
curl http://<PUBLIC_IP>:8080/api/healthz

# Get Messages
curl http://<PUBLIC_IP>:8080/api/chat/messages

# Get Rooms
curl http://<PUBLIC_IP>:8080/api/chat/rooms
```

### SignalR Real-Time Testing

Your SignalR hub is at: `http://<PUBLIC_IP>:8080/ws`

#### Available SignalR Methods:
- `SendMessage(user, message)` - Broadcast message
- `SendMessageToRoom(roomId, user, message)` - Send to room
- `JoinRoom(roomId)` - Join chat room
- `LeaveRoom(roomId)` - Leave chat room

#### Events from Server:
- `ReceiveMessage(user, message)` - Incoming message
- `UserDisconnected(connectionId)` - User left

### Test with HTML Client

Save this as `test-signalr.html` and open in browser:

```html
<!DOCTYPE html>
<html>
<head><title>SignalR Test</title></head>
<body>
    <h1>SignalR Chat Test</h1>
    <button onclick="connect()">Connect</button>
    <button onclick="send()">Send Test Message</button>
    <div id="status">Disconnected</div>
    <div id="messages"></div>

    <script src="https://cdn.jsdelivr.net/npm/@microsoft/signalr@latest/dist/browser/signalr.min.js"></script>
    <script>
        let connection;

        async function connect() {
            connection = new signalR.HubConnectionBuilder()
                .withUrl("http://<YOUR_PUBLIC_IP>:8080/ws")
                .build();

            connection.on("ReceiveMessage", (user, msg) => {
                document.getElementById('messages').innerHTML +=
                    `<p><b>${user}:</b> ${msg}</p>`;
            });

            await connection.start();
            document.getElementById('status').textContent = 'Connected!';
        }

        async function send() {
            await connection.invoke("SendMessage", "TestUser", "Hello World!");
        }
    </script>
</body>
</html>
```

Replace `<YOUR_PUBLIC_IP>` with your actual EC2 public IP.

---

## Stack Management

### Update Infrastructure

```bash
# Modify infrastructure.yaml or parameters.json
# Then redeploy
./deploy.sh

# Or manually:
aws cloudformation deploy \
    --template-file infrastructure.yaml \
    --stack-name ws-api-infrastructure \
    --parameter-overrides file://parameters.json \
    --capabilities CAPABILITY_IAM \
    --region us-east-2
```

### Update Application

After code changes:

```bash
# SSH to EC2
ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>

cd /opt/websocket-api/ws-api-dotnet

# Pull latest code
git pull

# Rebuild and restart
docker build -t ws-api-dotnet .
docker stop ws-api-dotnet
docker rm ws-api-dotnet
docker run -d --name ws-api-dotnet -p 8080:8080 -p 8081:8081 \
  -e ASPNETCORE_ENVIRONMENT=Production \
  -e ASPNETCORE_URLS=http://+:8080 \
  --restart unless-stopped ws-api-dotnet

# Check logs
docker logs -f ws-api-dotnet
```

### Delete Stack

```bash
# Using script
chmod +x delete-stack.sh
./delete-stack.sh

# Or manually
aws cloudformation delete-stack \
    --stack-name ws-api-infrastructure \
    --region us-east-2

# Wait for deletion
aws cloudformation wait stack-delete-complete \
    --stack-name ws-api-infrastructure \
    --region us-east-2
```

**WARNING**: This will permanently delete all resources!

---

## Troubleshooting

### Common Issues

#### 1. Cannot SSH to Instance

**Solutions:**
```bash
# Check security group allows your IP
aws ec2 describe-security-groups \
    --group-ids <SG_ID> \
    --region us-east-2

# Verify key permissions
chmod 400 ws-api-key.pem  # Linux/Mac

# Windows PowerShell:
icacls ws-api-key.pem /inheritance:r
icacls ws-api-key.pem /grant:r "$($env:USERNAME):(R)"

# Check instance is running
aws ec2 describe-instances \
    --instance-ids <INSTANCE_ID> \
    --region us-east-2
```

#### 2. API Not Accessible

```bash
# On EC2, check Docker
docker ps
docker logs ws-api-dotnet

# Check if app is listening
curl http://localhost:8080/api/healthz

# Verify security group
# Port 8080 must be open to 0.0.0.0/0
```

#### 3. SignalR Connection Fails (CORS Error)

**Fix:**
```bash
# SSH to EC2
cd /opt/websocket-api/ws-api-dotnet
nano appsettings.Production.json

# Add your frontend URL to AllowedOrigins
# Save and rebuild container (see Update Application above)
```

#### 4. Docker Build Fails

```bash
# Check Docker version
docker --version  # Should be 25.0+

# Check disk space
df -h

# View detailed error
docker build -t ws-api-dotnet . --no-cache
```

#### 5. Stack Creation Failed

```bash
# View error details
aws cloudformation describe-stack-events \
    --stack-name ws-api-infrastructure \
    --region us-east-2 \
    --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'

# Common issues:
# - Key pair doesn't exist in region
# - Insufficient IAM permissions
# - Region doesn't support instance type
```

### Useful Commands

```bash
# View all stack events
aws cloudformation describe-stack-events \
    --stack-name ws-api-infrastructure \
    --region us-east-2 \
    --max-items 20

# Check Docker containers
docker ps -a

# View container logs (last 100 lines)
docker logs --tail 100 ws-api-dotnet

# Restart Docker service
sudo systemctl restart docker

# Check EC2 system logs (via Console)
# EC2 → Instances → Select instance → Actions → Monitor and troubleshoot → Get system log
```

---

## Configuration

### Parameters

Edit `parameters.json`:

| Parameter | Description | Default | Notes |
|-----------|-------------|---------|-------|
| EnvironmentName | Resource name prefix | ws-api | Used for tagging |
| InstanceType | EC2 instance size | t3.micro | t3.small for production |
| KeyPairName | SSH key pair name | YOUR_KEY_PAIR_NAME_HERE | Must exist in region |
| AllowedCIDR | IP range for access | 0.0.0.0/0 | Restrict in production |

### Security Group Ports

| Port | Protocol | Purpose | Source |
|------|----------|---------|--------|
| 22 | TCP | SSH access | AllowedCIDR |
| 8080 | TCP | HTTP API | AllowedCIDR |
| 8081 | TCP | HTTPS API | AllowedCIDR |

### Environment Variables

When running the container, these are set:
- `ASPNETCORE_ENVIRONMENT=Production`
- `ASPNETCORE_URLS=http://+:8080`

Additional variables can be added with `-e` flag.

---

## Cost Estimation

### Monthly Costs (us-east-2 region)

**t3.micro (Development)**
- EC2 Instance: ~$7.50/month (On-Demand)
- EBS Storage (8GB): ~$0.80/month
- Data Transfer: ~$0.09/GB (first 10TB)
- **Estimated Total: $8-15/month**

**t3.small (Production)**
- EC2 Instance: ~$15/month (On-Demand)
- EBS Storage (8GB): ~$0.80/month
- Data Transfer: Variable
- **Estimated Total: $16-25/month**

**Cost Optimization Tips:**
- Use Reserved Instances (save up to 72%)
- Stop instances when not needed
- Use AWS Free Tier (first 12 months)
- Monitor with AWS Cost Explorer

---

## Production Best Practices

### Security
1. **Restrict CIDR blocks** - Don't use 0.0.0.0/0 in production
2. **Use HTTPS** - Configure SSL/TLS certificates
3. **Enable CloudTrail** - Audit all API calls
4. **Use Secrets Manager** - Store sensitive data securely
5. **Regular updates** - Keep OS and packages updated
6. **Enable MFA** - For AWS account access

### Monitoring
1. **CloudWatch Alarms** - CPU, memory, disk usage
2. **Application Logs** - Centralized logging (CloudWatch Logs)
3. **Health Checks** - Monitor `/api/healthz` endpoint
4. **SNS Notifications** - Alert on critical events

### Backup & Recovery
1. **AMI Snapshots** - Weekly EC2 backups
2. **EBS Snapshots** - Daily volume backups
3. **Database Backups** - If using RDS/databases
4. **Disaster Recovery Plan** - Document recovery steps

### Scalability
1. **Auto Scaling Group** - Handle variable load
2. **Load Balancer** - Distribute traffic
3. **Multi-AZ Deployment** - High availability
4. **CDN (CloudFront)** - Faster content delivery

---

## Resources Created

| Resource | Name Pattern | Description |
|----------|--------------|-------------|
| VPC | ws-api-VPC | Virtual network (10.0.0.0/16) |
| Subnet | ws-api-Public-Subnet | Public subnet (10.0.1.0/24) |
| Internet Gateway | ws-api-IGW | Internet connectivity |
| Route Table | ws-api-Public-Routes | Routing configuration |
| Security Group | ws-api-WebSocket-SG | Firewall rules |
| EC2 Instance | ws-api-WebSocket-API | Application server |
| IAM Role | ws-api-EC2-Role | Instance permissions |
| Instance Profile | EC2InstanceProfile | Links IAM role to EC2 |

---

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│           AWS Cloud (us-east-2)         │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  VPC (10.0.0.0/16)                │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │ Public Subnet (10.0.1.0/24) │ │ │
│  │  │                             │ │ │
│  │  │  ┌────────────────────┐    │ │ │
│  │  │  │  EC2 Instance      │    │ │ │
│  │  │  │  (t3.micro)        │    │ │ │
│  │  │  │                    │    │ │ │
│  │  │  │  ┌──────────────┐ │    │ │ │
│  │  │  │  │ Docker       │ │    │ │ │
│  │  │  │  │ Container    │ │    │ │ │
│  │  │  │  │              │ │    │ │ │
│  │  │  │  │ .NET 9.0     │ │    │ │ │
│  │  │  │  │ SignalR API  │ │    │ │ │
│  │  │  │  │ Port: 8080   │ │    │ │ │
│  │  │  │  └──────────────┘ │    │ │ │
│  │  │  └────────────────────┘    │ │ │
│  │  │                             │ │ │
│  │  └─────────────────────────────┘ │ │
│  │                                   │ │
│  │  Security Group                   │ │
│  │  - SSH (22)                       │ │
│  │  - HTTP (8080)                    │ │
│  │  - HTTPS (8081)                   │ │
│  │                                   │ │
│  └───────────────────────────────────┘ │
│                                         │
│  Internet Gateway                       │
│         ↕                               │
└─────────┼───────────────────────────────┘
          ↕
    Internet (Public IP)
```

---

## Quick Reference Commands

```bash
# Deploy infrastructure
aws cloudformation deploy --template-file infrastructure.yaml \
  --stack-name ws-api-infrastructure --parameter-overrides file://parameters.json \
  --capabilities CAPABILITY_IAM --region us-east-2

# SSH to instance
ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>

# Build Docker image
docker build -t ws-api-dotnet .

# Run container
docker run -d --name ws-api-dotnet -p 8080:8080 -p 8081:8081 \
  -e ASPNETCORE_ENVIRONMENT=Production -e ASPNETCORE_URLS=http://+:8080 \
  --restart unless-stopped ws-api-dotnet

# View logs
docker logs -f ws-api-dotnet

# Restart container
docker restart ws-api-dotnet

# Stop container
docker stop ws-api-dotnet

# Remove container
docker rm ws-api-dotnet

# Check health
curl http://localhost:8080/api/healthz
```

---

## Related Repositories

- **Backend API**: [ws-api-dotnet](https://github.com/nickchow2020/ws-api-dotnet) - .NET SignalR Chat API
- **Frontend** (TBD): React chat application

---

## Support & Documentation

- [AWS CloudFormation Docs](https://docs.aws.amazon.com/cloudformation/)
- [AWS EC2 Docs](https://docs.aws.amazon.com/ec2/)
- [Docker Documentation](https://docs.docker.com/)
- [.NET SignalR Docs](https://docs.microsoft.com/aspnet/core/signalr/)

---

## License

MIT License - See LICENSE file for details

---

## Changelog

### 2025-10-19
- Initial infrastructure setup
- CloudFormation templates created
- EC2 deployment successful
- SignalR Chat API deployed and tested
- CORS configuration added
- Documentation completed
