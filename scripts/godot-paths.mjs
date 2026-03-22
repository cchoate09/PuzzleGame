import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

function existingFile(candidate) {
  return candidate && fs.existsSync(candidate) ? candidate : null;
}

function pathCandidates(filename) {
  return (process.env.PATH || "")
    .split(path.delimiter)
    .map((segment) => path.join(segment, filename))
    .filter((candidate) => fs.existsSync(candidate));
}

function wingetCandidates() {
  const packagesRoot = path.join(process.env.LOCALAPPDATA || "", "Microsoft", "WinGet", "Packages");
  if (!fs.existsSync(packagesRoot)) {
    return [];
  }

  const packageDirs = fs
    .readdirSync(packagesRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && entry.name.startsWith("GodotEngine.GodotEngine"))
    .map((entry) => path.join(packagesRoot, entry.name));

  const matches = [];
  for (const packageDir of packageDirs) {
    for (const filename of fs.readdirSync(packageDir)) {
      if (/^Godot_v.*_console\.exe$/i.test(filename)) {
        matches.push(path.join(packageDir, filename));
      }
    }
  }

  return matches.sort().reverse();
}

export function findGodotConsole() {
  const directCandidates = [
    process.env.GODOT_CONSOLE_PATH,
    ...pathCandidates("godot_console.exe"),
    ...pathCandidates("godot.exe"),
    ...wingetCandidates(),
  ];

  for (const candidate of directCandidates) {
    const resolved = existingFile(candidate);
    if (resolved) {
      return resolved;
    }
  }

  return null;
}

export function getInstalledGodotVersion(godotConsole) {
  const result = spawnSync(godotConsole, ["--version"], {
    encoding: "utf8",
    shell: false,
  });

  if (result.error || result.status !== 0) {
    return null;
  }

  const match = result.stdout.match(/(\d+\.\d+\.\d+\.stable)/);
  return match ? match[1] : null;
}

export function getGodotTemplatesDir(version) {
  return path.join(process.env.APPDATA || "", "Godot", "export_templates", version);
}
