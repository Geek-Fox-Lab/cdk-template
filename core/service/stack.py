from aws_cdk import CfnOutput, Stack
from constructs import Construct

from core.service.constructs.compute import ComputeConstruct


class ServiceStack(Stack):
    """Unique service stack composed from reusable sample constructs."""

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        environment_name: str,
        project_name: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        name_prefix = f"{project_name}-{environment_name}"
