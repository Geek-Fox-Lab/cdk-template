from aws_cdk import Duration
from aws_cdk import aws_dynamodb as dynamodb
from aws_cdk import aws_lambda as lambda_
from aws_cdk import aws_s3 as s3
from aws_cdk import aws_sns as sns
from aws_cdk import aws_sqs as sqs
from constructs import Construct


class ComputeConstruct(Construct):
    """Compute resources and permissions for request handling."""

    def __init__(
        self,
        scope: Construct,
        construct_id: str
    ) -> None:
        super().__init__(scope, construct_id)
