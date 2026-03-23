import { spawnSync } from "node:child_process";
import path from "node:path";
import { findGodotConsole } from "./godot-paths.mjs";

const rootDir = path.resolve(".");
const projectDir = path.join(rootDir, "godot");

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: rootDir,
    stdio: "inherit",
    shell: false,
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

const godotConsole = findGodotConsole();
if (!godotConsole) {
  process.stderr.write("Unable to locate Godot console executable. Set GODOT_CONSOLE_PATH if needed.\n");
  process.exit(1);
}

run(process.execPath, [path.join("scripts", "sync-content.mjs")]);
run(godotConsole, [
  "--headless",
  "--path",
  projectDir,
  "--script",
  "res://scripts/tests/run_batch1_tests.gd",
]);
run(godotConsole, [
  "--headless",
  "--path",
  projectDir,
  "--script",
  "res://scripts/tests/run_batch2_ui_smoke.gd",
]);
run(godotConsole, [
  "--headless",
  "--path",
  projectDir,
  "--script",
  "res://scripts/tests/run_batch3_tools_tests.gd",
]);
run(godotConsole, [
  "--headless",
  "--path",
  projectDir,
  "--script",
  "res://scripts/tests/run_batch4_support_tests.gd",
]);
run(godotConsole, [
  "--headless",
  "--path",
  projectDir,
  "--script",
  "res://scripts/tests/run_batch5_demo_tests.gd",
]);
run(godotConsole, [
  "--headless",
  "--path",
  projectDir,
  "--script",
  "res://scripts/tests/run_batch6_campaign_tests.gd",
]);
