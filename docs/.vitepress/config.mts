import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Conduit',
  description: 'Unified Swift SDK for local and cloud LLM inference',
  base: '/',

  head: [
    ['link', { rel: 'icon', href: '/conduit-logo.svg' }],
  ],

  themeConfig: {
    logo: '/conduit-logo.svg',

    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Providers', link: '/providers/' },
      {
        text: 'v0.3',
        items: [
          { text: 'Changelog', link: 'https://github.com/christopherkarani/Conduit/releases' },
          { text: 'GitHub', link: 'https://github.com/christopherkarani/Conduit' },
        ],
      },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Essentials',
          items: [
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Architecture', link: '/guide/architecture' },
          ],
        },
        {
          text: 'Generation',
          items: [
            { text: 'Streaming', link: '/guide/streaming' },
            { text: 'Structured Output', link: '/guide/structured-output' },
            { text: 'Tool Calling', link: '/guide/tool-calling' },
          ],
        },
        {
          text: 'Services',
          items: [
            { text: 'Chat Session', link: '/guide/chat-session' },
            { text: 'Model Management', link: '/guide/model-management' },
          ],
        },
        {
          text: 'Reference',
          items: [
            { text: 'Error Handling', link: '/guide/error-handling' },
            { text: 'Platform Support', link: '/guide/platform-support' },
            { text: 'SwiftAgents Integration', link: '/guide/swift-agents-integration' },
          ],
        },
      ],

      '/providers/': [
        {
          text: 'Overview',
          items: [
            { text: 'Providers Overview', link: '/providers/' },
          ],
        },
        {
          text: 'Cloud Providers',
          items: [
            { text: 'Anthropic', link: '/providers/anthropic' },
            { text: 'OpenAI', link: '/providers/openai' },
            { text: 'HuggingFace', link: '/providers/huggingface' },
            { text: 'Kimi', link: '/providers/kimi' },
            { text: 'MiniMax', link: '/providers/minimax' },
          ],
        },
        {
          text: 'Local Providers',
          items: [
            { text: 'MLX', link: '/providers/mlx' },
            { text: 'Foundation Models', link: '/providers/foundation-models' },
            { text: 'CoreML', link: '/providers/coreml' },
            { text: 'Llama', link: '/providers/llama' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/christopherkarani/Conduit' },
    ],

    editLink: {
      pattern: 'https://github.com/christopherkarani/Conduit/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright 2024-present Christopher Karani',
    },
  },
})
