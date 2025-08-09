import { createApp } from 'vue'
import App from './App.vue'
import router from '@/router/index'
import i18n from '@/plugins/i18n'
import '@/plugins/axios'

// Vuetify
import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'

// Material Design Icons
import '@mdi/font/css/materialdesignicons.css'

const vuetify = createVuetify({
  components,
  directives,
  locale: {
    locale: 'ja',
    fallback: 'en',
  },
  theme: {
    defaultTheme: 'light'
  }
})

const app = createApp(App)
app.use(router)
app.use(vuetify)
app.use(i18n)
app.mount('#app')

  app.config.warnHandler = (msg, instance, trace) => {
    // Vuetify の翻訳警告を無視
    if (msg.includes('Translation key') && msg.includes('not found')) {
      return
    }
    // その他の警告は表示
    console.warn(msg, trace)
  }
