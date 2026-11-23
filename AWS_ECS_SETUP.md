# Deploy Keycloak to Amazon ECS

GitHub Actions builds the repository's [Dockerfile](Dockerfile) and publishes the image to Amazon ECR. Use the published image URI to create the first ECS task definition and service. Subsequent workflow runs publish new images. To roll out a new image, register a task definition revision and update the ECS service.

## 1. Create the GitHub Actions IAM role

Start with a private ECR repository and the IAM OIDC provider `https://token.actions.githubusercontent.com` with audience `sts.amazonaws.com`. This guide assumes the repository and role are in the same AWS account.

In the AWS console, open **IAM → Roles → Create role → Custom trust policy**. Name the role `github-actions-keycloak` and replace `ACCOUNT_ID` in the trust policy below with your AWS account ID.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:nyilinhtut1994/keycloak:ref:refs/heads/*"
        }
      }
    }
  ]
}
```

This trusts branch workflows in `nyilinhtut1994/keycloak`. Anyone with permission to push workflow changes to a branch in that repository can use the role. The example matches the original GitHub subject format and assumes the job has no GitHub Environment. If the repository uses immutable subjects, use `repo:nyilinhtut1994@OWNER_ID/keycloak@REPO_ID:ref:refs/heads/*` with the actual IDs. [GitHub OIDC subject formats](https://docs.github.com/en/actions/reference/security/oidc)

On the role, open **Permissions → Add permissions → Create inline policy → JSON**. Replace `ECR_REPOSITORY_ARN` with the full ARN shown for your private repository in ECR. The workflow needs these permissions to publish to that repository. [AWS ECR push permissions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-push-iam.html)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "ECR_REPOSITORY_ARN"
    }
  ]
}
```

## 2. Configure GitHub and publish the image

On `nyilinhtut1994/keycloak`, open **Settings → Secrets and variables → Actions → Variables**. Add the following **repository variables**.

| Variable | Value |
| --- | --- |
| `AWS_ROLE_ARN` | Full ARN of the GitHub Actions IAM role |
| `AWS_REGION` | Region of the ECR repository |
| `ECR_REPOSITORY` | ECR repository name, such as `keycloak` |

Push a branch containing [.github/workflows/deploy.yml](.github/workflows/deploy.yml). The workflow runs on pushes to any branch that contains it. Once the workflow is on the default branch, you can also open **Actions → Publish Keycloak image to Amazon ECR → Run workflow** and choose a branch. GitHub uses OIDC to obtain temporary AWS credentials. [GitHub OIDC setup](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)

After the run succeeds, copy the **ECR image** URI from the run summary. The tag uses `<commit-sha>-<run-id>-<run-attempt>`. Confirm the tag appears in **ECR → Repositories → your repository → Images**.

## 3. Create the ECS task definition and service

The steps below use Linux on Fargate, PostgreSQL, and an Application Load Balancer (ALB) that terminates HTTPS. Have a VPC, a reachable PostgreSQL database, and a DNS name and certificate for Keycloak ready.

1. **Create an ECS task execution role.** Use the ECS tasks trust principal `ecs-tasks.amazonaws.com` and attach `AmazonECSTaskExecutionRolePolicy` for ECR pulls and CloudWatch Logs. If the task definition injects Secrets Manager values, grant this execution role `secretsmanager:GetSecretValue` on those secret ARNs and `kms:Decrypt` on the relevant customer-managed KMS key if one encrypts them. [ECS task execution role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html)
2. **Register the task definition.** In **ECS → Task definitions → Create new task definition**, choose Fargate with Linux/X86_64 to match the workflow's image. Use the task execution role from step 1. Add an essential container named `keycloak`, paste the full ECR image URI from the workflow summary, map TCP port `8080`, and enable CloudWatch logging. Add the settings below to the container definition. [AWS task definition guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/create-task-definition.html)
3. **Create the load balancer and service.** Configure an HTTPS listener on port `443` with the certificate for your Keycloak hostname. Forward traffic to an IP target group on HTTP port `8080`. With the default Keycloak path, set the target group's HTTP health check path to `/realms/master/.well-known/openid-configuration`. Allow the ECS task security group to receive port `8080` from the ALB security group, and allow the task to connect to PostgreSQL. Private tasks need access to ECR, S3, CloudWatch Logs, and Secrets Manager when used, through NAT or the relevant VPC endpoints. Create a Fargate service in your ECS cluster using the task definition and attach the target group to the Keycloak container. Start with one task and point the Keycloak DNS name to the ALB. [ECS Application Load Balancer setup](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/alb.html)
4. **Verify the deployment.** Check that the ECS task is running and the ALB target is healthy. Request `https://<your-keycloak-hostname>/realms/master/.well-known/openid-configuration` and confirm it returns HTTP `200` and an issuer URL with your public hostname.

### Keycloak container settings

| Name | Where to set it | Value |
| --- | --- | --- |
| `KC_DB` | Environment variable | `postgres` |
| `KC_DB_URL_HOST` | Environment variable | PostgreSQL endpoint hostname |
| `KC_DB_URL_DATABASE` | Environment variable | Database name |
| `KC_DB_URL_PORT` | Environment variable | PostgreSQL port if different from `5432` |
| `KC_DB_USERNAME` | Secrets Manager | Database username |
| `KC_DB_PASSWORD` | Secrets Manager | Database password |
| `KC_HOSTNAME` | Environment variable | Public URL, such as `https://keycloak.example.com` |
| `KC_HTTP_ENABLED` | Environment variable | `true` for HTTP between the ALB and the task |
| `KC_PROXY_HEADERS` | Environment variable | `xforwarded` for the ALB's forwarded headers |
| `KC_BOOTSTRAP_ADMIN_USERNAME` | Secrets Manager | Initial admin username for a fresh database |
| `KC_BOOTSTRAP_ADMIN_PASSWORD` | Secrets Manager | Initial admin password for a fresh database |

For each Secrets Manager entry, add a container secret mapping with the environment variable name and the secret ARN or JSON key reference. After first startup, open `/admin` through the public hostname and create a permanent admin account. [ECS secret injection](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html) · [Keycloak database settings](https://www.keycloak.org/server/db) · [Keycloak reverse proxy settings](https://www.keycloak.org/server/reverseproxy) · [Keycloak container settings](https://www.keycloak.org/server/containers)

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| GitHub fails to assume the IAM role | Check `AWS_ROLE_ARN`, the OIDC provider audience, and whether the role's `sub` pattern matches the repository's subject format for the selected branch. |
| ECR push returns `AccessDenied` | Compare `AWS_REGION` and `ECR_REPOSITORY` with the configured repository. Check that the role policy allows uploads to its exact ARN. |
| Docker build fails during the SCIM download | The [Dockerfile](Dockerfile) references SCIM `7.7.1` for Keycloak major version 26. The public release list does not show that asset. A `404` at the `curl` step requires a valid artifact compatible with the Keycloak base image before ECR publishing can succeed. [Public SCIM releases](https://github.com/Captain-P-Goldfish/scim-for-keycloak/releases) |
| ECS cannot pull the image or read a secret | Check the image URI, task execution role, and subnet connectivity to ECR and Secrets Manager. Review the stopped task's reason in ECS. |
| ECS starts the task but the ALB target is unhealthy | Check the health check path, target port, security groups, and Keycloak startup logs for database connection or configuration errors. |
