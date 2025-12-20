import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'downloader.zig',
  description: 'A production-ready, high-performance HTTP/HTTPS downloader library for Zig',
  
  base: '/downloader.zig/',
  
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { name: 'og:type', content: 'website' }],
    ['meta', { name: 'og:title', content: 'downloader.zig' }],
    ['meta', { name: 'og:description', content: 'A production-ready HTTP/HTTPS downloader library for Zig' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
  ],

  themeConfig: {
    logo: '/logo.svg',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'API', link: '/api/' },
      { text: 'Examples', link: '/examples/' },
      {
        text: 'v0.0.1',
        items: [
          { text: 'Releases', link: 'https://github.com/muhammad-fiaz/downloader.zig/releases' }
        ]
      }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'What is downloader.zig?', link: '/guide/introduction' },
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Installation', link: '/guide/installation' },
          ]
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Configuration', link: '/guide/configuration' },
            { text: 'Progress Reporting', link: '/guide/progress' },
            { text: 'Resume Downloads', link: '/guide/resume' },
            { text: 'Retry Logic', link: '/guide/retry' },
            { text: 'Error Handling', link: '/guide/errors' },
          ]
        },
        {
          text: 'Advanced',
          items: [
            { text: 'Concurrent Downloads', link: '/guide/concurrent' },
            { text: 'Custom User-Agent', link: '/guide/user-agent' },
            { text: 'Thread Safety', link: '/guide/thread-safety' },
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/' },
            { text: 'Client', link: '/api/client' },
            { text: 'Config', link: '/api/config' },
            { text: 'Progress', link: '/api/progress' },
            { text: 'Errors', link: '/api/errors' },
          ]
        }
      ],
      '/examples/': [
        {
          text: 'Examples',
          items: [
            { text: 'Overview', link: '/examples/' },
            { text: 'Basic Download', link: '/examples/basic' },
            { text: 'Advanced Configuration', link: '/examples/advanced' },
            { text: 'Concurrent Downloads', link: '/examples/concurrent' },
            { text: 'Resume Downloads', link: '/examples/resume' },
            { text: 'Checksum Verification', link: '/examples/checksum' },
            { text: 'Update Checker', link: '/examples/update-check' },
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/muhammad-fiaz/downloader.zig' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024 Muhammad Fiaz'
    },

    search: {
      provider: 'local'
    },

    editLink: {
      pattern: 'https://github.com/muhammad-fiaz/downloader.zig/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    }
  }
})
