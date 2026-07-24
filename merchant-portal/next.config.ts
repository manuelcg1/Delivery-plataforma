import type { NextConfig } from 'next';
const backend = process.env.API_INTERNAL_URL ?? 'http://localhost:8080';
const config: NextConfig = {
  output: 'standalone',
  outputFileTracingRoot: process.cwd(),
  async rewrites() {
    return [{ source: '/backend/:path*', destination: `${backend}/:path*` }];
  }
};
export default config;
