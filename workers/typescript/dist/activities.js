"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.greet = greet;
exports.processTypeScript = processTypeScript;
async function greet(name) {
    return `Hello, ${name}!`;
}
async function processTypeScript(message, language) {
    return `TypeScript says: ${message}`;
}
