# Brand & Icon Assets

Jarvis identifies AI providers, developer tools, and cloud services using crisp vector symbols (`SF Symbols`), native macOS application icons (`NSWorkspace.shared.icon(forFile:)`), and a curated set of static provider marks in `Sources/JarvisDemo/Resources/Brands/`.

## Bundled Provider Marks

- **AI Providers:** OpenAI (`openai.png`), Anthropic / Claude (`anthropic.png`), Google AI / Gemini (`google.png`), Kimi (`kimi.png`), ElevenLabs (`elevenlabs.png`), xAI / X (`x.png`).
- **Creative & macOS Utilities:** Adobe (`adobe.png`, `photoshop.png`), iCloud (`icloud.png`), CleanMyMac (`cleanmymac.png`).
- **Developer Stack Vector Badges:** AWS, Cursor, GitHub Copilot, Vercel, Supabase, Linear, Raycast, Cloudflare, Docker, Next.js, Vite, FastAPI, Ollama, PostgreSQL, and Redis are rendered using high-contrast native SF Symbols and semantic accent tints.

All bundled PNGs have metadata stripped so `python3 scripts/check_publication.py` verifies clean binary chunks (`IHDR`, `IDAT`, `IEND`, `sRGB`). Brand names and marks belong to their respective owners and are used solely to identify user-configured developer tools and subscriptions.
