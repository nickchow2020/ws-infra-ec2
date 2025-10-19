# CDK Migration Plan

Migration plan from CloudFormation to AWS CDK with GitHub Actions automation.

## Why CDK + GitHub Actions?

### Benefits
- ✅ **Infrastructure as Code** - TypeScript/Python instead of YAML
- ✅ **Type Safety** - Catch errors before deployment
- ✅ **Reusability** - Share constructs across projects
- ✅ **Testing** - Unit test your infrastructure
- ✅ **CI/CD** - Automated deployments on git push
- ✅ **Better Developer Experience** - IDE autocomplete, refactoring
- ✅ **Version Control** - Track infrastructure changes in git

### Current Stack
```
CloudFormation (YAML) → AWS CLI (Manual) → EC2 → Manual Docker Deploy
```

### Target Stack
```
CDK (TypeScript) → GitHub Actions → AWS → Automated Everything
```

---

## Migration Phases

### Phase 1: CDK Infrastructure Setup (Week 1)
Convert CloudFormation to CDK TypeScript

### Phase 2: GitHub Actions CI/CD (Week 1-2)
Automate deployments on push

### Phase 3: Application Deployment Automation (Week 2)
Docker build and deploy via GitHub Actions

### Phase 4: Enhanced Features (Week 3+)
Monitoring, auto-scaling, multiple environments

---

## Phase 1: CDK Infrastructure Setup

### Step 1.1: Install CDK

```bash
# Install AWS CDK CLI globally
npm install -g aws-cdk

# Verify installation
cdk --version
```

### Step 1.2: Initialize CDK Project

```bash
# Create new CDK project
mkdir ws-infra-cdk
cd ws-infra-cdk

# Initialize TypeScript CDK app
cdk init app --language typescript

# Project structure created:
# bin/           - CDK app entry point
# lib/           - Stack definitions
# test/          - Unit tests
# cdk.json      - CDK configuration
# package.json  - Dependencies
```

### Step 1.3: Install Required Dependencies

```bash
npm install @aws-cdk/aws-ec2 @aws-cdk/aws-iam @aws-cdk/aws-elasticloadbalancingv2
```

### Step 1.4: Create CDK Stack

**`lib/websocket-api-stack.ts`**

