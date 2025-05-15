import { Worker, NativeConnection } from '@temporalio/worker';
import * as activities from './activities';

async function run() {
  const connection = await NativeConnection.connect({
    address: process.env.TEMPORAL_ADDRESS || 'temporal:7233',
  });

  const worker = await Worker.create({
    connection,
    namespace: process.env.TEMPORAL_NAMESPACE || 'default',
    taskQueue: 'typescript-task-queue',
    activities,
  });

  console.log('TypeScript worker started');
  await worker.run();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
}); 