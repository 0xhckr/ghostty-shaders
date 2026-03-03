import type {
  ShadertoyRenderPass,
  CompatibilityTier,
  DiagnosticMessage,
  ChannelType,
} from "./types";
import { proceduralNoiseGLSL } from "./templates";

export interface ChannelInfo {
  channel: number; // 0-3
  type: string; // ctype from API
  convertible: boolean;
  action: "keep" | "noise" | "inline" | "zero" | "remap";
}

export interface ChannelAnalysis {
  tier: CompatibilityTier;
  channels: ChannelInfo[];
  diagnostics: DiagnosticMessage[];
}

const UNSUPPORTED_TYPES: Set<string> = new Set([
  "cubemap",
  "volume",
  "video",
  "music",
  "musicstream",
  "mic",
  "webcam",
  "keyboard",
]);

export function analyzeChannels(
  renderpass: ShadertoyRenderPass[]
): ChannelAnalysis {
  const diagnostics: DiagnosticMessage[] = [];
  const channels: ChannelInfo[] = [];

  const imagePass = renderpass.find((p) => p.type === "image");
  if (!imagePass) {
    return { tier: 1 as CompatibilityTier, channels, diagnostics };
  }

  let hasTexture = false;
  let hasBuffer = false;
  let hasUnsupported = false;
  let hasChannel0Conflict = false;

  for (const input of imagePass.inputs) {
    const ch = input.channel;
    const ctype = input.ctype;

    if (ch === 0 && ctype !== "buffer") {
      // iChannel0 should be the terminal texture in Ghostty.
      // If Shadertoy maps it to something else, that's a conflict.
      hasChannel0Conflict = true;
      diagnostics.push({
        severity: "warning",
        category: "channel",
        message: `iChannel0 is mapped to '${ctype}' in Shadertoy but must be the terminal texture in Ghostty. References will be remapped to procedural noise.`,
      });
      channels.push({
        channel: ch,
        type: ctype,
        convertible: ctype === "texture",
        action: ctype === "texture" ? "remap" : "zero",
      });
      if (ctype === "texture") {
        hasTexture = true;
      } else if (UNSUPPORTED_TYPES.has(ctype)) {
        hasUnsupported = true;
      }
      continue;
    }

    if (ctype === "buffer") {
      hasBuffer = true;
      channels.push({
        channel: ch,
        type: ctype,
        convertible: true,
        action: "inline",
      });
      diagnostics.push({
        severity: "info",
        category: "channel",
        message: `iChannel${ch} references a buffer pass (handled by passes.ts).`,
      });
    } else if (ctype === "texture") {
      hasTexture = true;
      channels.push({
        channel: ch,
        type: ctype,
        convertible: true,
        action: "noise",
      });
      diagnostics.push({
        severity: "info",
        category: "channel",
        message: `iChannel${ch} texture will be replaced with procedural noise.`,
      });
    } else if (UNSUPPORTED_TYPES.has(ctype)) {
      hasUnsupported = true;
      channels.push({
        channel: ch,
        type: ctype,
        convertible: false,
        action: "zero",
      });
      diagnostics.push({
        severity: "warning",
        category: "channel",
        message: `iChannel${ch} uses unsupported type '${ctype}'. References will be replaced with vec4(0.0).`,
      });
    } else if (ch === 0) {
      // iChannel0 with no special mapping — keep as terminal
      channels.push({
        channel: ch,
        type: "terminal",
        convertible: true,
        action: "keep",
      });
    }
  }

  // Determine tier
  let tier: CompatibilityTier;
  if (hasUnsupported) {
    tier = 4 as CompatibilityTier;
  } else if (hasBuffer) {
    tier = 3 as CompatibilityTier;
  } else if (hasTexture || hasChannel0Conflict) {
    tier = 2 as CompatibilityTier;
  } else {
    tier = 1 as CompatibilityTier;
  }

  return { tier, channels, diagnostics };
}

export function replaceChannelTextures(
  source: string,
  channels: ChannelInfo[]
): { code: string; needsNoise: boolean } {
  let code = source;
  let needsNoise = false;

  for (const ch of channels) {
    if (ch.action === "noise" || ch.action === "remap") {
      // Replace texture(iChannelN, ...) with proceduralNoise(...)
      const pattern = new RegExp(
        `texture\\s*\\(\\s*iChannel${ch.channel}\\s*,\\s*([^)]+)\\)`,
        "g"
      );
      code = code.replace(pattern, (_match, uvArg: string) => {
        needsNoise = true;
        return `proceduralNoise(${uvArg.trim()})`;
      });

      // Also handle texelFetch(iChannelN, ...) → proceduralNoise with normalized coords
      const fetchPattern = new RegExp(
        `texelFetch\\s*\\(\\s*iChannel${ch.channel}\\s*,\\s*([^,]+),\\s*[^)]+\\)`,
        "g"
      );
      code = code.replace(fetchPattern, (_match, coordArg: string) => {
        needsNoise = true;
        return `proceduralNoise(vec2(${coordArg.trim()}) / iResolution.xy)`;
      });
    } else if (ch.action === "zero") {
      // Replace texture(iChannelN, ...) with vec4(0.0)
      const pattern = new RegExp(
        `texture\\s*\\(\\s*iChannel${ch.channel}\\s*,\\s*[^)]+\\)`,
        "g"
      );
      code = code.replace(pattern, "vec4(0.0)");

      const fetchPattern = new RegExp(
        `texelFetch\\s*\\(\\s*iChannel${ch.channel}\\s*,\\s*[^,]+,\\s*[^)]+\\)`,
        "g"
      );
      code = code.replace(fetchPattern, "vec4(0.0)");
    }
    // 'keep' and 'inline' channels are left untouched
  }

  return { code, needsNoise };
}
