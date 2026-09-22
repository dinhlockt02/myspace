import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { createHmac, timingSafeEqual } from 'crypto';

const ssm = new SSMClient();
const sqs = new SQSClient();

async function getSsmParameter(name) {
  const command = new GetParameterCommand({
    Name: name,
    WithDecryption: true
  });
  const response = await ssm.send(command);
  return response.Parameter.Value;
}

function verifySignature(payload, signature, secret) {
  const expected = 'sha256=' + createHmac('sha256', secret)
    .update(payload)
    .digest('hex');

  try {
    return timingSafeEqual(
      Buffer.from(expected),
      Buffer.from(signature)
    );
  } catch {
    return false;
  }
}

export const handler = async (event) => {
  const headers = event.headers || {};
  const signature = headers['x-hub-signature-256'] || '';
  const eventType = headers['x-github-event'] || '';

  const body = event.body || '';
  const payload = typeof body === 'string' ? Buffer.from(body) : body;

  const secret = await getSsmParameter(process.env.WEBHOOK_SECRET_SSM);

  if (!verifySignature(payload, signature, secret)) {
    return { statusCode: 401, body: 'invalid signature' };
  }

  const data = JSON.parse(payload.toString());

  if (eventType !== 'workflow_job') {
    return { statusCode: 200, body: 'ignored event type' };
  }

  const action = data.action || '';
  if (action !== 'queued') {
    return { statusCode: 200, body: `ignored action: ${action}` };
  }

  const job = data.workflow_job || {};
  const jobId = job.id;
  const workflowName = job.workflow_name;
  const labels = job.labels || [];

  const message = {
    job_id: jobId,
    workflow_name: workflowName,
    labels: labels,
    owner: process.env.GITHUB_OWNER,
    repo: process.env.GITHUB_REPO
  };

  const command = new SendMessageCommand({
    QueueUrl: process.env.SQS_QUEUE_URL,
    MessageBody: JSON.stringify(message),
    ...(process.env.SQS_QUEUE_URL.includes('fifo') && {
      MessageGroupId: 'default'
    })
  });

  await sqs.send(command);

  return {
    statusCode: 200,
    body: JSON.stringify({ status: 'queued', job_id: jobId })
  };
};
