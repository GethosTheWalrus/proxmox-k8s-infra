export async function greet(name: string): Promise<string> {
  return `Hello, ${name}!`;
}

export async function processTypeScript(message: string, language: string): Promise<string> {
  return `TypeScript says: ${message}`;
}

export async function ProcessTypeScript(message: string): Promise<string> {
  return `TypeScript says: ${message}`;
} 