# Terraform CI/CD – Basic Workflow

A hands-on Terraform learning repository created to understand how **Terraform**, **Azure**, and **GitHub Actions** can be combined to implement a basic CI/CD workflow with DevSecOps practices.

The infrastructure in this repository is intentionally simple. It contains a single Azure Resource Group child module so that the primary focus remains on understanding Terraform workflow automation, GitHub Actions jobs, security scanning, environments, approvals, and deployment flow.

---

## 🎯 Learning Objectives

This repository is designed to provide hands-on practice with:

- Terraform root and child modules
- Terraform formatting and validation
- Terraform initialization, planning, and applying
- GitHub Actions workflows
- Workflow triggers and path filters
- Job dependencies using `needs`
- Conditional job execution using `if`
- Terraform security and code-quality scanning
- Gitleaks and TruffleHog
- TFLint
- Azure authentication using GitHub OIDC
- GitHub Environments
- Development and Production environment separation
- Production deployment approval
- GitHub branch protection
- CI/CD concepts for Infrastructure as Code

---

# 📁 Repository Structure

```text
workflow-basic-1/
│
├── .github/
│   └── workflows/
│       └── terraform.yaml
│
├── environment/
│   └── dev/
│       ├── main.tf
│       ├── provider.tf
│       ├── terraform.tfvars
│       └── variables.tf
│
├── modules/
│   └── azurerm_resource_group/
│       ├── main.tf
│       └── variable.tf
│
├── .gitignore
└── README.md
```

---

# 🏗️ Terraform Architecture

The repository follows a simple **root module → child module** structure.

```text
environment/dev
      │
      │ module call
      ▼
modules/azurerm_resource_group
      │
      ▼
Azure Resource Group
```

### Root Module

The Terraform root configuration is located at:

```text
environment/dev
```

It contains:

- `main.tf`
- `provider.tf`
- `terraform.tfvars`
- `variables.tf`

This directory is used as the Terraform working directory by GitHub Actions.

### Child Module

The repository contains one child module:

```text
modules/azurerm_resource_group
```

The module contains:

```text
main.tf
variable.tf
```

Its purpose is to demonstrate how a root module can consume a reusable Terraform child module to create an Azure Resource Group.

The module is intentionally simple because this repository focuses primarily on learning the CI/CD workflow rather than building a large infrastructure platform.

---

# 🔄 GitHub Actions CI/CD Workflow

The GitHub Actions workflow is located at:

```text
.github/workflows/terraform.yaml
```

The workflow is triggered by pushes, while README-only changes are ignored:

```yaml
on:
  push:
    paths-ignore:
      - '**/README.md'
```

This means changes to documentation files matching `**/README.md` do not trigger the Terraform workflow.

This is useful because a documentation-only change does not require Terraform security scanning, planning, or deployment.

---

# 🔐 Workflow Permissions

The workflow uses the following permissions:

```yaml
permissions:
  id-token: write
  contents: read
```

### `contents: read`

Allows the workflow to check out and read repository contents.

### `id-token: write`

Allows GitHub Actions to request an OIDC token.

The OIDC token is then used by Azure authentication so that the workflow can authenticate to Azure without storing a long-lived Azure client secret.

---

# 🔍 Security Scan Job

The first job is the **Security Scan** job.

It performs:

```text
Security Scan
      │
      ├── Gitleaks
      │
      ├── TruffleHog
      │
      └── TFLint
```

The purpose is to identify potential security and Terraform configuration issues before infrastructure changes proceed to the planning stage.

## Gitleaks

Gitleaks is used to scan the repository for accidentally committed secrets and sensitive information.

Examples include:

- API keys
- passwords
- tokens
- private keys
- cloud credentials

## TruffleHog

TruffleHog is another secret-scanning tool used to search the repository for potentially exposed credentials.

The workflow uses:

```text
--results=verified,unknown
```

The configuration requests verified and unknown findings.

## TFLint

TFLint is used to lint Terraform configuration and identify Terraform-specific issues and best-practice violations.

The workflow:

1. Installs TFLint
2. Displays the installed version
3. Initializes TFLint
4. Runs TFLint

Example:

```yaml
- name: Setup TFLint
  uses: terraform-linters/setup-tflint@v6

- name: Init TFLint
  run: tflint --init

- name: Run TFLint
  run: tflint -f compact
```

