# Deploying to AWS

There are many different ways to deploy applications - one of the reasons why
Distillery is as configurable as it is, is due to the inherently custom nature
of most deployment environments.

There are also many ways of deploying to AWS! Particularly with recent
developments which add hosted Kubernetes to the AWS family of services, you
essentially have 3 main choices: VMs with EC2, containers with ECS, or
containers with EKS/Fargate.

This guide is going to cover a deployment methodology that is based on
Infrastructure as Code (IaC), and continuous integration and deployment.

For this, we do the following:

  * Define all infrastructure resources via CloudFormation templates
  * Provision the initial deployment pipeline with a `pipeline.yml`
    CloudFormation template, this creates a stack with CodePipeline, CodeBuild,
    and CodeDeploy resources, an encrypted S3 bucket for build artifacts, an IAM
    role for EC2 instances, and IAM roles for the CodePipeline/Build/Deploy
    services.
  * The pipeline monitors a GitHub repository via webhook, pushes trigger the
    pipeline to fetch the source from GitHub for that revision, and push it into
    an S3 bucket for CodeBuild
  * CodeBuild runs the build for the application in Docker, in a Centos7 base
    image which will allow us to build a release for an Amazon Linux 2-based EC2
    host.
  * A successful build will output artifacts for deployment, of which two files
    define the CloudFormation template for the infrastructure being deployed to,
    and the configuration for that infrastructure, `infra.yml` and `production.conf`
    respectively. This enables us to create multiple environments in the future if desired.
  * The first stage of deployment involves CloudFormation getting the template
    for the target infrastructure, applying the template configuration, and then
    creating the resulting infrastructure it if it doesn't exist, updating it
    if it does, or replacing it if the last infrastructure deployment failed.
  * The final stage of deployment involves CodeDeploy, which interacts with the
    EC2 hosts created in the previous step to install the release, run any
    prerequisite steps, and then start the release. CodeDeploy will deploy to one
    host at a time, disconnecting it from the load balancer, installing the
    release, then reconnecting it to the load balancer, until all hosts are updated.

!!! warning
    While I put a lot of effort into this guide, I do not make any
    guarantees that it is free of defects or security holes. If you do use this
    guide to set up your own infrastructure, you need to take the time to
    understand what you are doing, and have someone that is an expert review it
    to ensure that it is secure. Use at your own risk!

## Features

If you aren't sure why you would want to set this infrastructure up, the
following is a list of the benefits:

  * _Infrastructure as Code_ - your infrastructure is defined, and lives
    alongside, your application code. Changes to that infrastructure are
    versioned and managed just like any other code.
  * _Automated Builds_ - each commit to `master` triggers a build which produces
    a Distillery release as an artifact
  * _Continuous Deployment_ - each successful build initiates a deployment.
    Faster iteration times mean smaller surface area for review and root cause
    analysis when things go wrong, it is also easier to roll back
  * _Zero Downtime Deploys_ - all hosts sit behind an application load balancer
    which ensures traffic is always being routed to a functional host. When
    deployments are rolled out, hosts have their connections drained, and are
    then disconnected from the load balancer, upgraded, then reconnected to the
    load balancer when they have passed health checks. This process ensures that
    users will never notice a rollout, unless intended
  * _Automatic Rollbacks_ - if a deployment fails, they are automatically rolled
    back by the pipeline, including changes to infrastructure
  * _Automatic Scaling_ - the use of autoscaling groups means that the application
    can be scaled up in response to monitoring events
  * _Load Balancing_ - load is automatically balanced between hosts, and configured with
    sticky sessions, traffic for a given session will always be routed to the
    same node
  * _Secure Configuration_ - secrets are stored via SSM in the parameter store
    as secure strings, encrypted with a key dedicated to the stack. Only the
    application and adminstrators can access the secrets
  * _Secure Networking_ - use of security groups and network rules ensure that
    only the traffic which we want to allow is permitted to reach each area of
    the infrastructure

## Prerequisites

