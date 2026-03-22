import fs from "node:fs";
import { findGodotConsole, getGodotTemplatesDir, getInstalledGodotVersion } from "./godot-paths.mjs";

const godotConsole = findGodotConsole();
if (!godotConsole) {
  process.stderr.write("Godot console executable not found.\n");
  process.exit(1);
}

const version = getInstalledGodotVersion(godotConsole);
if (!version) {
  process.stderr.write(`Unable to determine installed Godot version from ${godotConsole}.\n`);
  process.exit(1);
}

const templatesDir = getGodotTemplatesDir(version);
const requiredFiles = [
  "windows_release_x86_64.exe",
  "windows_debug_x86_64.exe",
];

const missing = requiredFiles.filter((filename) => !fs.existsSync(`${templatesDir}/${filename}`));
if (missing.length) {
  process.stderr.write(`Missing export templates for ${version} in ${templatesDir}: ${missing.join(", ")}\n`);
  process.exit(1);
}

process.stdout.write(`Godot setup verified.\nExecutable: ${godotConsole}\nTemplates: ${templatesDir}\n`);
