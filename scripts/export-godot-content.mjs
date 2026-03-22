import { syncContent } from "./sync-content.mjs";

syncContent().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
