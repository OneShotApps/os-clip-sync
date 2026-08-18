#!/usr/bin/env node
"use strict";

const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const REPOSITORY_ROOT = path.resolve(__dirname, "..");
const OAUTH_CONFIG_PATH = path.join(
  REPOSITORY_ROOT,
  "keys",
  "google-oauth.json",
);
const REDIRECT_PORT = "8000";
const LOOPBACK_URL = `http://localhost:${REDIRECT_PORT}`;
const FLUTTER_COMMANDS_WITH_DART_DEFINES = new Set(["build", "run"]);

function showUsage() {
  console.log(`Usage:
  node tools/with-google-oauth.js --check
  node tools/with-google-oauth.js [--cwd REPOSITORY_PATH] -- COMMAND [ARGUMENTS...]

Validates keys/google-oauth.json without printing its values. A child command
receives CLIP_SYNC_GOOGLE_CLIENT_IDS for Docker Compose interpolation. Flutter
build and run commands also receive the client values through a
temporary --dart-define-from-file file, which is removed after the command.

Prerequisites: Node.js 22+ and the requested child command on PATH.`);
}

function readOAuthConfig() {
  let document;

  try {
    document = JSON.parse(fs.readFileSync(OAUTH_CONFIG_PATH, "utf8"));
  } catch (error) {
    throw new Error(
      `Cannot read ${path.relative(REPOSITORY_ROOT, OAUTH_CONFIG_PATH)}: ${error.message}`,
    );
  }

  const config = document.web;
  const validClientId =
    typeof config?.client_id === "string" &&
    config.client_id.endsWith(".apps.googleusercontent.com");
  const validClientSecret =
    typeof config?.client_secret === "string" &&
    config.client_secret.length > 0;
  const validOrigin =
    Array.isArray(config?.javascript_origins) &&
    config.javascript_origins.includes(LOOPBACK_URL);
  const validRedirect =
    Array.isArray(config?.redirect_uris) &&
    config.redirect_uris.includes(LOOPBACK_URL);

  if (!validClientId || !validClientSecret || !validOrigin || !validRedirect) {
    throw new Error(
      `OAuth configuration must contain a Google web client ID, client secret, and exact ${LOOPBACK_URL} origin and redirect URI.`,
    );
  }

  return {
    clientId: config.client_id,
    clientSecret: config.client_secret,
  };
}

function resolveWorkingDirectory(value) {
  const workingDirectory = path.resolve(REPOSITORY_ROOT, value);
  const relativePath = path.relative(REPOSITORY_ROOT, workingDirectory);
  const outsideRepository =
    relativePath.startsWith(`..${path.sep}`) || path.isAbsolute(relativePath);

  if (outsideRepository || !fs.statSync(workingDirectory).isDirectory()) {
    throw new Error(
      "--cwd must name an existing directory inside this repository.",
    );
  }

  return workingDirectory;
}

function parseArguments(argumentsList) {
  if (argumentsList.length === 1 && argumentsList[0] === "--check") {
    return { checkOnly: true };
  }

  if (
    argumentsList.length === 1 &&
    ["--help", "-h"].includes(argumentsList[0])
  ) {
    return { showHelp: true };
  }

  const remaining = [...argumentsList];
  let workingDirectory = process.cwd();

  if (remaining[0] === "--cwd") {
    if (!remaining[1]) {
      throw new Error("--cwd requires a repository-relative directory.");
    }
    workingDirectory = resolveWorkingDirectory(remaining[1]);
    remaining.splice(0, 2);
  }

  if (remaining[0] === "--") {
    remaining.shift();
  }
  if (remaining.length === 0) {
    throw new Error("Provide --check or a child command to run.");
  }

  return {
    checkOnly: false,
    command: remaining[0],
    commandArguments: remaining.slice(1),
    workingDirectory,
  };
}

function isFlutterCommand(command) {
  return ["flutter", "flutter.bat", "flutter.exe"].includes(
    path.basename(command).toLowerCase(),
  );
}

function createFlutterDefines(config) {
  const temporaryDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), "clip-sync-google-oauth-"),
  );
  const definesPath = path.join(temporaryDirectory, "dart-defines.json");

  fs.writeFileSync(
    definesPath,
    JSON.stringify({
      CLIP_SYNC_GOOGLE_CLIENT_ID: config.clientId,
      CLIP_SYNC_GOOGLE_CLIENT_SECRET: config.clientSecret,
      CLIP_SYNC_GOOGLE_REDIRECT_PORT: REDIRECT_PORT,
    }),
    { encoding: "utf8", mode: 0o600 },
  );

  return { definesPath, temporaryDirectory };
}

function removeFlutterDefines(temporaryFile) {
  if (!temporaryFile) {
    return;
  }

  fs.unlinkSync(temporaryFile.definesPath);
  fs.rmdirSync(temporaryFile.temporaryDirectory);
}

function run() {
  const parsedArguments = parseArguments(process.argv.slice(2));
  if (parsedArguments.showHelp) {
    showUsage();
    return;
  }

  const oauthConfig = readOAuthConfig();
  if (parsedArguments.checkOnly) {
    console.log(
      "Google OAuth client configuration is valid; credential values were not displayed.",
    );
    return;
  }

  let temporaryFile;
  const commandArguments = [...parsedArguments.commandArguments];
  const injectFlutterDefines =
    isFlutterCommand(parsedArguments.command) &&
    FLUTTER_COMMANDS_WITH_DART_DEFINES.has(commandArguments[0]);

  if (injectFlutterDefines) {
    if (
      commandArguments.some((value) =>
        value.startsWith("--dart-define-from-file"),
      )
    ) {
      throw new Error(
        "Remove the existing --dart-define-from-file argument; this launcher supplies it.",
      );
    }
    temporaryFile = createFlutterDefines(oauthConfig);
    commandArguments.push(
      `--dart-define-from-file=${temporaryFile.definesPath}`,
    );
  }

  const command =
    process.platform === "win32" && parsedArguments.command === "flutter"
      ? "flutter.bat"
      : parsedArguments.command;

  try {
    const result = spawnSync(command, commandArguments, {
      cwd: parsedArguments.workingDirectory,
      env: {
        ...process.env,
        CLIP_SYNC_GOOGLE_CLIENT_IDS: oauthConfig.clientId,
      },
      stdio: "inherit",
    });

    if (result.error) {
      throw result.error;
    }
    process.exitCode = result.status ?? 1;
  } finally {
    removeFlutterDefines(temporaryFile);
  }
}

try {
  run();
} catch (error) {
  console.error(`Google OAuth launcher failed: ${error.message}`);
  process.exitCode = 1;
}
