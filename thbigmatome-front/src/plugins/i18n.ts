import { createI18n } from 'vue-i18n'
import ja from '@/locales/ja.json'

const i18n = createI18n({
  legacy: false, // Composition APIで使うため false に設定
  locale: 'ja',
  fallbackLocale: 'ja',
  messages: {
    ja,
  },
  missingWarn: false,
  fallbackWarn: false,
})

export default i18n