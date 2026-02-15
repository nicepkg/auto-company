import { execFile } from "node:child_process";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export const PROJECT_ROOT = process.cwd();
export const RUNS_DIR = path.join(PROJECT_ROOT, "runs");
export const TEMPLATES_DIR = path.join(PROJECT_ROOT, "templates");

export type CommandResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
};

export function sanitizeRunId(runId: unknown): string {
  if (typeof runId !== "string") {
    throw new Error("runId is required");
  }
  const value = runId.trim();
  if (!value) {
    throw new Error("runId is required");
  }
  if (!/^[a-zA-Z0-9_-]+$/.test(value)) {
    throw new Error("runId can contain only letters, numbers, dashes, and underscores");
  }
  return value;
}

export function runDir(runId: string): string {
  return path.join(RUNS_DIR, sanitizeRunId(runId));
}

export function runFile(runId: string, fileName: string): string {
  return path.join(runDir(runId), fileName);
}

export async function readRunJson<T>(runId: string, fileName: string): Promise<T> {
  const payload = await readFile(runFile(runId, fileName), "utf-8");
  return JSON.parse(payload) as T;
}

export async function runPythonCli(
  args: string[],
  options?: { allowNonZeroExit?: boolean }
): Promise<CommandResult> {
  const fullArgs = ["-m", "sq_autopilot.cli", ...args];

  try {
    const { stdout, stderr } = await execFileAsync("python3", fullArgs, {
      cwd: PROJECT_ROOT,
      env: {
        ...process.env,
        PYTHONPATH: path.join(PROJECT_ROOT, "src")
      }
    });

    return {
      stdout,
      stderr,
      exitCode: 0
    };
  } catch (error) {
    const err = error as NodeJS.ErrnoException & {
      code?: number;
      stdout?: string;
      stderr?: string;
    };
    const exitCode = typeof err.code === "number" ? err.code : 1;
    const result = {
      stdout: err.stdout ?? "",
      stderr: err.stderr ?? err.message,
      exitCode
    };

    if (options?.allowNonZeroExit) {
      return result;
    }

    throw new Error(
      `Python CLI failed (exit ${exitCode}): ${result.stderr || result.stdout || "unknown error"}`
    );
  }
}

export async function withTempDir<T>(prefix: string, work: (dir: string) => Promise<T>): Promise<T> {
  const dir = path.join(os.tmpdir(), "sq-autopilot-hosted", `${prefix}-${Date.now()}`);
  await mkdir(dir, { recursive: true });

  try {
    return await work(dir);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

export async function writeTempFile(
  dir: string,
  fileName: string,
  content: string
): Promise<string> {
  const filePath = path.join(dir, fileName);
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, content, "utf-8");
  return filePath;
}

export function templateFile(fileName: string): string {
  return path.join(TEMPLATES_DIR, fileName);
}
