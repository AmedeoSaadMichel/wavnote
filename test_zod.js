const { z } = require("zod");
const { zodToJsonSchema } = require("zod-to-json-schema");

const ReadNotesArgsSchema = z.object({
    paths: z.array(z.string()),
});

console.log(JSON.stringify(zodToJsonSchema(ReadNotesArgsSchema), null, 2));
