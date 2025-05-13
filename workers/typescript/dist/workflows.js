"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TypeScriptWorkflowImpl = void 0;
class TypeScriptWorkflowImpl {
    async run(name) {
        return `Hello from TypeScript worker, ${name}!`;
    }
}
exports.TypeScriptWorkflowImpl = TypeScriptWorkflowImpl;