---

# 📋 Terraform Plan Job

The **Terraform Plan** job depends on the Security Scan job:

```yaml
needs: scan
```

The dependency creates this relationship:

```text
Security Scan
      │
      │ success
      ▼
Terraform Plan
```

If the `scan` job fails, the `plan` job does not proceed.

The Terraform Plan job runs from:

```text
environment/dev
```

The job performs:

```text
Terraform fmt
      │
      ▼
Terraform init
      │
      ▼
Terraform validate
      │
      ▼
Terraform plan
```

### Terraform fmt

Checks whether the Terraform configuration is correctly formatted:

```bash
terraform fmt -check
```

### Terraform init

Initializes the Terraform working directory and downloads the required provider/module dependencies:

```bash
terraform init
```

### Terraform validate

Validates the Terraform configuration:

```bash
terraform validate
```

### Terraform plan

Creates an execution plan showing what Terraform intends to change:

```bash
terraform plan
```

---

# 🌎 GitHub Environments

This workflow uses two GitHub Environments:

```text
development
production
```

They represent two different stages of the deployment lifecycle.

```text
Terraform Plan
      │
      ▼
development
      │
      ▼
production
      │
      ▼
Manual Approval
      │
      ▼
Terraform Apply
```

## Development Environment

The Plan job uses:

```yaml
environment:
  name: development
```

The Development environment does not have a required reviewer.

Its purpose is to represent the non-production stage of the workflow.

The Terraform Plan is associated with this environment.

## Production Environment

The Apply job uses:

```yaml
environment:
  name: production
```

The Production environment has a required reviewer configured in GitHub.

When the workflow reaches the Production environment, GitHub pauses the deployment until an authorized reviewer approves it.

The flow becomes:

```text
Terraform Apply Job
        │
        ▼
 Production Environment
        │
        ▼
  Reviewer Approval
        │
   ┌────┴────┐
   │         │
 APPROVE    REJECT
   │         │
   ▼         ▼
 Apply     Stop
```

This demonstrates how GitHub Environments can be used to introduce a manual approval gate before production deployment.

---

# 🚀 Terraform Apply Job

The Apply job is responsible for deploying the Terraform configuration.

It is configured with:

```yaml
if: github.ref == 'refs/heads/main'
```

and:

```yaml
needs: plan
```

Therefore, the intended dependency is:

```text
Plan
 │
 │ success
 ▼
Apply
 │
 ▼
Production Environment
 │
 │ approval
 ▼
Terraform Apply
```

The Apply job uses:

```bash
terraform init
terraform apply -auto-approve
```

The Terraform working directory remains:

```text
environment/dev
```

---

# 🔀 Complete CI/CD Flow

The complete workflow can be visualized as:

```text
                    Git Push
                       │
                       ▼
              README-only change?
                  /          \
                YES           NO
                 │             │
                 ▼             ▼
              Ignore       Security Scan
                             │
                 ┌───────────┼───────────┐
                 │           │           │
                 ▼           ▼           ▼
              Gitleaks   TruffleHog    TFLint
                 │           │           │
                 └───────────┼───────────┘
                             │
                           SUCCESS
                             │
                             ▼
                    Terraform Plan
                             │
                    ┌────────┼────────┐
                    │        │        │
                    ▼        ▼        ▼
                   fmt      init    validate
                                      │
                                      ▼
                                    plan
                                      │
                                      ▼
                              Development
                              Environment
                                      │
                                      ▼
                                Plan Success
                                      │
                                      ▼
                                Apply Job
                                      │
                                      ▼
                              Production
                              Environment
                                      │
                                      ▼
                              Manual Approval
                                      │
                                ┌─────┴─────┐
                                │           │
                             APPROVE      REJECT
                                │           │
                                ▼           ▼
                          Terraform      Deployment
                            Apply          stops
```

---

# 🛡️ Branch Protection

The `main` branch is protected.

Branch protection is an important part of the CI/CD design because it prevents changes from being merged into `main` without satisfying the configured repository rules.

The intended development model is:

```text
Feature Branch
      │
      ▼
Pull Request
      │
      ▼
Required Checks
      │
      ▼
Code Review
      │
      ▼
Merge to main
```

