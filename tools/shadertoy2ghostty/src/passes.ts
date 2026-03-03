import type { ShadertoyRenderPass, DiagnosticMessage } from "./types";

// --- Types ---

export interface PassNode {
  name: string; // "Image", "Buffer A", etc.
  type: string; // "image", "buffer", "common", "sound"
  code: string;
  inputs: { channel: number; readsFrom: string | null }[]; // null = external texture
}

export interface PassGraph {
  nodes: PassNode[];
  hasFeedbackLoop: boolean;
  feedbackDetails: string[]; // which buffers have self-reference
  commonCode: string | null; // "Common" tab code if present
}

// --- Helpers ---

/** Map a Shadertoy buffer output ID to a canonical buffer name. */
function bufferNameFromOutputId(
  outputId: number,
  passes: ShadertoyRenderPass[]
): string | null {
  for (const pass of passes) {
    if (pass.type !== "buffer") continue;
    for (const out of pass.outputs) {
      if (out.id === outputId) return pass.name;
    }
  }
  return null;
}

/** Derive a safe function suffix from a pass name, e.g. "Buf A" → "A". */
function bufferSuffix(name: string): string {
  const m = name.match(/[A-D]$/);
  return m ? m[0] : name.replace(/[^a-zA-Z0-9]/g, "");
}

// --- 1. Build dependency graph ---

export function buildPassGraph(
  renderpasses: ShadertoyRenderPass[]
): PassGraph {
  const feedbackDetails: string[] = [];
  let commonCode: string | null = null;

  const nodes: PassNode[] = [];

  for (const pass of renderpasses) {
    if (pass.type === "common") {
      commonCode = pass.code;
      continue;
    }

    // Skip sound / cubemap passes — we only care about image and buffer
    if (pass.type !== "image" && pass.type !== "buffer") continue;

    const inputs: PassNode["inputs"] = [];

    for (const inp of pass.inputs) {
      if (inp.ctype === "buffer") {
        const readsFrom = bufferNameFromOutputId(inp.id, renderpasses);
        inputs.push({ channel: inp.channel, readsFrom });

        // Feedback detection: buffer reads its own output
        if (readsFrom === pass.name) {
          feedbackDetails.push(
            `${pass.name} reads its own output via iChannel${inp.channel}`
          );
        }
      } else {
        inputs.push({ channel: inp.channel, readsFrom: null });
      }
    }

    nodes.push({
      name: pass.name,
      type: pass.type,
      code: pass.code,
      inputs,
    });
  }

  return {
    nodes,
    hasFeedbackLoop: feedbackDetails.length > 0,
    feedbackDetails,
    commonCode,
  };
}

// --- 2. Topological sort ---

export function sortPasses(graph: PassGraph): PassNode[] | null {
  const bufferNodes = graph.nodes.filter((n) => n.type === "buffer");
  const imageNodes = graph.nodes.filter((n) => n.type === "image");

  // Build adjacency: edge from dependency → dependent
  const inDegree = new Map<string, number>();
  const adj = new Map<string, string[]>();

  for (const node of bufferNodes) {
    inDegree.set(node.name, 0);
    adj.set(node.name, []);
  }

  for (const node of bufferNodes) {
    for (const inp of node.inputs) {
      if (inp.readsFrom && inp.readsFrom !== node.name) {
        // inp.readsFrom must come before node
        if (!adj.has(inp.readsFrom)) continue; // external, skip
        adj.get(inp.readsFrom)!.push(node.name);
        inDegree.set(node.name, (inDegree.get(node.name) ?? 0) + 1);
      }
    }
  }

  // Kahn's algorithm
  const queue: string[] = [];
  for (const [name, deg] of inDegree) {
    if (deg === 0) queue.push(name);
  }

  const sorted: PassNode[] = [];
  const nodeMap = new Map(bufferNodes.map((n) => [n.name, n]));

  while (queue.length > 0) {
    const name = queue.shift()!;
    sorted.push(nodeMap.get(name)!);
    for (const dep of adj.get(name) ?? []) {
      const newDeg = (inDegree.get(dep) ?? 1) - 1;
      inDegree.set(dep, newDeg);
      if (newDeg === 0) queue.push(dep);
    }
  }

  if (sorted.length !== bufferNodes.length) {
    return null; // cycle detected
  }

  // Append image passes at the end (they consume buffers)
  return [...sorted, ...imageNodes];
}

// --- 3. Inline buffers ---

