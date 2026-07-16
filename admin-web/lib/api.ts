export type ApiHealth = {
  status: string;
  service: string;
  version: string;
  timestamp: string;
};

function isApiHealth(value: unknown): value is ApiHealth {
  if (typeof value !== 'object' || value === null) return false;

  const health = value as Record<string, unknown>;
  return (
    typeof health.status === 'string' &&
    typeof health.service === 'string' &&
    typeof health.version === 'string' &&
    typeof health.timestamp === 'string'
  );
}

export async function getApiHealth(): Promise<ApiHealth | null> {
  const baseUrl = process.env.API_INTERNAL_URL ?? process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8080';
  try {
    const response = await fetch(`${baseUrl}/api/v1/public/health`, { cache: 'no-store' });
    if (!response.ok) return null;
    const payload: unknown = await response.json();
    return isApiHealth(payload) ? payload : null;
  } catch {
    return null;
  }
}
