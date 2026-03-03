// Shadertoy API Response Types

export interface ShadertoyInputSampler {
  filter: string;
  wrap: string;
  vflip: string;
  srgb: string;
  internal: string;
}

export type ChannelType =
  | 'texture'
  | 'cubemap'
  | 'volume'
  | 'video'
  | 'music'
  | 'musicstream'
  | 'mic'
  | 'webcam'
  | 'keyboard'
  | 'buffer';

export interface ShadertoyInput {
  id: number;
  src: string;
  ctype: ChannelType;
  channel: number;
  sampler: ShadertoyInputSampler;
  published: number;
}

export interface ShadertoyOutput {
  id: number;
  channel: number;
}

export type RenderPassType = 'image' | 'buffer' | 'common' | 'sound' | 'cubemap';

export interface ShadertoyRenderPass {
  inputs: ShadertoyInput[];
  outputs: ShadertoyOutput[];
  code: string;
  name: string;
  description: string;
  type: RenderPassType;
}

export interface ShadertoyInfo {
  id: string;
  date: string;
  viewed: number;
  name: string;
  username: string;
  description: string;
  likes: number;
  published: number;
  flags: number;
  usePreview: number;
  tags: string[];
  hasliked: number;
}

export interface ShadertoyShader {
  ver: string;
  info: ShadertoyInfo;
  renderpass: ShadertoyRenderPass[];
}

export interface ShadertoyApiResponse {
  Shader: ShadertoyShader;
}

// Internal Types

export enum CompatibilityTier {
  FullAuto = 1,
  WithWarnings = 2,
  BufferInlining = 3,
  Unsupported = 4,
}

export type BlendMode = 'overlay' | 'replace' | 'additive' | 'multiply';

export interface ConversionOptions {
  blendMode: BlendMode;
  flipY: boolean;
  force: boolean;
  verbose: boolean;
  analyzeOnly: boolean;
}

export interface DiagnosticMessage {
  severity: 'info' | 'warning' | 'error';
  category: 'uniform' | 'channel' | 'pass' | 'general';
  message: string;
}

export interface ConversionResult {
  glsl: string;
  tier: CompatibilityTier;
  diagnostics: DiagnosticMessage[];
  shaderName: string;
  author: string;
}