```typescript
import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';

export interface WebSocketApiStackProps extends cdk.StackProps {
  environmentName: string;
  instanceType?: ec2.InstanceType;
  keyPairName: string;
}

export class WebSocketApiStack extends cdk.Stack {
  public readonly instance: ec2.Instance;
  public readonly vpc: ec2.Vpc;

  constructor(scope: Construct, id: string, props: WebSocketApiStackProps) {
    super(scope, id, props);

    // VPC
    this.vpc = new ec2.Vpc(this, 'VPC', {
      cidr: '10.0.0.0/16',
      maxAzs: 2,
      natGateways: 0, // No NAT for cost savings
      subnetConfiguration: [
        {
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
      ],
    });

    // Security Group
    const securityGroup = new ec2.SecurityGroup(this, 'WebSocketSG', {
      vpc: this.vpc,
      description: 'Security group for WebSocket API',
      allowAllOutbound: true,
    });

    // Allow SSH
    securityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(22),
      'Allow SSH access'
    );

    // Allow HTTP
    securityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(8080),
      'Allow WebSocket API HTTP'
    );

    // Allow HTTPS
    securityGroup.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(8081),
      'Allow WebSocket API HTTPS'
    );

    // IAM Role for EC2
    const role = new iam.Role(this, 'EC2Role', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
        iam.ManagedPolicy.fromAwsManagedPolicyName('CloudWatchAgentServerPolicy'),
      ],
    });

    // User Data Script
    const userData = ec2.UserData.forLinux();
    userData.addCommands(
      '#!/bin/bash',
      'set -e',
      '',
      '# Update system',
      'yum update -y',
      '',
      '# Install Docker',
      'amazon-linux-extras install docker -y',
      'service docker start',
      'systemctl enable docker',
      'usermod -a -G docker ec2-user',
      '',
      '# Install Docker Compose',
      'curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose',
      'chmod +x /usr/local/bin/docker-compose',
      'ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose',
      '',
      '# Install Git',
      'yum install -y git',
      '',
      '# Create application directory',
      'mkdir -p /opt/websocket-api',
      'chown ec2-user:ec2-user /opt/websocket-api',
      '',
      '# Signal success',
      'yum install -y aws-cfn-bootstrap',
      `/opt/aws/bin/cfn-signal -e $? --stack ${this.stackName} --resource Instance --region ${this.region}`
    );

    // EC2 Instance
    this.instance = new ec2.Instance(this, 'Instance', {
      vpc: this.vpc,
      instanceType: props.instanceType || ec2.InstanceType.of(
        ec2.InstanceClass.T3,
        ec2.InstanceSize.MICRO
      ),
      machineImage: ec2.MachineImage.latestAmazonLinux2(),
      securityGroup: securityGroup,
      role: role,
      keyName: props.keyPairName,
      userData: userData,
      vpcSubnets: {
        subnetType: ec2.SubnetType.PUBLIC,
      },
    });

    // Outputs
    new cdk.CfnOutput(this, 'PublicIP', {
      value: this.instance.instancePublicIp,
      description: 'Public IP address of the EC2 instance',
    });

    new cdk.CfnOutput(this, 'PublicDNS', {
      value: this.instance.instancePublicDnsName,
      description: 'Public DNS name of the EC2 instance',
    });

    new cdk.CfnOutput(this, 'SSHCommand', {
      value: `ssh -i ${props.keyPairName}.pem ec2-user@${this.instance.instancePublicIp}`,
      description: 'SSH command to connect to the instance',
    });

    new cdk.CfnOutput(this, 'WebSocketAPIEndpoint', {
      value: `http://${this.instance.instancePublicIp}:8080`,
      description: 'WebSocket API endpoint',
    });

    new cdk.CfnOutput(this, 'HealthCheckEndpoint', {
      value: `http://${this.instance.instancePublicIp}:8080/api/healthz`,
      description: 'Health check endpoint',
    });

    // Tags
    cdk.Tags.of(this).add('Project', 'WebSocketAPI');
    cdk.Tags.of(this).add('Environment', props.environmentName);
  }
}
```

**`bin/ws-infra-cdk.ts`**

```typescript
#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { WebSocketApiStack } from '../lib/websocket-api-stack';

const app = new cdk.App();

new WebSocketApiStack(app, 'WebSocketApiStack', {
  environmentName: process.env.ENVIRONMENT || 'dev',
  keyPairName: process.env.KEY_PAIR_NAME || 'ws-api-key',
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'us-east-2',
  },
});
```

### Step 1.5: CDK Commands

```bash
# Bootstrap CDK (one-time setup per account/region)
cdk bootstrap

# Synthesize CloudFormation template
cdk synth

# View changes before deploying
cdk diff

# Deploy infrastructure
cdk deploy

# Destroy infrastructure
cdk destroy
```

---

## Phase 2: GitHub Actions CI/CD

### Step 2.1: Repository Structure

```
ws-infra-cdk/
├── .github/
│   └── workflows/
│       ├── deploy-infrastructure.yml    # CDK deployment
│       └── deploy-application.yml       # Docker deployment
├── bin/
│   └── ws-infra-cdk.ts
├── lib/
│   └── websocket-api-stack.ts
├── test/
│   └── websocket-api-stack.test.ts
├── cdk.json
├── package.json
└── README.md
```

### Step 2.2: GitHub Actions - Infrastructure Deployment

**`.github/workflows/deploy-infrastructure.yml`**

```yaml
name: Deploy Infrastructure

on:
  push:
    branches:
      - main
    paths:
      - 'lib/**'
      - 'bin/**'
      - 'cdk.json'
      - '.github/workflows/deploy-infrastructure.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - prod

