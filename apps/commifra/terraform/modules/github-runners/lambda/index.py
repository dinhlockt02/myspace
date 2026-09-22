import hashlib
import hmac
import json
import os

import boto3
import urllib.request

ssm = boto3.client("ssm")
ec2 = boto3.client("ec2")


def get_ssm(name: str) -> str:
    return ssm.get_parameter(Name=name, WithDecryption=True)["Parameter"]["Value"]


def verify_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = "sha256=" + hmac.new(
        secret.encode(), payload, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def count_running_runners() -> int:
    resp = ec2.describe_instances(
        Filters=[
            {"Name": "tag:Module", "Values": ["github-runners"]},
            {
                "Name": "instance-state-name",
                "Values": ["pending", "running"],
            },
        ]
    )
    return sum(
        len(r["Instances"]) for r in resp.get("Reservations", [])
    )


def launch_runner():
    subnet_ids = os.environ["SUBNET_IDS"].split(",")
    launch_template_id = os.environ["LAUNCH_TEMPLATE_ID"]
    max_runners = int(os.environ["MAX_RUNNERS"])

    if count_running_runners() >= max_runners:
        return {"status": "skipped", "reason": "max runners reached"}

    ec2.run_instances(
        LaunchTemplate={"LaunchTemplateId": launch_template_id},
        MinCount=1,
        MaxCount=1,
        SubnetId=subnet_ids[0],
    )
    return {"status": "launched"}


def handler(event, context):
    headers = event.get("headers", {})
    signature = headers.get("x-hub-signature-256", "")
    event_type = headers.get("x-github-event", "")

    body = event.get("body", "")
    if isinstance(body, str):
        payload = body.encode()
    else:
        payload = body

    secret = get_ssm(os.environ["WEBHOOK_SECRET_SSM"])

    if not verify_signature(payload, signature, secret):
        return {"statusCode": 401, "body": "invalid signature"}

    data = json.loads(payload)

    if event_type != "workflow_job":
        return {"statusCode": 200, "body": "ignored event type"}

    action = data.get("action", "")
    if action != "queued":
        return {"statusCode": 200, "body": f"ignored action: {action}"}

    result = launch_runner()
    return {"statusCode": 200, "body": json.dumps(result)}
