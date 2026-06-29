#!/usr/bin/env python3

import aws_cdk as cdk

from core.service import ServiceStack

app = cdk.App()

environment_name = app.node.try_get_context("environment") or "dev"
project_name = app.node.try_get_context("project_name") or "cdk-template"

ServiceStack(
    app,
    f"{project_name}-{environment_name}-service",
    environment_name=environment_name,
    project_name=project_name,
    description="Sample service stack with reusable infrastructure constructs.",
)

app.synth()
