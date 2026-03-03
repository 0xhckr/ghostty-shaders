import type {
  ShadertoyApiResponse,
  ConversionOptions,
  ConversionResult,
  CompatibilityTier,
  DiagnosticMessage,
} from './types.js';
import { analyzeChannels, replaceChannelTextures } from './channels.js';
import { buildPassGraph, sortPasses, inlineBuffers } from './passes.js';
import { attributionHeader, proceduralNoiseGLSL, blendingCode } from './templates.js';
import { stubMissingUniforms, replaceFragCoord, injectFlipY } from './uniforms.js';
import { CompatibilityTier as Tier } from './types.js';

/**
 * Analyze a Shadertoy shader for Ghostty compatibility without converting it.
 */
export function analyzeShader(
  shader: ShadertoyApiResponse,
): { tier: CompatibilityTier; diagnostics: DiagnosticMessage[] } {
  const renderpasses = shader.Shader.renderpass;
  const channelAnalysis = analyzeChannels(renderpasses);
  const passGraph = buildPassGraph(renderpasses);

  const diagnostics = [...channelAnalysis.diagnostics];

  if (passGraph.hasFeedbackLoop) {
    diagnostics.push({
      severity: 'warning',
      category: 'pass',
      message: `Feedback loops detected: ${passGraph.feedbackDetails.join('; ')}. Inlined buffers will not have frame-to-frame persistence.`,
    });
  }

  // Pass graph can push tier up to 3 if buffers exist but channels didn't detect them
  let tier = channelAnalysis.tier;
  const hasBufferPasses = passGraph.nodes.some((n) => n.type === 'buffer');
  if (hasBufferPasses && tier < Tier.BufferInlining) {
    tier = Tier.BufferInlining;
  }

  return { tier, diagnostics };
}

/**
 * Convert a Shadertoy shader to Ghostty-compatible GLSL.
 */
export function convertShader(
  shader: ShadertoyApiResponse,
  options: ConversionOptions,
): ConversionResult {
  const info = shader.Shader.info;
  const renderpasses = shader.Shader.renderpass;
  const allDiagnostics: DiagnosticMessage[] = [];

  // 1. Extract shader info
  const shaderName = info.name;
  const author = info.username;
  const shaderId = info.id;

  // 2. Analyze compatibility
  const channelAnalysis = analyzeChannels(renderpasses);
  const passGraph = buildPassGraph(renderpasses);
  allDiagnostics.push(...channelAnalysis.diagnostics);

  if (passGraph.hasFeedbackLoop) {
    allDiagnostics.push({
      severity: 'warning',
      category: 'pass',
      message: `Feedback loops detected: ${passGraph.feedbackDetails.join('; ')}. Inlined buffers will not have frame-to-frame persistence.`,
    });
  }

  let tier = channelAnalysis.tier;
  const hasBufferPasses = passGraph.nodes.some((n) => n.type === 'buffer');
  if (hasBufferPasses && tier < Tier.BufferInlining) {
    tier = Tier.BufferInlining;
  }

  // If Tier 4 (unsupported) and not forced, return early
  if (tier === Tier.Unsupported && !options.force) {
    allDiagnostics.push({
      severity: 'error',
      category: 'general',
      message: 'Shader uses unsupported features (Tier 4). Use --force to attempt conversion anyway.',
    });
    return {
      glsl: '',
      tier,
      diagnostics: allDiagnostics,
      shaderName,
      author,
    };
  }

  // 3. Extract code parts
  const imagePass = renderpasses.find((p) => p.type === 'image');
  if (!imagePass) {
    allDiagnostics.push({
      severity: 'error',
      category: 'general',
      message: 'No "image" renderpass found in shader.',
    });
    return {
      glsl: '',
      tier,
      diagnostics: allDiagnostics,
      shaderName,
      author,
    };
  }

  let mainCode = imagePass.code;
  const commonCode = passGraph.commonCode;
  const bufferNodes = passGraph.nodes.filter((n) => n.type === 'buffer');

  // 4. Inline buffer passes (Tier 3)
  let inlinedBufferCode = '';
  if (bufferNodes.length > 0) {
    const sorted = sortPasses(passGraph);
    if (sorted === null) {
      allDiagnostics.push({
        severity: 'error',
        category: 'pass',
        message: 'Cyclic dependency detected among buffer passes. Cannot inline.',
      });
      return {
        glsl: '',
        tier,
        diagnostics: allDiagnostics,
        shaderName,
        author,
      };
    }

    const sortedBuffers = sorted.filter((n) => n.type === 'buffer');
    const inlineResult = inlineBuffers(mainCode, sortedBuffers, passGraph);
    mainCode = inlineResult.code;
    allDiagnostics.push(...inlineResult.diagnostics);
  }

  // 5. Replace channel textures
  const channelResult = replaceChannelTextures(mainCode, channelAnalysis.channels);
  mainCode = channelResult.code;
  let needsNoise = channelResult.needsNoise;

  // 6. Stub missing uniforms
  const uniformResult = stubMissingUniforms(mainCode);
  mainCode = uniformResult.code;
  allDiagnostics.push(...uniformResult.diagnostics);

  // 7. Replace gl_FragCoord
  const fragCoordResult = replaceFragCoord(mainCode);
  mainCode = fragCoordResult.code;
  if (fragCoordResult.replaced) {
    allDiagnostics.push({
      severity: 'info',
      category: 'general',
      message: 'Replaced gl_FragCoord with fragCoord.',
    });
  }

  // 8. Y-axis flip
  if (options.flipY) {
    mainCode = injectFlipY(mainCode);
    allDiagnostics.push({
      severity: 'info',
      category: 'general',
      message: 'Injected Y-axis flip.',
    });
  }

  // 9. Inject terminal blending
  if (options.blendMode !== 'replace') {
    const blend = blendingCode(options.blendMode);
    if (blend) {
      // Inject blending code before the closing brace of mainImage
      const lastBrace = mainCode.lastIndexOf('}');
      if (lastBrace !== -1) {
        mainCode = mainCode.slice(0, lastBrace) + blend + '\n' + mainCode.slice(lastBrace);
      }
      allDiagnostics.push({
        severity: 'info',
        category: 'general',
        message: `Injected terminal blending (${options.blendMode} mode).`,
      });
    }
  }

  // 10. Build final output
  const parts: string[] = [];

  // Attribution header
  parts.push(attributionHeader(shaderName, author, shaderId));
  parts.push('');

  // Procedural noise (if needed)
  if (needsNoise) {
    parts.push(proceduralNoiseGLSL());
  }

  // Common code (if any)
  if (commonCode) {
    parts.push('// --- Common code ---');
    parts.push(commonCode);
    parts.push('// --- End common code ---');
    parts.push('');
  }

  // Main shader code (includes inlined buffer functions if any, uniform stubs, etc.)
  parts.push(mainCode);

  return {
    glsl: parts.join('\n'),
    tier,
    diagnostics: allDiagnostics,
    shaderName,
    author,
  };
}
