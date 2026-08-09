# Terraform CI/CD – Basic Workflow

A hands-on Terraform learning repository created to understand how Terraform can be integrated with **GitHub Actions** to implement a basic **CI/CD workflow**.

The repository intentionally contains a simple Terraform configuration with a single child module for creating an Azure Resource Group. The primary objective is not to build a large infrastructure platform, but to understand the fundamentals of:

- Terraform modules
- Terraform formatting and validation
- Terraform plan and apply
- GitHub Actions workflows
- Pull Request based CI
- Security scanning
- TFLint
- GitHub branch protection
- Conditional job execution
- Terraform CI/CD flow

---

## Architecture

The repository contains a simple Terraform configuration:

```text
GitHub Repository
│
├── .github/
│   └── workflows/
│       └── terraform.yaml
│
├── azurerm_resource_group/
│   ├── main.tf
│   └── variable.tf
│
├── environment/
│   └── dev/
│       ├── main.tf
│       ├── provider.tf
│       ├── terraform.tfvars
│       └── variables.tf
│
├── .gitignore
└── README.md
```

### Terraform Structure

The `environment/dev` directory acts as the root Terraform configuration.

It consumes the reusable child module:

```text
environment/dev
       │
       ▼
azurerm_resource_group
       │
       ▼
Azure Resource Group
```

The child module is intentionally kept simple because this repository is primarily focused on learning Terraform workflow automation.

---

# Terraform Module

## `azurerm_resource_group`

The repository contains one child module:

```text
azurerm_resource_group/
├── main.tf
└── variable.tf
```

The module is responsible for creating an Azure Resource Group.

The development environment consumes this module from:

```text
environment/dev/main.tf
```

This demonstrates the basic Terraform module pattern:

```text
Root Module
    │
    └── Child Module
            │
            └── Azure Resource Group
```

---

# GitHub Actions CI/CD Workflow

The repository uses GitHub Actions to implement a basic Terraform CI/CD pipeline.

The workflow is located at:

```text
.github/workflows/terraform.yaml
```

The workflow responds to two events:

```yaml
on:
  pull_request:
    branches:
      - main

  push:
    branches:
      - main
```

This creates two different execution paths.

---

## Pull Request Workflow

When a Pull Request is opened or updated against `main`, the workflow performs validation and security checks.

```text
Pull Request
     │
     ▼
Security Scan
     │
     ├── Gitleaks
     ├── TruffleHog
     └── TFLint
     │
     ▼
Terraform Plan
     │
     ├── Terraform fmt
     ├── Terraform init
     ├── Terraform validate
     └── Terraform plan
```

The Terraform Plan job depends on the Security Scan job:

```yaml
needs: scan
```

Therefore:

```text
Security Scan
      │
      │ success
      ▼
Terraform Plan
```

If the security scan fails, the Terraform Plan job does not run.

---

# Security and Code Quality Checks

The Pull Request workflow performs several checks before Terraform changes can be merged.

## Gitleaks

