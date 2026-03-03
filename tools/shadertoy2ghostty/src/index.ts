import * as fs from 'fs';
import * as path from 'path';
import type { BlendMode, ConversionOptions, ShadertoyApiResponse } from './types.js';
import { CompatibilityTier } from './types.js';
import { resolveApiKey, parseShaderInput, fetchShader } from './api.js';
import { analyzeShader, convertShader } from './transform.js';

const HELP_TEXT = `
Usage: npx tsx tools/shadertoy2ghostty/src/index.ts [OPTIONS] <SHADER_ID_OR_URL>

Convert a Shadertoy shader to Ghostty-compatible GLSL.

Input (one of):
  <SHADER_ID_OR_URL>       Fetch from Shadertoy API (requires API key)
  -i, --input <FILE>       Read shader GLSL from a local file
  --stdin                  Read shader GLSL from stdin (paste mode)

Options:
  -o, --output <FILE>      Output path (default: <shader-name>.glsl in repo root)
  -k, --api-key <KEY>      API key (or SHADERTOY_API_KEY env var)
  --name <NAME>            Shader name (for local/stdin input, default: filename or "untitled")
  --author <AUTHOR>        Shader author (for local/stdin input, default: "unknown")
  --blend <MODE>           overlay|replace|additive|multiply (default: overlay)
  --no-blend               Same as --blend replace
  --flip-y                 Insert Y-axis flip
  --analyze-only           Print compatibility analysis, don't convert
  --force                  Convert Tier 4 shaders with degradation
  -v, --verbose            Detailed transformation log
  -h, --help               Show help text
`.trim();

interface ParsedArgs {
  output?: string;
  apiKey?: string;
  inputFile?: string;
  useStdin: boolean;
  shaderName?: string;
  shaderAuthor?: string;
  blendMode: BlendMode;
  flipY: boolean;
  analyzeOnly: boolean;
  force: boolean;
  verbose: boolean;
  shaderInput?: string;
}

function parseArgs(argv: string[]): ParsedArgs {
  const args = argv.slice(2); // skip node and script path
  const result: ParsedArgs = {
    useStdin: false,
    blendMode: 'overlay',
    flipY: false,
    analyzeOnly: false,
    force: false,
    verbose: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    switch (arg) {
      case '-h':
      case '--help':
        console.log(HELP_TEXT);
        process.exit(0);

      case '-o':
      case '--output':
        result.output = args[++i];
        if (!result.output) {
          console.error('Error: --output requires a file path argument.');
          process.exit(1);
        }
        break;

      case '-k':
      case '--api-key':
        result.apiKey = args[++i];
        if (!result.apiKey) {
          console.error('Error: --api-key requires a key argument.');
          process.exit(1);
        }
        break;

      case '--blend': {
        const mode = args[++i] as BlendMode;
        const valid: BlendMode[] = ['overlay', 'replace', 'additive', 'multiply'];
        if (!valid.includes(mode)) {
          console.error(`Error: Invalid blend mode "${mode}". Valid modes: ${valid.join(', ')}`);
          process.exit(1);
        }
        result.blendMode = mode;
        break;
      }

      case '--no-blend':
        result.blendMode = 'replace';
        break;

      case '-i':
      case '--input':
        result.inputFile = args[++i];
        if (!result.inputFile) {
          console.error('Error: --input requires a file path argument.');
          process.exit(1);
        }
        break;

      case '--stdin':
        result.useStdin = true;
        break;

      case '--name':
        result.shaderName = args[++i];
        if (!result.shaderName) {
          console.error('Error: --name requires a value.');
          process.exit(1);
        }
        break;

      case '--author':
        result.shaderAuthor = args[++i];
        if (!result.shaderAuthor) {
          console.error('Error: --author requires a value.');
          process.exit(1);
        }
        break;

      case '--flip-y':
        result.flipY = true;
        break;

      case '--analyze-only':
        result.analyzeOnly = true;
        break;

      case '--force':
        result.force = true;
        break;

      case '-v':
      case '--verbose':
        result.verbose = true;
        break;

      default:
        if (arg.startsWith('-')) {
          console.error(`Error: Unknown option "${arg}". Use --help for usage.`);
          process.exit(1);
        }
        result.shaderInput = arg;
        break;
    }
  }

  return result;
}

function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '');
}

function tierLabel(tier: CompatibilityTier): string {
  switch (tier) {
    case CompatibilityTier.FullAuto: return 'Tier 1 (Full Auto)';
    case CompatibilityTier.WithWarnings: return 'Tier 2 (With Warnings)';
    case CompatibilityTier.BufferInlining: return 'Tier 3 (Buffer Inlining)';
    case CompatibilityTier.Unsupported: return 'Tier 4 (Unsupported)';
  }
}

