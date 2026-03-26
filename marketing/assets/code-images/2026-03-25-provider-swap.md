# Code Images — 2026-03-25

## Provider Swap Example

Carbon URL:
```
https://carbon.now.sh/?l=swift&t=dracula&bg=rgba(10,10,10,1)&code=//%20OpenAI%0Alet%20provider%20%3D%20OpenAIProvider.openAIKey(apiKey%3A%20%22sk-...%22)%0A%0A//%20Anthropic%20%E2%80%94%20just%20change%20the%20initializer%0Alet%20provider%20%3D%20AnthropicProvider.anthropicKey(apiKey%3A%20%22sk-ant-...%22)%0A%0A//%20Same%20API%20everywhere%0Alet%20result%20%3D%20try%20await%20provider.generate(%0A%20%20%20%20prompt%3A%20%22Hello%22%2C%20model%3A%20.gpt4o%2C%20config%3A%20.default%0A)
```

---

## @Generable Example

Carbon URL:
```
https://carbon.now.sh/?l=swift&t=dracula&bg=rgba(10,10,10,1)&code=@Generable%0Astruct%20WeatherResult%20%7B%0A%20%20%40Guide(description%3A%20%22City%20name%22)%0A%20%20var%20city%3A%20String%0A%20%20%0A%20%20%40Guide(description%3A%20%22Temperature%20in%20Celsius%22)%0A%20%20var%20temperature%3A%20Double%0A%20%20%0A%20%20%40Guide(description%3A%20%22Weather%20condition%22)%0A%20%20var%20condition%3A%20String%0A%7D%0A%0A//%20Auto-synthesized%3A%20init(GeneratedContent)%2C%20generatedContent%2C%20generationSchema%2C%20PartiallyGenerated
```
