# Deployment Guide

This guide covers deploying the legacy EC2 application using Terraform.

## Prerequisites Checklist

- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform >= 1.5.0 installed
- [ ] (Optional) SSH key pair created in AWS Console
- [ ] (Optional) Route53 hosted zone for domain

## Step-by-Step Deployment

### 1. Clone and Prepare

```bash
# If using git
git clone <repo-url>
cd ec2-legacy-app

# Or if starting from files
cd ec2-legacy-app
```

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region   = "us-east-1"  # Change to your preferred region
project_name = "legacy-api"
environment  = "production"

instance_type = "t3.micro"  # Can use t3.small for better performance

# If you have an SSH key pair in AWS:
key_pair_name = "my-keypair-name"

# Restrict access in production:
allowed_cidr_blocks = ["YOUR_IP/32"]  # Your IP address

# Optional: Route53 DNS
# domain_name     = "api.example.com"
# route53_zone_id = "Z1234567890ABC"

tags = {
  Owner       = "devops-team"
  Environment = "production"
}
```

### 3. Initialize Terraform

```bash
terraform init
```

This will download the AWS provider and initialize the backend.

### 4. Validate Configuration

```bash
terraform validate
terraform fmt -check
```

### 5. Review Deployment Plan

```bash
terraform plan -out=tfplan
```

Review what will be created:
- VPC and networking components
- Security groups
- EC2 instance
- S3 bucket
- IAM roles
- Elastic IP

### 6. Deploy Infrastructure

```bash
terraform apply
# Or use the plan file:
terraform apply tfplan
```

Type `yes` when prompted. This will take approximately 3-5 minutes.

### 7. Verify Deployment

Wait for the instance to be ready (about 2-3 minutes after `terraform apply` completes):

```bash
# Get instance details
terraform output

# Get application URL
APP_URL=$(terraform output -raw application_url)
echo "Application URL: $APP_URL"

# Test health endpoint
curl $APP_URL/health
```

### 8. Test Application Endpoints

```bash
# Set APP_URL variable
APP_URL=$(terraform output -raw application_url)

# Health check
curl $APP_URL/health | jq

# List products
curl $APP_URL/api/v1/products | jq

# Get specific product
curl $APP_URL/api/v1/products/1 | jq

# Create an order
curl -X POST $APP_URL/api/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 2}' | jq

# List orders
curl $APP_URL/api/v1/orders | jq

# Get stats
curl $APP_URL/api/v1/stats | jq
```

### 9. SSH into Instance (Optional)

If you configured a key pair:

```bash
INSTANCE_IP=$(terraform output -raw ec2_instance_public_ip)
KEY_PATH="~/.ssh/your-key.pem"  # Path to your private key

ssh -i $KEY_PATH ubuntu@$INSTANCE_IP

# Once inside:
sudo systemctl status flask-app
sudo journalctl -u flask-app -n 50
tail -f /var/log/flask-app/access.log
```

## Troubleshooting

### Instance not responding

1. **Check instance status**:
   ```bash
   aws ec2 describe-instance-status \
     --instance-ids $(terraform output -raw ec2_instance_id) \
     --region $(terraform output -raw aws_region)
   ```

2. **Check security groups**: Ensure port 80 is open
   ```bash
   aws ec2 describe-security-groups \
     --group-ids $(terraform output -raw security_group_id)
   ```

3. **SSH into instance** (if key pair configured):
   ```bash
   # Check if services are running
   sudo systemctl status flask-app
   sudo systemctl status nginx
   
   # Check logs
   sudo journalctl -u flask-app -n 100
   sudo tail -f /var/log/nginx/flask-error.log
   ```

### Application setup failed

1. **Check user-data logs**:
   ```bash
   ssh -i ~/.ssh/key.pem ubuntu@<instance-ip>
   cat /var/log/user-data.log
   cat /var/log/app-setup.log
   ```

2. **Manually run setup**:
   ```bash
   sudo /opt/flask-app/scripts/setup.sh
   ```

### Health check failing

1. **Test Flask app directly**:
   ```bash
   curl http://localhost:5000/health
   ```

2. **Check Gunicorn process**:
   ```bash
   ps aux | grep gunicorn
   sudo netstat -tlnp | grep 5000
   ```

3. **Restart services**:
   ```bash
   sudo systemctl restart flask-app
   sudo systemctl restart nginx
   ```

## Monitoring

### Application Logs (on EC2 instance)

```bash
# Application access logs
tail -f /var/log/flask-app/access.log

# Application error logs
tail -f /var/log/flask-app/error.log

# Systemd logs
sudo journalctl -u flask-app -f

# Nginx logs
tail -f /var/log/nginx/flask-access.log
tail -f /var/log/nginx/flask-error.log
```

### EC2 Metrics (AWS Console)

- CloudWatch → Metrics → EC2
- CPUUtilization
- NetworkIn/NetworkOut
- StatusCheckFailed

## Cost Estimation

Approximate monthly costs (us-east-1):

- **t3.micro EC2**: ~$7.50/month
- **Elastic IP**: $0/month (free when attached to instance)
- **S3 Storage**: ~$0.023/GB/month (minimal for this app)
- **Data Transfer**: First 100GB free, then ~$0.09/GB
- **VPC**: Free
- **Total**: ~$8-15/month (depending on traffic)

💡 **Tip**: Stop/terminate instances when not in use to save costs.

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

⚠️ **Warning**: This permanently deletes:
- EC2 instance and all data
- S3 bucket and contents
- All networking resources
- Elastic IP (will be released)

## Next Steps: Migration to ECS

After deploying this legacy application, students should:

1. ✅ Verify application works correctly
2. ✅ Understand current architecture
3. ✅ Document API endpoints and behavior
4. ✅ Plan ECS migration strategy
5. ✅ Design zero-downtime cutover plan

See the main README.md for migration goals and requirements.
