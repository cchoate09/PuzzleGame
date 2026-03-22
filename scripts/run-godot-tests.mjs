import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const rootDir = path.resolve(".");
const projectDir = path.join(rootDir, "godot");

function findGodotConsole() {
  const candidates = [
    process.env.GODOT_CONSOLE_PATH,
    path.join(
      process.env.LOCALAPPDATA || "",
      "Microsoft",
      "WinGet",
      "Packages",
      "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe",
      "Godot_v4.6.1-stable_win64_console.exe"
    ),
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (candidate && fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return null;
}

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

run(process.execPath, [path.join("scripts", "export-godot-content.mjs")]);
run(godotConsole, [
  "--headless",
  "--path",
  projectDir,
  "--script",
  "res://scripts/tests/run_batch1_tests.gd",
]);
