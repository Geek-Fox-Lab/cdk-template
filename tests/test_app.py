import aws_cdk as cdk
from aws_cdk import assertions

from core.service import ServiceStack


def test_service_stack_synthesizes_bucket_table_and_api() -> None:
    app = cdk.App()

    stack = ServiceStack(
        app,
        "test-service",
        environment_name="test",
        project_name="cdk-template",
    )

    template = assertions.Template.from_stack(stack)

    template.resource_count_is("AWS::S3::Bucket", 1)
    template.resource_count_is("AWS::DynamoDB::Table", 1)
    template.resource_count_is("AWS::ApiGateway::RestApi", 1)
    template.resource_count_is("AWS::Lambda::Function", 1)
