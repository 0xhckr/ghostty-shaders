import type { DiagnosticMessage } from './types.js';

// iMouse shim: wraps Ghostty's vec2 iMouse into a vec4 for Shadertoy compatibility
const IMOUSE_SHIM = `
// Shadertoy iMouse compatibility shim (Ghostty provides vec2)
#ifdef GHOSTTY_SHIM_IMOUSE
// already shimmed
#else
#define GHOSTTY_SHIM_IMOUSE
vec4 iMouse_st = vec4(iMouse, 0.0, 0.0);
#define iMouse iMouse_st
#endif
`.trimStart();

interface UniformStub {
  /** Regex to detect usage in source */
  pattern: RegExp;
  /** GLSL declaration to inject */
  glsl: string;
  /** Diagnostic message describing the stub */
  message: string;
}

const UNIFORM_STUBS: UniformStub[] = [
  {
    pattern: /\biTimeDelta\b/,
    glsl: 'float iTimeDelta = 0.016;',
    message: 'Stubbed iTimeDelta as 0.016 (~60fps)',
  },
  {
    pattern: /\biFrameRate\b/,
    glsl: 'float iFrameRate = 60.0;',
    message: 'Stubbed iFrameRate as 60.0',
  },
  {
    pattern: /\biDate\b/,
    glsl: 'vec4 iDate = vec4(2024.0, 0.0, 0.0, iTime);',
    message: 'Stubbed iDate with approximate values',
  },
  {
    pattern: /\biSampleRate\b/,
    glsl: 'float iSampleRate = 44100.0;',
    message: 'Stubbed iSampleRate as 44100.0',
  },
  {
    pattern: /\biChannelTime\b/,
    glsl: 'float iChannelTime[4] = float[4](iTime, iTime, iTime, iTime);',
    message: 'Stubbed iChannelTime[4] using iTime',
  },
  {
    pattern: /\biChannelResolution\b/,
    glsl: 'vec3 iChannelResolution[4] = vec3[4](iResolution, iResolution, iResolution, iResolution);',
    message: 'Stubbed iChannelResolution[4] using iResolution',
  },
  {
    pattern: /\biFrame\b/,
    glsl: 'int iFrame = int(iTime * 60.0);',
    message: 'Stubbed iFrame as int(iTime * 60.0)',
  },
];

/**
 * Checks whether iMouse is used as a vec4 (with .z, .w, .zw, or swizzles beyond xy).
 */
function needsMouseShim(source: string): boolean {
  // Matches iMouse.z, iMouse.w, iMouse.zw, iMouse.xyzw, etc.
  if (/\biMouse\s*\.\s*[zwZW]/.test(source)) return true;
  // Matches swizzles that include z or w: e.g. iMouse.xyz, iMouse.xyzw
  if (/\biMouse\s*\.\s*[xyzw]*[zw][xyzw]*\b/.test(source)) return true;
  // Check for vec4(iMouse) or vec4 cast
  if (/vec4\s*\(\s*iMouse\b/.test(source)) return true;
  return false;
}

/**
 * Scans shader source for Shadertoy uniforms not available in Ghostty
 * and injects compatibility stubs for any that are referenced.
 */
export function stubMissingUniforms(source: string): { code: string; diagnostics: DiagnosticMessage[] } {
  const diagnostics: DiagnosticMessage[] = [];
  const stubs: string[] = [];

  // Check for iMouse vec4 usage
  if (/\biMouse\b/.test(source) && needsMouseShim(source)) {
    stubs.push(IMOUSE_SHIM);
    diagnostics.push({
      severity: 'warning',
      category: 'uniform',
      message: 'Injected iMouse vec4 shim (Ghostty provides vec2)',
    });
  }

  // Check each uniform stub
  for (const stub of UNIFORM_STUBS) {
    if (stub.pattern.test(source)) {
      stubs.push(stub.glsl);
      diagnostics.push({
        severity: 'info',
        category: 'uniform',
        message: stub.message,
      });
    }
  }

  if (stubs.length === 0) {
    return { code: source, diagnostics };
  }

  const stubBlock = '// --- Shadertoy uniform stubs (Ghostty compatibility) ---\n'
    + stubs.join('\n')
    + '\n// --- End uniform stubs ---\n\n';

  return { code: stubBlock + source, diagnostics };
}

/**
 * Replaces `gl_FragCoord` with `fragCoord` throughout the source.
 * Some Shadertoy shaders use the raw builtin instead of the mainImage parameter.
 */
export function replaceFragCoord(source: string): { code: string; replaced: boolean } {
  const replaced = /\bgl_FragCoord\b/.test(source);
  const code = source.replace(/\bgl_FragCoord\b/g, 'fragCoord');
  return { code, replaced };
}

/**
 * Inserts a Y-axis flip as the first line inside mainImage's body.
 * This accounts for the coordinate system difference between Shadertoy and Ghostty.
 */
export function injectFlipY(source: string): string {
  // Match "void mainImage(...) {" and insert the flip after the opening brace
  const mainImagePattern = /(void\s+mainImage\s*\([^)]*\)\s*\{)/;
  const match = source.match(mainImagePattern);

  if (!match) {
    return source;
  }

  return source.replace(
    mainImagePattern,
    '$1\n    fragCoord.y = iResolution.y - fragCoord.y;',
  );
}
