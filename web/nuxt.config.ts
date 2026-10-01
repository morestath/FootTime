export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  ssr: false, // SPA : la session Supabase vit dans le navigateur
  css: ['~/assets/css/main.css'],
  app: { head: { title: 'FootTime', htmlAttrs: { lang: 'fr' },
    meta: [{ name: 'viewport', content: 'width=device-width, initial-scale=1' },
           { name: 'theme-color', content: '#0B0F0E' }] } },
  runtimeConfig: { public: {
    supabaseUrl: process.env.NUXT_PUBLIC_SUPABASE_URL || '',
    supabaseAnonKey: process.env.NUXT_PUBLIC_SUPABASE_ANON_KEY || '',
    sandbox: process.env.NUXT_PUBLIC_SANDBOX === 'true',
  } },
})
