import { z } from "file:///Users/amedeosaadmichel/.nvm/versions/node/v22.20.0/lib/node_modules/mcp-obsidian/node_modules/zod/lib/index.mjs";
import { zodToJsonSchema } from "file:///Users/amedeosaadmichel/.nvm/versions/node/v22.20.0/lib/node_modules/mcp-obsidian/node_modules/zod-to-json-schema/dist/esm/index.js";

const ReadNotesArgsSchema = z.object({
    paths: z.array(z.string()),
});

console.log(JSON.stringify(zodToJsonSchema(ReadNotesArgsSchema), null, 2));
