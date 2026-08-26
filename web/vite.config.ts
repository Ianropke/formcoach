import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { VitePWA } from 'vite-plugin-pwa';

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'pwa-192x192.png', 'pwa-512x512.png', 'icon.svg'],
      workbox: {
        maximumFileSizeToCacheInBytes: 25 * 1024 * 1024, // 25MB for on-device WASM and ML model caching
        globPatterns: ['**/*.{js,css,html,ico,png,svg,wasm,task}']
      },
      manifest: {
        name: 'FormCoach — Local-First Biomechanics',
        short_name: 'FormCoach',
        description: 'On-device strength-training form analysis & fatigue tracking',
        theme_color: '#000000',
        background_color: '#000000',
        display: 'standalone',
        orientation: 'portrait',
        icons: [
          {
            src: 'pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: 'pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      }
    })
  ],
  server: {
    host: '0.0.0.0',
    port: 3000
  }
});
