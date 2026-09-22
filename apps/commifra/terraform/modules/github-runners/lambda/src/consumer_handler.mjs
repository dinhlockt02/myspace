import { EC2Client, RunInstancesCommand, DescribeInstancesCommand } from '@aws-sdk/client-ec2';

const ec2 = new EC2Client();

async function countRunningRunners() {
  const command = new DescribeInstancesCommand({
    Filters: [
      { Name: 'tag:Module', Values: ['github-runners'] },
      { Name: 'instance-state-name', Values: ['pending', 'running'] }
    ]
  });

  const response = await ec2.send(command);
  const reservations = response.Reservations || [];

  return reservations.reduce((sum, r) => {
    return sum + (r.Instances?.length || 0);
  }, 0);
}

function getNextSubnet(subnetIds, jobNumber) {
  const index = jobNumber % subnetIds.length;
  return subnetIds[index];
}

async function launchRunner(jobId, workflowName) {
  const subnetIds = process.env.SUBNET_IDS.split(',');
  const launchTemplateId = process.env.LAUNCH_TEMPLATE_ID;
  const maxRunners = parseInt(process.env.MAX_RUNNERS);

  const currentCount = await countRunningRunners();

  if (currentCount >= maxRunners) {
    return { status: 'skipped', reason: 'max runners reached' };
  }

  const startIndex = jobId % subnetIds.length;
  const triedSubnets = [];

  for (let i = 0; i < subnetIds.length; i++) {
    const subnetIndex = (startIndex + i) % subnetIds.length;
    const subnetId = subnetIds[subnetIndex];
    triedSubnets.push(subnetId);

    const command = new RunInstancesCommand({
      LaunchTemplate: { LaunchTemplateId: launchTemplateId },
      MinCount: 1,
      MaxCount: 1,
      SubnetId: subnetId,
      TagSpecifications: [
        {
          ResourceType: 'instance',
          Tags: [
            { Key: 'Name', Value: 'commifra-github-runner' },
            { Key: 'Module', Value: 'github-runners' },
            { Key: 'JobId', Value: String(jobId) },
            { Key: 'WorkflowName', Value: workflowName },
            { Key: 'Project', Value: 'myspace' },
            { Key: 'App', Value: 'commifra' }
          ]
        }
      ]
    });

    try {
      await ec2.send(command);
      return { status: 'launched', job_id: jobId, subnet_id: subnetId };
    } catch (error) {
      if (error.name === 'InsufficientInstanceCapacityError' || 
          error.name === 'Unsupported' ||
          (error.Code && error.Code.includes('Insufficient'))) {
        console.warn(`Capacity issue in subnet ${subnetId}, trying next subnet`);
        continue;
      }
      throw error;
    }
  }

  return { 
    status: 'failed', 
    job_id: jobId, 
    reason: 'insufficient capacity in all subnets',
    tried_subnets: triedSubnets 
  };
}

export const handler = async (event) => {
  const results = [];

  for (const record of event.Records || []) {
    const body = JSON.parse(record.body);

    const jobId = body.job_id;
    const workflowName = body.workflow_name || 'unknown';

    const result = await launchRunner(jobId, workflowName);
    results.push(result);
  }

  return { batchItemFailures: [] };
};