export function inlineBuffers(
  imageCode: string,
  buffers: PassNode[],
  graph: PassGraph
): { code: string; diagnostics: DiagnosticMessage[] } {
  const diagnostics: DiagnosticMessage[] = [];
  const renamedFunctions: string[] = [];

  // Process each buffer: rename mainImage → _bufferX
  for (const buf of buffers) {
    const suffix = bufferSuffix(buf.name);
    const funcName = `_buffer${suffix}`;

    // Rename mainImage in the buffer code
    const renamed = buf.code.replace(
      /void\s+mainImage\s*\(\s*out\s+vec4\s+(\w+)\s*,\s*in\s+vec2\s+(\w+)\s*\)/,
      `void ${funcName}(out vec4 $1, in vec2 $2)`
    );

    renamedFunctions.push(renamed);

    diagnostics.push({
      severity: "warning",
      category: "pass",
      message: `Buffer "${buf.name}" inlined as ${funcName}(). Each texture() sample becomes a full function call — no caching between pixels. This may be significantly slower than the original multi-pass version.`,
    });
  }

  // Build a map: buffer name → function name
  const bufferFuncMap = new Map<string, string>();
  for (const buf of buffers) {
    const suffix = bufferSuffix(buf.name);
    bufferFuncMap.set(buf.name, `_buffer${suffix}`);
  }

  // Replace texture(iChannelN, uv) calls that reference buffers
  let result = imageCode;
  for (const node of [...buffers, ...graph.nodes.filter((n) => n.type === "image")]) {
    for (const inp of node.inputs) {
      if (inp.readsFrom === null) continue;
      const funcName = bufferFuncMap.get(inp.readsFrom);
      if (!funcName) continue;

      const resultVar = `${funcName}_result`;

      // Replace in the appropriate code
      if (node.type === "image") {
        // Replace in image code (result variable)
        const pattern = new RegExp(
          `texture\\s*\\(\\s*iChannel${inp.channel}\\s*,\\s*([^)]+)\\)`,
          "g"
        );
        let callIndex = 0;
        result = result.replace(pattern, (_match, uvArg: string) => {
          const varName = callIndex === 0 ? resultVar : `${resultVar}_${callIndex}`;
          callIndex++;
          return `(${varName})`;
        });

        // We need to prepend the call declarations before mainImage
        // We'll handle this after all replacements
      }
    }
  }

  // Also handle buffer-to-buffer references in the renamed functions
  for (let i = 0; i < renamedFunctions.length; i++) {
    const buf = buffers[i];
    for (const inp of buf.inputs) {
      if (inp.readsFrom === null || inp.readsFrom === buf.name) continue;
      const funcName = bufferFuncMap.get(inp.readsFrom);
      if (!funcName) continue;

      const resultVar = `${funcName}_result`;
      const pattern = new RegExp(
        `texture\\s*\\(\\s*iChannel${inp.channel}\\s*,\\s*([^)]+)\\)`,
        "g"
      );
      let callIndex = 0;
      renamedFunctions[i] = renamedFunctions[i].replace(
        pattern,
        (_match, uvArg: string) => {
          const varName = callIndex === 0 ? resultVar : `${resultVar}_${callIndex}`;
          callIndex++;
          return `(${varName})`;
        }
      );
    }
  }

  // Now inject buffer call declarations before mainImage in the image pass
  // Find where mainImage starts and inject calls
  const callDeclarations: string[] = [];
  for (const node of graph.nodes.filter((n) => n.type === "image")) {
    for (const inp of node.inputs) {
      if (inp.readsFrom === null) continue;
      const funcName = bufferFuncMap.get(inp.readsFrom);
      if (!funcName) continue;
      const resultVar = `${funcName}_result`;
      callDeclarations.push(
        `  vec4 ${resultVar}; ${funcName}(${resultVar}, fragCoord); // was texture(iChannel${inp.channel}, uv)`
      );
    }
  }

  // Inject call declarations at the start of mainImage body
  if (callDeclarations.length > 0) {
    result = result.replace(
      /(void\s+mainImage\s*\([^)]*\)\s*\{)/,
      `$1\n${callDeclarations.join("\n")}\n`
    );
  }

  // Also inject buffer-to-buffer call declarations in renamed functions
  for (let i = 0; i < renamedFunctions.length; i++) {
    const buf = buffers[i];
    const bufCallDecls: string[] = [];
    for (const inp of buf.inputs) {
      if (inp.readsFrom === null || inp.readsFrom === buf.name) continue;
      const funcName = bufferFuncMap.get(inp.readsFrom);
      if (!funcName) continue;
      const resultVar = `${funcName}_result`;
      bufCallDecls.push(
        `  vec4 ${resultVar}; ${funcName}(${resultVar}, fragCoord); // was texture(iChannel${inp.channel}, uv)`
      );
    }
    if (bufCallDecls.length > 0) {
      const suffix = bufferSuffix(buf.name);
      const myFuncName = `_buffer${suffix}`;
      renamedFunctions[i] = renamedFunctions[i].replace(
        new RegExp(`(void\\s+${myFuncName}\\s*\\([^)]*\\)\\s*\\{)`),
        `$1\n${bufCallDecls.join("\n")}\n`
      );
    }
  }

  // Assemble final code: buffer functions + image code
  const assembled = [...renamedFunctions, result].join("\n\n");

  return { code: assembled, diagnostics };
}
