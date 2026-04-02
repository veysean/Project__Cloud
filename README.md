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
cloud-project/
│
├── provider.tf        # Defines Terraform and AWS provider configuration
├── main.tf            # Core infrastructure (EC2, S3, etc.)
├── security.tf        # Security groups and IAM roles
├── variables.tf       # Input variables (reusable values)
├── outputs.tf         # Output values (e.g., public DNS)
│
├── app/               # Web application source code
│   ├── index.js       # Main application file (Node.js example)
│   └── package.json   # Dependencies for the app
│
├── scripts/
│   └── install.sh     # Script to configure EC2 and run the app
│
├── README.md          # Project documentation
```

