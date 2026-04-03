# 🌐 Cloud Computing Project – AWS Scalable Web Application

## 📌 Project Overview

This project demonstrates how to design, provision, and deploy a **scalable, secure, and highly available web application** using **Amazon Web Services (AWS)** and **Terraform (Infrastructure as Code)**.

The system follows cloud best practices, including:

* High availability (multiple EC2 instances)
* Scalability (Auto Scaling Group)
* Security (IAM roles and security groups)
* Observability (CloudWatch monitoring and logging)

---

## 🏗️ Architecture Overview

```
User → Load Balancer → EC2 Instances (Auto Scaling)
                         ↓
                      RDS Database
                         ↓
                        S3 Storage
```

---

## 🛠️ Technologies & Tools Used

| Tool           | Purpose                               |
| -------------- | ------------------------------------- |
| AWS EC2        | Hosts the web application             |
| AWS RDS        | Stores structured data (database)     |
| AWS S3         | Stores static files (images, uploads) |
| AWS ELB        | Distributes traffic across instances  |
| AWS ASG        | Automatically scales EC2 instances    |
| AWS IAM        | Manages permissions and access        |
| AWS VPC        | Provides network isolation            |
| AWS CloudWatch | Monitoring and logging                |
| Terraform      | Infrastructure as Code                |
| GitHub         | Version control                       |

---

## 📁 Project Structure

```
project__cloud/
│
├── provider.tf         # AWS and Terraform version configurations
├── main.tf             # Root "Bridge": Connects the user inputs to the modules
├── variables.tf        # Root "Inputs": Where you set your actual values and defaults
├── outputs.tf          # Root "Display": Prints the final IPs and URLs to your screen
│
├── modules/            # Reusable Infrastructure Logic
│   ├── vpc.tf          # Networking (VPC, Subnets, Routing)
│   ├── rds.tf          # Database (Private RDS instance)
│   ├── ec2.tf          # Compute (App Server)
│   ├── security.tf     # Firewalls (Web and DB Security Groups)
│   ├── variables.tf    # Module "Inputs": The variables the module expects
│   └── outputs.tf      # Module "Outputs": The data the module shares back
│   └── cloudwatch.tf   # Monitoring and alarm configuration
│
├── app/                # Web application source code
│   ├── index.js        # Main application file (Node.js example)
│   └── package.json    # Dependencies for the app
│
├── scripts/
│   └── install.sh      # Script to configure EC2 and run the app
│
├── README.md           # Project documentation
```

