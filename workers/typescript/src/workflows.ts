import { proxyActivities } from '@temporalio/workflow';

export interface TypeScriptWorkflow {
  run(name: string): Promise<string>;
}

export class TypeScriptWorkflowImpl implements TypeScriptWorkflow {
  async run(name: string): Promise<string> {
    return `Hello from TypeScript worker, ${name}!`;
  }
} 