You will need the following in order to follow along with this guide, I will
cover some setup/configuration, but you won't be able to follow along without
these things:

  * An AWS account - this seems obvious, but hey, we're not going to start out
    by leaving things out of the guide
  * An AWS user with administrative privileges, with the credentials exported,
    i.e. you have the values for `AWS_ACCESS_KEY_ID` and
    `AWS_SECRET_ACCESS_KEY`.
  * You have installed `awscli` - you can do this with `brew install awscli` or
    by following the installation instructions [here](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)
  * You have logged in to `awscli` with `aws configure`
  * You have forked and cloned the example application from [here](https://github.com/bitwalker/distillery-aws-example)
  * You have generated a GitHub OAuth token with `repo` and `admin:repo_hook` privileges
  * You have provisioned an SSH key pair in AWS, and have the private key handy
    (see [[Provisioning an SSH key pair]] for instructions)

!!! warning
    This guide has you spin up infrastructure in AWS. This infrastructure costs
    money, though it is a small amount if only running through the guide to see
    how it works, it is important to be aware that the resources involved do not
    all fall under the AWS Free Tier. If you do not want to incur costs, then
    you will not be able to follow this guide.

## The Application

The example application we will use is a Phoenix application backed by a
Postgres database. The web app itself is just a slightly modified TodoMVC clone
which writes to the database via Phoenix.

It has the following requirements:

  * Needs to serve plain HTTP traffic on some port
  * Needs to serve secure HTTP traffic on another port (optional for this guide)
  * Needs access to a Postgres database

In AWS, we will set it up like so:

  * The application listens on port 4000
  * An Application Load Balancer (ALB) listens on port 80 and forwards traffic
  to port 4000
  * An RDS instance serves as our Postgres backend

In addition, we set it up so that we can SSH to the EC2 host, just in case we
need to access a remote shell to the app, or do troubleshooting on the host.

### Release Configuration

The example application makes use of a few extra Distillery features to help
make things easy to deploy:

  * We use the Mix config provider to execute a dedicated config file on the EC2
    host, this config file handles fetching secrets from SSM
  * We use overlays to add a custom command for migrations, a systemd service
    unit, and a custom `vm.args`

Otherwise, it is a normal release.

## Provisioning an SSH key pair

To get an SSH key pair we can use to access EC2 hosts managed in our
infrastructure, we can use the AWS CLI:

    $ aws ec2 create-key-pair --key-name="distillery-aws-example" > key.out
    $ cat key.out | jq '.KeyMaterial' --raw-output > distillery-aws-example.pem

!!! info
    If you don't have `jq` installed, you can do so via HomeBrew, or simply copy
    the contents of the `KeyMaterial` property in `key.out` to the `.pem` file.

!!! warning
    The `.pem` we just created contains the private key for the SSH key pair.
    Make sure to keep it safe and secure.

## Provisioning a GitHub OAuth token

You need to provision a GitHub OAuth token for the webhook needed by CodePipeline:

  1. Visit https://github.com/settings/tokens
  2. Click "Generate New Token"
  3. Set description to "CodePipeline access for distillery-aws-example"
  4. Add `repo` and `admin:repo_hook` permissions
  5. Click "Generate Token"
  6. Copy the token somewhere secure

## Provisioning our pipeline

!!! tip
    If you want to follow progress of various components, you can do so in the
    [AWS Console](https://console.aws.amazon.com). To navigate to a particular
    service, click the Services dropdown and type in the name of the service you
    are looking for. For the most part, the ones you will be interested in are
    CloudFormation and CodePipeline, they will take you to other areas if you
    follow links. Lambda, CodeDeploy, and CodeBuild are also of interest.

First, make sure you are in the root of the
[distillery-aws-example repo](https://github.com/bitwalker/distillery-aws-example)
(which you should have forked into your own account, and cloned locally):

    $ git clone git@github.com:myaccount/distillery-aws-example.git
    $ cd distillery-aws-example

Now we need to spin up the CloudFormation stack for the pipeline:

    $ export GITHUB_TOKEN="<oauth_token>"
    $ export SSH_KEY_NAME=distillery-aws-example
    $ export APP_NAME=my-unique-name
    $ bin/cfn create

!!! info
    The values above are placeholders, use the names of the resources you
    created (i.e. if you used a different key name for the SSH key pair you
    created, set it appropriately here)
    
!!! info
    The name of the S3 bucket that will be created is derived from `APP_NAME`.
    Because S3 bucket names must be globally unique, it's important to set a
    unique `APP_NAME` so that the bucket will have a unique name.
    
!!! tip
    This step can take awhile, you can follow along in the AWS Console by
    navigating to the CloudFormation service.

This will spin up the initial CI/CD pipeline, then kick it off for the first
time, pulling source from the given GitHub user/repo. A successful build will
then kick off the creation of the "production" CloudFormation stack which will
provision all of the other resources need by the application (RDS, load
balancers, auto-scaling groups, etc.)

Once the second stack is up, and the CodeDeploy stage in CodePipeline has
finished, you can proceed to the next section.

## Testing It Out

To see the app in action, you will need to open up the `-production` stack in
CloudFormation and look at the outputs for `WebsiteURL`. This is the URL we can
use to access the application via the load balancer (we don't bother to
provision a DNS record for this guide, but that would be the logical next step).

The URL should look something like:

    http://distillery-example-alb-XXXXXXXX.us-east-1.elb.amazonaws.com

## Cleaning Up

To clean up the resources created in this guide, run the `clean` task:

    $ export GITHUB_TOKEN="<oauth_token>"
    $ export SSH_KEY_NAME=distillery-aws-example
    $ bin/cfn destroy

This cleans up all the versioned objects in S3 from builds run through the
pipeline, then deletes the CloudFormation stacks that were created. This can
take some time, so you may want to do other things while it completes.

!!! warning
    Don't forget to revoke the GitHub OAuth token you created, and delete the SSH key pair in AWS!

## Further Reading

I plan to expand this guide with some additional information and advice on
adapting to your own application or using different approaches to configuration,
until then, the following links are recommended reading if you are looking to
get started with AWS.

  * [AWS Well-Architected Framework](https://d1.awsstatic.com/whitepapers/architecture/AWS_Well-Architected_Framework.pdf)
  * [The Open Guide to AWS](https://github.com/open-guides/og-aws)
