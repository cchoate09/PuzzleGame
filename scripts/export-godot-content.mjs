import fs from "node:fs/promises";
import path from "node:path";

import { buildCampaignIndex } from "../src/content/campaign.js";
import { THREE_LAYER_PROOF_ROOM } from "../src/content/devRooms.js";
import { CANONICAL_SOLUTIONS, THREE_LAYER_PROOF_SOLUTION } from "../src/content/solutions.js";

const outDir = path.resolve("godot/data/generated");

function stableJson(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

async function writeJson(filename, value) {
  const filePath = path.join(outDir, filename);
  await fs.writeFile(filePath, stableJson(value), "utf8");
}

async function main() {
  const campaign = buildCampaignIndex();
  await fs.mkdir(outDir, { recursive: true });

  await writeJson("campaign_index.json", campaign);
  await writeJson("dev_rooms.json", {
    threeLayerProofRoom: THREE_LAYER_PROOF_ROOM,
  });
  await writeJson("solutions.json", {
    canonicalSolutions: CANONICAL_SOLUTIONS,
    threeLayerProofSolution: THREE_LAYER_PROOF_SOLUTION,
  });

  process.stdout.write(`Exported Godot content to ${outDir}\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
