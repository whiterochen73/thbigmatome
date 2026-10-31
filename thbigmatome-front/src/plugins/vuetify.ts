// src/plugins/vuetify.ts
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { aliases, mdi } from 'vuetify/iconsets/mdi'
import { ja, en } from 'vuetify/locale'
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
  locale: {
    locale: 'ja',
    fallback: 'en',
    messages: { ja, en },
  },
  theme: {
    defaultTheme: 'light',
    themes: {
      light: {
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
          'on-surface': '#1A1A1A',
          'surface-variant': '#F1EEE6',
          'on-surface-variant': '#4A4A4A',
          link: '#1B3A6B',
          'border-strong': '#857F70',
          'danger-ink': '#8a1420',

          // テキストカラー（Lightモード）
          'text-high': '#1A1A1A', // 本文（高重要）
          'text-medium': '#4A4A4A', // 本文（中重要）
          'text-caption': '#666666', // キャプション
          'text-disabled': '#BBBBBB', // 無効テキスト

          // ゲーム固有色
          'game-home': '#1B3A6B',
          'game-visitor': '#46565F',

          'state-done': '#ddefc9',
          'on-state-done': '#2f5a12',
          'state-todo': '#fbebc2',
          'on-state-todo': '#6d4a00',
          'state-edit': '#ffffff',
          'on-state-edit': '#1A1A1A',
          'state-warn': '#f7d9dc',
          'on-state-warn': '#8a1420',
          'state-info': '#d6e9f2',
          'on-state-info': '#12506b',
          'state-neutral': '#eeece7',
          'on-state-neutral': '#4a4a4a',
          'absence-out': '#f6dbe8',
          'on-absence-out': '#8a1c55',
          'absence-adjust': '#e3e7ea',
          'on-absence-adjust': '#3b4a54',
          'absence-cooldown': '#f9e0cf',
          'on-absence-cooldown': '#8a3f0c',
          'zone-roster': '#dcecef',
          'on-zone-roster': '#1f5a68',
          'zone-game': '#dfe4ee',
          'on-zone-game': '#1B3A6B',
          'date-game': '#dfe4ee',
          'on-date-game': '#1B3A6B',
          'date-interleague': '#d6e9f2',
          'on-date-interleague': '#12506b',
          'date-reserve': '#dcecef',
          'on-date-reserve': '#1f5a68',
          'date-travel': '#e3e7ea',
          'on-date-travel': '#3b4a54',
          'date-rain': '#e3e1db',
          'on-date-rain': '#4a4a4a',
          'result-win': '#ddefc9',
          'on-result-win': '#2f5a12',
          'result-loss': '#f7d9dc',
          'on-result-loss': '#8a1420',
          'result-draw': '#eeece7',
          'on-result-draw': '#4a4a4a',
          'result-nogame': '#e3e1db',
          'on-result-nogame': '#4a4a4a',
          action: '#2E7D32',
          'on-action': '#FFFFFF',
        },
      },
      dark: {
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
          'on-surface': '#E8E8F2',
          'surface-variant': '#2D2D50',
          'on-surface-variant': '#B8B8D0',
          link: '#9DBBF2',
          'border-strong': '#7C7CB0',
          'danger-ink': '#ffb3b8',

          // テキストカラー（Darkモード）
          'text-high': '#E8E8F2', // 本文（高重要）
          'text-medium': '#B8B8D0', // 本文（中重要）
          'text-caption': '#A0A0B8', // キャプション
          'text-disabled': '#555555', // 無効テキスト

          // ゲーム固有色
          'game-home': '#9DBBF2',
          'game-visitor': '#B4C7D3',

          'state-done': '#2c4a1c',
          'on-state-done': '#bfe59a',
          'state-todo': '#4d3a0c',
          'on-state-todo': '#ffd777',
          'state-edit': '#252545',
          'on-state-edit': '#E8E8F2',
          'state-warn': '#5a1a22',
          'on-state-warn': '#ffb3b8',
          'state-info': '#1f3f52',
          'on-state-info': '#a9dbf2',
          'state-neutral': '#33335a',
          'on-state-neutral': '#b8b8d0',
          'absence-out': '#5a1d3d',
          'on-absence-out': '#ffb8d8',
          'absence-adjust': '#2f3b44',
          'on-absence-adjust': '#c5d3dc',
          'absence-cooldown': '#5a2f10',
          'on-absence-cooldown': '#ffc7a0',
          'zone-roster': '#1d3b43',
          'on-zone-roster': '#a8d3dd',
          'zone-game': '#27345a',
          'on-zone-game': '#bcd0f5',
          'date-game': '#27345a',
          'on-date-game': '#bcd0f5',
          'date-interleague': '#1f3f52',
          'on-date-interleague': '#a9dbf2',
          'date-reserve': '#1d3b43',
          'on-date-reserve': '#a8d3dd',
          'date-travel': '#2f3b44',
          'on-date-travel': '#c5d3dc',
          'date-rain': '#33335a',
          'on-date-rain': '#b8b8d0',
          'result-win': '#2c4a1c',
          'on-result-win': '#bfe59a',
          'result-loss': '#5a1a22',
          'on-result-loss': '#ffb3b8',
          'result-draw': '#33335a',
          'on-result-draw': '#b8b8d0',
          'result-nogame': '#33335a',
          'on-result-nogame': '#b8b8d0',
          action: '#7CD08F',
          'on-action': '#082414',
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
    // 追加: ダイアログ統一
    VDialog: { scrollable: true },
    // 追加: アラート統一
    VAlert: { density: 'compact' },
    // 追加: チップ統一
    VChip: { size: 'small', variant: 'tonal' },
    // 追加: リスト統一
    VList: { density: 'compact' },
    VListItem: { density: 'compact' },
    // 追加: ツールチップ統一
    VTooltip: { location: 'bottom' },
    // 追加: スナックバー統一
    VSnackbar: { location: 'top', timeout: 3000 },
    // 追加: オートコンプリート統一
    VAutocomplete: { density: 'compact', variant: 'outlined' },
    // 追加: テキストエリア統一
    VTextarea: { density: 'compact', variant: 'outlined' },
    // 追加: タブ統一
    VTabs: { color: 'primary' },
  },
})
