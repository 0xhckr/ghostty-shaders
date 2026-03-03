import type { ShadertoyApiResponse } from "./types";

/**
 * Extract a shader ID from either a raw ID or a full Shadertoy URL.
 * Accepts:
 *   - "XsXXDn"
 *   - "https://www.shadertoy.com/view/XsXXDn"
 */
export function parseShaderInput(input: string): string {
  const trimmed = input.trim();

  // Match Shadertoy URL pattern
  const urlMatch = trimmed.match(
    /^https?:\/\/(?:www\.)?shadertoy\.com\/view\/([A-Za-z0-9]+)/
  );
  if (urlMatch) {
    return urlMatch[1];
  }

  // If it looks like a bare ID (alphanumeric, typically 6 chars)
  if (/^[A-Za-z0-9]+$/.test(trimmed)) {
    return trimmed;
  }

  throw new Error(
    `Invalid shader input: "${input}". Provide a shader ID (e.g. XsXXDn) or a Shadertoy URL.`
  );
}

/**
 * Resolve the Shadertoy API key from CLI argument or environment variable.
 * CLI argument takes precedence over the environment variable.
 */
export function resolveApiKey(cliKey?: string): string {
  if (cliKey) {
    return cliKey;
  }

  const envKey = process.env.SHADERTOY_API_KEY;
  if (envKey) {
    return envKey;
  }

  throw new Error(
    "No Shadertoy API key provided. " +
      "Pass --api-key <key> or set the SHADERTOY_API_KEY environment variable. " +
      "You can get an API key at https://www.shadertoy.com/myapps"
  );
}

/**
 * Fetch shader data from the Shadertoy REST API.
 */
export async function fetchShader(
  shaderId: string,
  apiKey: string
): Promise<ShadertoyApiResponse> {
  const url = `https://www.shadertoy.com/api/v1/shaders/${encodeURIComponent(shaderId)}?key=${encodeURIComponent(apiKey)}`;

  let response: Response;
  try {
    response = await fetch(url);
  } catch (err) {
    throw new Error(
      `Network error fetching shader "${shaderId}": ${err instanceof Error ? err.message : String(err)}`
    );
  }

  if (!response.ok) {
    throw new Error(
      `Shadertoy API returned HTTP ${response.status} for shader "${shaderId}"`
    );
  }

  const data = await response.json();

  // The API returns { "Error": "..." } on failure instead of an HTTP error code
  if (data.Error) {
    const errorMsg: string = data.Error;

    if (/key/i.test(errorMsg)) {
      throw new Error(
        `Invalid Shadertoy API key: ${errorMsg}. Check your key at https://www.shadertoy.com/myapps`
      );
    }

    if (/not found/i.test(errorMsg)) {
      throw new Error(
        `Shader "${shaderId}" not found. Check the shader ID or URL and try again.`
      );
    }

    throw new Error(`Shadertoy API error: ${errorMsg}`);
  }

  return data as ShadertoyApiResponse;
}
