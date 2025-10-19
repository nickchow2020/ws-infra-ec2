# Deployment Checklist

Use this checklist to redeploy your infrastructure and application from scratch.

## Prerequisites Checklist

- [ ] AWS CLI installed and configured
- [ ] AWS Access Keys created and saved
- [ ] EC2 Key Pair created (`ws-api-key`)
- [ ] Key pair file saved securely (`.pem` file)
- [ ] Git installed
- [ ] SSH client available

---

## Part 1: Infrastructure Deployment (10 minutes)

### Step 1: Configure AWS CLI
```bash
aws configure
# Access Key ID: [YOUR_KEY]
# Secret Access Key: [YOUR_SECRET]
# Region: us-east-2
# Output: json
```
- [ ] AWS CLI configured

### Step 2: Update Parameters
```bash
# Edit parameters.json
# Change KeyPairName to: ws-api-key
```
- [ ] `parameters.json` updated with correct key pair name

### Step 3: Deploy CloudFormation Stack

**Windows PowerShell:**
```powershell
aws cloudformation deploy `
    --template-file infrastructure.yaml `
    --stack-name ws-api-infrastructure `
    --parameter-overrides file://parameters.json `
    --capabilities CAPABILITY_IAM `
    --region us-east-2
```

- [ ] CloudFormation deployment started
- [ ] Wait 5-10 minutes for completion
- [ ] Deployment successful

### Step 4: Get Stack Outputs
```powershell
aws cloudformation describe-stacks `
    --stack-name ws-api-infrastructure `
    --region us-east-2 `
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' `
    --output table
```

**Save these values:**
- [ ] PublicIP: `_________________`
- [ ] SSHCommand: `_________________`
- [ ] WebSocketAPIEndpoint: `_________________`

---

## Part 2: Application Deployment (15 minutes)

### Step 5: SSH into EC2
```bash
ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>
```
- [ ] Successfully connected to EC2

### Step 6: Clone Backend Repository
```bash
cd /opt/websocket-api
git clone https://github.com/nickchow2020/ws-api-dotnet.git
cd ws-api-dotnet
ls -la
```
- [ ] Repository cloned
- [ ] Files visible (Dockerfile, Program.cs, etc.)

### Step 7: Configure CORS
```bash
nano appsettings.Production.json
```

Update to:
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
    "null"
  ]
}
```

Save: `Ctrl+X`, `Y`, `Enter`

- [ ] CORS configuration updated
- [ ] No trailing commas in JSON
- [ ] File saved successfully

### Step 8: Build Docker Image
```bash
docker build -t ws-api-dotnet .
```
- [ ] Build started
- [ ] Wait 2-3 minutes
- [ ] Build completed successfully

### Step 9: Run Container
```bash
docker run -d \
  --name ws-api-dotnet \
  -p 8080:8080 \
  -p 8081:8081 \
  -e ASPNETCORE_ENVIRONMENT=Production \
  -e ASPNETCORE_URLS=http://+:8080 \
  --restart unless-stopped \
  ws-api-dotnet
```
- [ ] Container started
- [ ] Container ID displayed

### Step 10: Verify Container
```bash
docker ps
docker logs ws-api-dotnet
```
- [ ] Container status: `Up`
- [ ] No error messages in logs

---

## Part 3: Testing (5 minutes)

### Step 11: Test Health Endpoint

**From EC2:**
```bash
curl http://localhost:8080/api/healthz
```
- [ ] Response: `{"status":"ok"}`

**From Local Machine (PowerShell):**
```powershell
curl http://<PUBLIC_IP>:8080/api/healthz
```
- [ ] Response: `{"status":"ok"}`
- [ ] StatusCode: 200

### Step 12: Test SignalR Connection

Open `test-signalr.html` in browser (update IP first)

- [ ] HTML test file created
- [ ] Public IP updated in file
- [ ] File opened in browser
- [ ] "Connect" button clicked
- [ ] Status shows "Connected successfully!"
- [ ] Test message sent
- [ ] Message received

---

## Final Verification

- [ ] Infrastructure deployed successfully
- [ ] EC2 instance running
- [ ] Application container running
- [ ] Health check passing
- [ ] SignalR connection working
- [ ] No errors in logs

---

## Important Information to Save

**Stack Details:**
- Stack Name: `ws-api-infrastructure`
- Region: `us-east-2`
- Key Pair: `ws-api-key`

**Endpoints:**
- Health: `http://<PUBLIC_IP>:8080/api/healthz`
- SignalR Hub: `http://<PUBLIC_IP>:8080/ws`
- SSH: `ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>`

**Docker Container:**
- Image Name: `ws-api-dotnet`
- Container Name: `ws-api-dotnet`
- Ports: 8080, 8081

---

## Troubleshooting

If something fails, check:

### Infrastructure Issues
```bash
# View stack events
aws cloudformation describe-stack-events \
    --stack-name ws-api-infrastructure \
    --region us-east-2 \
    --max-items 20
```

### Application Issues
```bash
# Check Docker
docker ps -a
docker logs ws-api-dotnet

# Rebuild if needed
docker stop ws-api-dotnet
docker rm ws-api-dotnet
docker build -t ws-api-dotnet .
# Then run container again
```

### CORS Issues
```bash
# Verify appsettings.Production.json
cat appsettings.Production.json

# Must not have trailing commas!
# Rebuild container after fixing
```

---

## Quick Commands Reference

```bash
# Deploy infrastructure
aws cloudformation deploy --template-file infrastructure.yaml \
  --stack-name ws-api-infrastructure --parameter-overrides file://parameters.json \
  --capabilities CAPABILITY_IAM --region us-east-2

# Get outputs
aws cloudformation describe-stacks --stack-name ws-api-infrastructure \
  --region us-east-2 --query 'Stacks[0].Outputs'

# SSH
ssh -i ws-api-key.pem ec2-user@<PUBLIC_IP>

# Build & Run
docker build -t ws-api-dotnet .
docker run -d --name ws-api-dotnet -p 8080:8080 -p 8081:8081 \
  -e ASPNETCORE_ENVIRONMENT=Production -e ASPNETCORE_URLS=http://+:8080 \
  --restart unless-stopped ws-api-dotnet

# Check status
docker ps
docker logs -f ws-api-dotnet
curl http://localhost:8080/api/healthz

# Delete everything
aws cloudformation delete-stack --stack-name ws-api-infrastructure --region us-east-2
```

---

## Estimated Time

- **Infrastructure Deployment**: 10 minutes
- **Application Deployment**: 15 minutes
- **Testing**: 5 minutes
- **Total**: ~30 minutes

---

## Notes

- Keep your `.pem` file secure (never commit to git)
- Save your AWS Access Keys securely
- Note your Public IP (changes if instance restarts)
- Check CORS settings before testing frontend
- Monitor costs in AWS Billing Dashboard

---

**Last Updated**: 2025-10-19
**Status**: Tested and Working ✅
