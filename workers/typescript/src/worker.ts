import { Worker } from '@temporalio/worker';
import { NativeConnection } from '@temporalio/client';
import * as activities from './activities';
import { TypeScriptWorkflowImpl } from './workflows';
import dotenv from 'dotenv';

dotenv.config();

async function run() {
  const connection = await NativeConnection.connect({
    address: process.env.TEMPORAL_HOST || 'temporal-frontend.temporal.svc.cluster.local:7233',
  });

  const worker = await Worker.create({
    connection,
    namespace: process.env.TEMPORAL_NAMESPACE || 'default',
    taskQueue: 'typescript-task-queue',
    workflowsPath: require.resolve('./workflows'),
    activities,
  });

  console.log('TypeScript worker started');
  await worker.run();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
}); 