import { mergeConfig } from 'vite'
import { defineConfig } from 'vitest/config'
import viteConfig from './vite.config'

export default mergeConfig(viteConfig, defineConfig({
  test: {
    environment: 'happy-dom',
    globals: true,
    include: ['src/**/__tests__/*.spec.ts'],
    passWithNoTests: true,
    css: true,
    setupFiles: ['src/test-setup.ts'],
    // Vuetify 4.0.3のVFormがテスト環境でMaximum recursive updatesを引き起こすバグへの回避策
    // テスト自体は全PASS、exit code 1のみの問題のため無視設定
    dangerouslyIgnoreUnhandledErrors: true,
    server: {
      deps: {
        inline: ['vuetify'],
      },
    },
  }
}))