[Gitleaks](https://github.com/gitleaks/gitleaks) is used to detect accidentally committed secrets and credentials.

Examples include:

- API keys
- passwords
- tokens
- private keys
- cloud credentials

---

## TruffleHog

[TruffleHog](https://github.com/trufflesecurity/trufflehog) is used to search the repository for potentially exposed secrets.

The workflow uses:

```text
--results=verified,unknown
```

to identify verified and potentially valid secrets.

---

## TFLint

[TFLint](https://github.com/terraform-linters/tflint) is used to lint Terraform configuration.

The workflow:

1. Installs TFLint
2. Initializes TFLint
3. Runs TFLint against the Terraform configuration

TFLint helps identify Terraform-specific problems and enforce coding best practices before infrastructure changes are merged.

---

# Terraform Plan

After the security and linting checks pass, the Terraform Plan job runs.

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

The Terraform working directory is:

```text
environment/dev
```

This demonstrates how GitHub Actions can execute Terraform commands from a specific working directory.

---

# Terraform Apply

Terraform Apply is intentionally separated from the Pull Request validation process.

The Apply job runs only when the workflow receives a push event for the `main` branch:

```yaml
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

The flow is therefore:

```text
                  FEATURE BRANCH
                       │
                       ▼
                     SCAN
                       │
                       ▼
                 PLAN + development
                       │
                       │
                       ▼
                    PR → main
                       │
                       ▼
                    MERGE
                       │
                       ▼
                  PUSH TO MAIN
                       │
              ┌────────┴────────┐
              ▼                 ▼
            SCAN              PLAN
                                │
                         development
                                │
                                ▼
                         APPLY JOB
                                │
                         production
                                │
                                ▼
                    ┌──────────────────┐
                    │ Manual Approval  │
                    └────────┬─────────┘
                             │
                             ▼
                      Terraform Apply
```

---

# Branch Protection

The `main` branch is protected so that the required CI checks must pass before a Pull Request can be merged.

The intended flow is:

```text
Pull Request
     │
     ├── Security Scan ── PASS
     │
     └── Terraform Plan ─ PASS
              │
              ▼
          PR can merge
              │
              ▼
          Push to main
              │
              ▼
        Terraform Apply
```

This demonstrates an important CI/CD principle:

> **Infrastructure changes should pass automated checks before they are allowed to reach the deployment stage.**

---

# Azure Authentication

The workflow uses GitHub Actions authentication with Azure through OpenID Connect (OIDC).

The workflow provides:

```yaml
permissions:
  id-token: write
  contents: read
```

Azure authentication is performed using:

```yaml
azure/login
```

with:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

stored as GitHub repository secrets.

This avoids storing a long-lived Azure client secret in the repository.

---

# Terraform Workflow Stages

The complete workflow can be summarized as:

```text
                    Pull Request
                         │
                         ▼
              ┌─────────────────────┐
              │   Security Scan      │
              │                     │
              │ • Gitleaks          │
              │ • TruffleHog        │
              │ • TFLint            │
              └──────────┬──────────┘
                         │
                      SUCCESS
                         │
                         ▼
              ┌─────────────────────┐
              │   Terraform Plan    │
              │                     │
              │ • fmt                │
              │ • init               │
              │ • validate           │
              │ • plan               │
              └──────────┬──────────┘
                         │
                      SUCCESS
                         │
                         ▼
                Branch Protection
                         │
                         ▼
                    PR Merged
                         │
                         ▼
                  Push → main
                         │
                         ▼
              ┌─────────────────────┐
              │  Terraform Apply    │
              └─────────────────────┘
```

---

# What This Repository Demonstrates

This repository is intentionally small, but it demonstrates several important DevOps and Infrastructure-as-Code concepts.

### Terraform

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

### GitHub Actions

- Workflow triggers
- Jobs
- Steps
- Job dependencies
- `needs`
- Conditional execution with `if`
- Environment-specific working directories
- GitHub Actions secrets
- OIDC authentication
- Pull Request workflows
- Push workflows

### DevSecOps

- Secret scanning
- Terraform linting
- Automated validation
- Branch protection
- Security checks before merge

---

# Learning Objective

The main objective of this repository is to understand the lifecycle of a Terraform change in a Git-based CI/CD environment:

```text
Write Terraform
      ↓
Commit
      ↓
Create Pull Request
      ↓
Security Checks
      ↓
Terraform Validation
      ↓
Terraform Plan
      ↓
Code Review
      ↓
Merge
      ↓
Terraform Apply
```

The infrastructure itself is intentionally simple so that the focus remains on understanding the **Terraform CI/CD workflow and GitHub Actions execution model**.

---

# Future Learning

This repository can be extended incrementally as more Terraform and DevOps concepts are learned.

Possible future additions include:

- Terraform plan artifacts
- Applying the exact approved Terraform plan
- Checkov
- Infracost
- Terraform test
- Terraform state management
- Environment promotion
- Manual approval before Apply
- GitHub Environments
- Deployment protection rules
- Reusable GitHub Actions workflows
- Matrix-based Terraform environments
- Remote state using Azure Storage
- Multiple Terraform modules
- Dev / Test / UAT / Production environments

---

## Purpose

This repository is part of a hands-on learning journey focused on **Terraform, Azure, GitHub Actions, CI/CD, and DevSecOps practices**.

The goal is to learn the concepts by building and progressively improving the workflow rather than starting with a complex enterprise implementation.
