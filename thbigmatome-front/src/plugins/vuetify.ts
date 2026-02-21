// src/plugins/vuetify.ts
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { aliases, mdi } from 'vuetify/iconsets/mdi'
import 'vuetify/styles'
import '@mdi/font/css/materialdesignicons.css'

export default createVuetify({
  components,
  directives,
  icons: {
    defaultSet: 'mdi',
    aliases,
    sets: {
      mdi,
    },
  },
  theme: {
    defaultTheme: 'thbigLight',
    themes: {
      thbigLight: {
        dark: false,
        colors: {
          // 基本カラー（和色）
          primary: '#1B3A6B', // 藍色（あいいろ）
          secondary: '#4A7A8A', // 千草色（ちくさいろ）
          accent: '#C0392B', // 朱色（しゅいろ）
          success: '#5D8A2F', // 萌黄（もえぎ）
          warning: '#D4940A', // 山吹（やまぶき）
          error: '#B01C2A', // 紅（くれない）
          info: '#2E86AB', // 浅葱（あさぎ）

          // 背景・サーフェス
          background: '#F8F6F1', // 和紙色
          surface: '#FFFFFF', // カード背景

          // テキストカラー（Lightモード）
          'text-high': '#1A1A1A', // 本文（高重要）
          'text-medium': '#4A4A4A', // 本文（中重要）
          'text-caption': '#777777', // キャプション
          'text-disabled': '#BBBBBB', // 無効テキスト
        },
      },
      thbigDark: {
        dark: true,
        colors: {
          // 基本カラー（Dark mode、明るく調整）
          primary: '#4A72B8', // 藍を明るく
          secondary: '#6AADBE', // 千草を明るく
          accent: '#E05C4A', // 朱を明るく
          success: '#7BBF4A', // 萌黄を明るく
          warning: '#F0B030', // 山吹を明るく
          error: '#E84040', // 紅を明るく
          info: '#5AACCE', // 浅葱を明るく

          // 背景・サーフェス
          background: '#1A1A2E', // 夜空色
          surface: '#252545', // カード背景

          // テキストカラー（Darkモード）
          'text-high': '#E8E8F2', // 本文（高重要）
          'text-medium': '#B8B8D0', // 本文（中重要）
          'text-caption': '#888888', // キャプション
          'text-disabled': '#555555', // 無効テキスト
        },
      },
    },
  },
  defaults: {
    VDataTable: { density: 'compact', hover: true },
    VBtn: { variant: 'tonal' },
    VCard: { elevation: 1 },
    VTextField: { density: 'compact', variant: 'outlined' },
    VSelect: { density: 'compact', variant: 'outlined' },
  },
})
