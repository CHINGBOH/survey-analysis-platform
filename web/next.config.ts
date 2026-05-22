import type { NextConfig } from "next";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "http://127.0.0.1:8765";

const nextConfig: NextConfig = {
  async rewrites() {
    return [
      // 把 /api/* 反代到 FastAPI,前端无需关心 CORS / 端口
      { source: "/api/:path*", destination: `${API_BASE}/api/:path*` },
      { source: "/static/:path*", destination: `${API_BASE}/static/:path*` },
    ];
  },
};

export default nextConfig;