The repository therefore demonstrates the principle of using GitHub repository controls together with CI checks to protect the main infrastructure branch.

---

# 🔑 Azure Authentication with OIDC

The workflow authenticates to Azure using GitHub Actions OIDC.

Azure login is performed using:

```yaml
- name: Azure login
  uses: azure/login@v3
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

The workflow therefore needs:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

configured as GitHub secrets.

The important security advantage is that the workflow does not need to store a long-lived Azure client secret.

The authentication model is:

```text
GitHub Actions
      │
      │ OIDC token
      ▼
Microsoft Entra ID
      │
      │ Federated Identity
      ▼
Azure Service Principal / App Registration
      │
      ▼
Azure Subscription
```

---

# 🧩 Job Dependencies

The workflow demonstrates GitHub Actions job dependencies using `needs`.

The primary dependency is:

```yaml
plan:
  needs: scan
```

and:

```yaml
apply:
  needs: plan
```

This creates:

```text
scan
  │
  ▼
plan
  │
  ▼
apply
```

This is an important GitHub Actions concept because jobs normally run independently unless a dependency is explicitly defined.

---

# 🧠 Conditional Job Execution

The Apply job contains:

```yaml
if: github.ref == 'refs/heads/main'
```

This demonstrates conditional execution of a GitHub Actions job.

The condition evaluates the Git reference and allows the Apply job to run only when the workflow is executing against `main`.

---

# 📦 Terraform Version

The workflow installs Terraform using:

```yaml
- uses: hashicorp/setup-terraform@v4
  with:
    terraform_version: "1.14.6"
```

Pinning the Terraform version helps keep the workflow consistent and predictable across GitHub-hosted runners.

---

# 🎯 What This Repository Demonstrates

## Terraform

- Root modules
- Child modules
- Variables
- Provider configuration
- Terraform state
- `terraform fmt`
- `terraform init`
- `terraform validate`
- `terraform plan`
- `terraform apply`

## GitHub Actions

- Workflow triggers
- Path filters
- Jobs
- Steps
- Job dependencies
- `needs`
- Conditional execution with `if`
- Working directories
- GitHub secrets
- OIDC authentication
- GitHub Environments

## DevSecOps

- Gitleaks
- TruffleHog
- TFLint
- Automated validation
- Branch protection
- Production approval gates

## Azure

- Azure Resource Group
- Microsoft Entra ID / App Registration
- Federated Identity Credentials
- OIDC authentication
- Azure subscription authentication

---

# 📚 Learning Path

The repository is intentionally small so that concepts can be introduced progressively.

A typical learning progression is:

```text
Terraform Basics
      │
      ▼
Terraform Modules
      │
      ▼
Git & GitHub
      │
      ▼
GitHub Actions
      │
      ▼
Terraform CI
      │
      ▼
Security Scanning
      │
      ▼
Terraform Plan
      │
      ▼
GitHub Environments
      │
      ▼
Production Approval
      │
      ▼
Terraform Apply
```

The objective is to understand not only **what** each tool does, but also **why** it is placed at a particular stage of the workflow.

---

# 🔮 Future Improvements

This repository can be progressively extended as additional Terraform and DevOps concepts are learned.

Possible future improvements include:

- Terraform plan artifacts
- Applying the exact reviewed Terraform plan
- Checkov
- Infracost
- Terraform test
- Remote Terraform state using Azure Storage
- State locking and state management
- Multiple reusable Terraform modules
- Dev / Test / UAT / Production environments
- Environment promotion
- Reusable GitHub Actions workflows
- Composite actions
- Matrix-based Terraform workflows
- Deployment protection rules
- Manual approval strategies
- Cost estimation
- Additional policy-as-code checks
- More advanced DevSecOps controls

---

# 🎓 Purpose of the Repository

This repository is part of a hands-on learning journey focused on:

**Terraform • Azure • GitHub Actions • CI/CD • DevSecOps • Infrastructure as Code**

The infrastructure is intentionally simple. The goal is to progressively build understanding by adding one concept at a time rather than starting with a complex enterprise implementation.

> **Learn the infrastructure. Understand the workflow. Automate the deployment.**

---

## License

This repository is intended primarily as a learning and practice project.