function formatDiagnostics(diagnostics: { severity: string; category: string; message: string }[]): string {
  if (diagnostics.length === 0) return '';
  return diagnostics
    .map((d) => `  [${d.severity.toUpperCase()}] [${d.category}] ${d.message}`)
    .join('\n');
}

function readStdin(): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
    process.stdin.on('error', reject);
  });
}

function wrapRawGlsl(code: string, name: string, author: string): ShadertoyApiResponse {
  return {
    Shader: {
      ver: '0.1',
      info: {
        id: 'local',
        date: '',
        viewed: 0,
        name,
        username: author,
        description: '',
        likes: 0,
        published: 0,
        flags: 0,
        usePreview: 0,
        tags: [],
        hasliked: 0,
      },
      renderpass: [
        {
          inputs: [],
          outputs: [{ id: 0, channel: 0 }],
          code,
          name: 'Image',
          description: '',
          type: 'image',
        },
      ],
    },
  };
}

async function main() {
  const parsed = parseArgs(process.argv);
  const isLocalInput = parsed.inputFile || parsed.useStdin;

  if (!parsed.shaderInput && !isLocalInput) {
    console.error('Error: No shader ID, URL, or input source provided.\n');
    console.error(HELP_TEXT);
    process.exit(1);
  }

  let shaderData: ShadertoyApiResponse;

  if (isLocalInput) {
    // Local input mode: read from file or stdin
    let rawGlsl: string;
    if (parsed.useStdin) {
      if (parsed.verbose) console.error('Reading shader from stdin...');
      rawGlsl = await readStdin();
    } else {
      if (parsed.verbose) console.error(`Reading shader from ${parsed.inputFile}...`);
      if (!fs.existsSync(parsed.inputFile!)) {
        console.error(`Error: File not found: ${parsed.inputFile}`);
        process.exit(1);
      }
      rawGlsl = fs.readFileSync(parsed.inputFile!, 'utf-8');
    }

    if (!rawGlsl.trim()) {
      console.error('Error: Empty shader input.');
      process.exit(1);
    }

    const name = parsed.shaderName
      || (parsed.inputFile ? path.basename(parsed.inputFile, path.extname(parsed.inputFile)) : 'untitled');
    const author = parsed.shaderAuthor || 'unknown';
    shaderData = wrapRawGlsl(rawGlsl, name, author);
  } else {
    // API mode: fetch from Shadertoy
    let apiKey: string;
    try {
      apiKey = resolveApiKey(parsed.apiKey);
    } catch (err) {
      console.error((err as Error).message);
      process.exit(1);
    }

    let shaderId: string;
    try {
      shaderId = parseShaderInput(parsed.shaderInput!);
    } catch (err) {
      console.error((err as Error).message);
      process.exit(1);
    }

    if (parsed.verbose) {
      console.error(`Fetching shader "${shaderId}" from Shadertoy API...`);
    }

    try {
      shaderData = await fetchShader(shaderId, apiKey);
    } catch (err) {
      console.error((err as Error).message);
      process.exit(1);
    }
  }

  // Analyze-only mode
  if (parsed.analyzeOnly) {
    const analysis = analyzeShader(shaderData);
    console.log(`Shader: ${shaderData.Shader.info.name}`);
    console.log(`Author: ${shaderData.Shader.info.username}`);
    console.log(`Compatibility: ${tierLabel(analysis.tier)}`);
    if (analysis.diagnostics.length > 0) {
      console.log(`\nDiagnostics:\n${formatDiagnostics(analysis.diagnostics)}`);
    }
    process.exit(0);
  }

  // Convert shader
  const options: ConversionOptions = {
    blendMode: parsed.blendMode,
    flipY: parsed.flipY,
    force: parsed.force,
    verbose: parsed.verbose,
    analyzeOnly: false,
  };

  const result = convertShader(shaderData, options);

  // Print diagnostics to stderr
  if (result.diagnostics.length > 0) {
    const formatted = formatDiagnostics(result.diagnostics);
    if (formatted) {
      console.error(`\nDiagnostics:\n${formatted}`);
    }
  }

  // Tier 4 without --force: already handled by convertShader returning empty glsl
  if (!result.glsl) {
    console.error(`\nShader is ${tierLabel(result.tier)}. Use --force to attempt conversion anyway.`);
    process.exit(1);
  }

  // Determine output path
  const toolDir = path.dirname(path.dirname(new URL(import.meta.url).pathname));
  const repoRoot = path.resolve(toolDir, '../..');
  const slug = slugify(result.shaderName || 'shader');
  const outputPath = parsed.output || path.join(repoRoot, `${slug}.glsl`);

  // Write output
  const outputDir = path.dirname(outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  fs.writeFileSync(outputPath, result.glsl, 'utf-8');

  console.log(`Converted "${result.shaderName}" by ${result.author} (${tierLabel(result.tier)})`);
  console.log(`Output: ${outputPath}`);
}

main();
