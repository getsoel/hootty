/** Shared output formatting for human vs --json mode. */

export function printJson(data: unknown): void {
  console.log(JSON.stringify(data, null, 2));
}

export function printError(message: string): void {
  console.error(`error: ${message}`);
}

export function printSuccess(message: string): void {
  console.log(message);
}