env:
  AWS_REGION: us-east-2
  NODE_VERSION: '18'

jobs:
  deploy:
    name: Deploy CDK Stack
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: CDK Diff
        run: npm run cdk diff

      - name: CDK Deploy
        run: npm run cdk deploy -- --require-approval never
        env:
          ENVIRONMENT: ${{ github.event.inputs.environment || 'dev' }}
          KEY_PAIR_NAME: ws-api-key

      - name: Get Stack Outputs
        id: stack-outputs
        run: |
          PUBLIC_IP=$(aws cloudformation describe-stacks \
            --stack-name WebSocketApiStack \
            --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' \
            --output text)
          echo "PUBLIC_IP=$PUBLIC_IP" >> $GITHUB_OUTPUT
          echo "Public IP: $PUBLIC_IP"

      - name: Post deployment info
        run: |
          echo "🚀 Infrastructure deployed successfully!"
          echo "Public IP: ${{ steps.stack-outputs.outputs.PUBLIC_IP }}"
          echo "API Endpoint: http://${{ steps.stack-outputs.outputs.PUBLIC_IP }}:8080"
```

### Step 2.3: GitHub Actions - Application Deployment

**`.github/workflows/deploy-application.yml`**

```yaml
name: Deploy Application

on:
  workflow_run:
    workflows: ["Deploy Infrastructure"]
    types:
      - completed
  push:
    branches:
      - main
    paths:
      - 'application/**'
  workflow_dispatch:

env:
  AWS_REGION: us-east-2

jobs:
  deploy:
    name: Deploy Docker Application
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name != 'workflow_run' }}

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Get EC2 instance ID
        id: get-instance
        run: |
          INSTANCE_ID=$(aws cloudformation describe-stacks \
            --stack-name WebSocketApiStack \
            --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
            --output text)
          echo "INSTANCE_ID=$INSTANCE_ID" >> $GITHUB_OUTPUT

      - name: Deploy application to EC2
        run: |
          aws ssm send-command \
            --instance-ids ${{ steps.get-instance.outputs.INSTANCE_ID }} \
            --document-name "AWS-RunShellScript" \
            --parameters 'commands=[
              "cd /opt/websocket-api",
              "if [ -d ws-api-dotnet ]; then cd ws-api-dotnet && git pull; else git clone https://github.com/nickchow2020/ws-api-dotnet.git && cd ws-api-dotnet; fi",
              "docker build -t ws-api-dotnet .",
              "docker stop ws-api-dotnet 2>/dev/null || true",
              "docker rm ws-api-dotnet 2>/dev/null || true",
              "docker run -d --name ws-api-dotnet -p 8080:8080 -p 8081:8081 -e ASPNETCORE_ENVIRONMENT=Production -e ASPNETCORE_URLS=http://+:8080 --restart unless-stopped ws-api-dotnet"
            ]' \
            --output text

      - name: Wait for deployment
        run: sleep 30

      - name: Get Public IP
        id: get-ip
        run: |
          PUBLIC_IP=$(aws cloudformation describe-stacks \
            --stack-name WebSocketApiStack \
            --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' \
            --output text)
          echo "PUBLIC_IP=$PUBLIC_IP" >> $GITHUB_OUTPUT

      - name: Health check
        run: |
          echo "Testing health endpoint..."
          curl -f http://${{ steps.get-ip.outputs.PUBLIC_IP }}:8080/api/healthz || exit 1
          echo "✅ Health check passed!"

      - name: Post deployment summary
        run: |
          echo "🎉 Application deployed successfully!"
          echo "API Endpoint: http://${{ steps.get-ip.outputs.PUBLIC_IP }}:8080"
          echo "SignalR Hub: ws://${{ steps.get-ip.outputs.PUBLIC_IP }}:8080/ws"
```

### Step 2.4: GitHub Secrets Setup

Add these secrets to your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

1. `AWS_ACCESS_KEY_ID` - Your AWS access key
2. `AWS_SECRET_ACCESS_KEY` - Your AWS secret key

---

## Phase 3: Enhanced Features

### Multi-Environment Support

**`cdk.json`**
```json
{
  "app": "npx ts-node bin/ws-infra-cdk.ts",
  "context": {
    "dev": {
      "instanceType": "t3.micro",
      "allowedCIDR": "0.0.0.0/0"
    },
    "prod": {
      "instanceType": "t3.small",
      "allowedCIDR": "0.0.0.0/0"
    }
  }
}
```

### Auto Scaling (Future)

```typescript
// lib/websocket-api-stack.ts
import * as autoscaling from 'aws-cdk-lib/aws-autoscaling';
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';

// Auto Scaling Group
const asg = new autoscaling.AutoScalingGroup(this, 'ASG', {
  vpc: this.vpc,
  instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
  machineImage: ec2.MachineImage.latestAmazonLinux2(),
  minCapacity: 1,
  maxCapacity: 3,
  desiredCapacity: 1,
});

// Application Load Balancer
const alb = new elbv2.ApplicationLoadBalancer(this, 'ALB', {
  vpc: this.vpc,
  internetFacing: true,
});

const listener = alb.addListener('Listener', {
  port: 80,
});

listener.addTargets('Target', {
  port: 8080,
  targets: [asg],
  healthCheck: {
    path: '/api/healthz',
  },
});
```

### Monitoring & Alarms

```typescript
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as sns from 'aws-cdk-lib/aws-sns';

// SNS Topic for alerts
const alertTopic = new sns.Topic(this, 'AlertTopic');

// CPU Alarm
new cloudwatch.Alarm(this, 'HighCPU', {
  metric: this.instance.metricCPUUtilization(),
  threshold: 80,
  evaluationPeriods: 2,
  alarmDescription: 'Alert when CPU exceeds 80%',
});
```

---

## Migration Timeline

### Week 1
- [ ] Set up CDK project
- [ ] Convert CloudFormation to CDK
- [ ] Test CDK deployment
- [ ] Create GitHub Actions workflows
- [ ] Test automated deployment

### Week 2
- [ ] Add multi-environment support
- [ ] Set up monitoring and alarms
- [ ] Add automated tests
- [ ] Document new deployment process

### Week 3+
- [ ] Implement auto-scaling
- [ ] Add load balancer
- [ ] Set up blue/green deployments
- [ ] Add infrastructure tests

---

## Comparison

### Current (CloudFormation)
```bash
# Manual steps
1. Edit parameters.json
2. Run aws cloudformation deploy
3. Wait for completion
4. SSH to EC2
5. Clone repo
6. Edit CORS
7. Build Docker
8. Run container
```

### Future (CDK + GitHub Actions)
```bash
# Automated
1. git push
2. ✅ Done! (Everything automated)
```

---

## Costs

**Current**: Same as now (~$8-10/month)

**With CDK + GitHub Actions**:
- Infrastructure: Same (~$8-10/month)
- GitHub Actions: Free (2000 minutes/month for public repos)
- Total: ~$8-10/month

---

## Resources

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [CDK TypeScript Reference](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-construct-library.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS CDK Examples](https://github.com/aws-samples/aws-cdk-examples)

---

## Next Steps

1. **Learn CDK Basics**
   - Complete [CDK Workshop](https://cdkworkshop.com/)
   - Read CDK documentation
   - Explore CDK examples

2. **Create New Repository**
   ```bash
   mkdir ws-infra-cdk
   cd ws-infra-cdk
   cdk init app --language typescript
   ```

3. **Migrate Incrementally**
   - Start with simple VPC
   - Add EC2 instance
   - Add Security Groups
   - Test thoroughly

4. **Set Up CI/CD**
   - Create GitHub Actions workflows
   - Test automated deployment
   - Add monitoring

5. **Deprecate Old Stack**
   - Once CDK stack is stable
   - Delete CloudFormation stack
   - Update documentation

---

**Status**: Planning Phase
**Target Date**: TBD
**Priority**: Medium (Current CloudFormation works fine for now)
