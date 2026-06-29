# CDK Template

Basic Python AWS CDK project with a `core` package and a sample service stack.

## Structure

- `app.py` - CDK application entrypoint.
- `core/service/stack.py` - unique service stack composition.
- `core/service/constructs/` - sample constructs for security, networking, storage, messaging, compute, API, and observability.
- `Makefile` - setup and AWS CDK workflow targets.

## Setup

```bash
make setup
```

The setup target creates `.venv`, installs Python dependencies, downloads a repo-local Node.js/npm into `.tools/node` when needed, and installs the local CDK CLI from `package.json`.

## AWS Login

Configure AWS CLI defaults in `.env`:

```bash
AWS_PROFILE=default
AWS_REGION=us-east-1
AWS_DEFAULT_REGION=us-east-1
AWS_SDK_LOAD_CONFIG=1
```

For SSO profiles, run:

```bash
aws sso login --profile default
```

`make tools` reads `.env` and reports the active profile, region, and caller identity when logged in.

## CDK Workflow

```bash
make synth
make diff
make deploy
```

Useful variables:

- `AWS_PROFILE` - AWS CLI profile to use, usually set in `.env`.
- `AWS_REGION` - AWS region to target, usually set in `.env`.
- `CONTEXT` - extra CDK context, for example `CONTEXT='-c environment=prod -c project_name=my-service'`.
- `STACK` - optional stack name selector.

Bootstrap a new account/region before the first deploy:

```bash
make bootstrap AWS_PROFILE=my-profile AWS_REGION=us-east-1
```
