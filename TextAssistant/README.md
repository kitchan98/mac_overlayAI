# Personal Productivity

A collection of productivity tools for macOS.

## Text Assistant

A lightweight macOS menu bar app that lets you quickly chat with an LLM about any selected text. Highlight text anywhere, press a hotkey, and get instant AI assistance in a floating overlay.

**[Download Latest Release](https://github.com/kitchan98/personal-productivity/releases/latest)**

### Features

- **Global Hotkey** (`Cmd+Option+A`) - Summon the assistant from any application
- **Smart Text Capture** - Automatically captures highlighted text via Accessibility API
- **YouTube Summarization** - Highlight a YouTube URL and get an instant transcript-based summary with follow-up Q&A
- **Web Search** - Toggle real-time web search for up-to-date information (via OpenRouter)
- **Streaming Responses** - Real-time token-by-token responses via OpenRouter
- **Multi-turn Conversations** - Ask follow-up questions in the same session
- **File Attachments** - Drag and drop images, PDFs, and code files
- **Multiple Models** - Choose from Gemini, GPT, Qwen, Grok, DeepSeek, and more
- **Personal Context** - Configure background information about yourself
- **Menu Bar Only** - Runs quietly without cluttering your dock

### Installation

1. Download `TextAssistant-x.x.x.dmg` from [Releases](https://github.com/kitchan98/personal-productivity/releases)
2. Open the DMG and drag **Text Assistant** to Applications
3. Launch the app (appears in menu bar)
4. Open Settings and enter your [OpenRouter API key](https://openrouter.ai/keys)
5. Grant Accessibility permission when prompted

### Requirements

- macOS 13.0 or later
- [OpenRouter API key](https://openrouter.ai/keys)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) (optional, for YouTube summarization)

### Usage

1. Highlight text in any application
2. Press `Cmd+Option+A`
3. Ask a question or start chatting
4. Press Enter to send, click X or Escape to close

### YouTube Summarization

Get instant summaries of YouTube videos:

**Method 1: Highlight & Hotkey**
1. Highlight a YouTube URL anywhere (browser, notes, etc.)
2. Press `Cmd+Option+A`
3. The app automatically detects the YouTube link and fetches the transcript
4. A detailed summary streams in, and you can ask follow-up questions

**Method 2: Paste in Chat**
1. Open the assistant with `Cmd+Option+A`
2. Paste a YouTube URL in the chat input
3. Send the message to get a summary

Supported URL formats: `youtube.com/watch?v=...`, `youtu.be/...`, `youtube.com/shorts/...`

> **Note**: Requires [yt-dlp](https://github.com/yt-dlp/yt-dlp) (`brew install yt-dlp`). Video must have subtitles or auto-generated captions.

### Supported Attachments

Drag and drop files directly into the chat:

- **Images**: PNG, JPG, GIF, WebP, HEIC
- **Documents**: PDF
- **Code/Text**: Swift, Python, JS, TS, JSON, YAML, Markdown, and more

### Available Models

| Model | Provider |
|-------|----------|
| Gemini 2.5 Flash Lite | Google |
| GPT OSS 120B | OpenAI |
| GPT-5 Nano | OpenAI |
| Qwen3 Coder (Free) | Qwen |
| Grok 4.1 Fast | xAI |
| DeepSeek V3.2 | DeepSeek |

### Building from Source

```bash
cd TextAssistant

# Build the app bundle
./Scripts/build-app.sh

# Create distributable DMG
./Scripts/create-dmg.sh

# Run the app
open "dist/Text Assistant.app"
```

### Development Workflow

After making code changes:

1. Update version in `TextAssistant/Resources/Info.plist` and `Scripts/create-dmg.sh`
2. Build: `./Scripts/build-app.sh`
3. Package: `./Scripts/create-dmg.sh`
4. Test: `open "dist/Text Assistant.app"`
5. Release:
   ```bash
   git add . && git commit -m "Description" && git push
   gh release create v1.x.x dist/TextAssistant-1.x.x.dmg --title "Text Assistant v1.x.x" --notes "Changes..."
   ```

### Project Structure

```
TextAssistant/
├── Package.swift                 # Swift package manifest
├── Scripts/
│   ├── build-app.sh              # Builds .app bundle
│   ├── create-dmg.sh             # Creates distributable DMG
│   └── GenerateIcon.swift        # Generates app icon
└── TextAssistant/
    ├── App/
    │   └── TextAssistantApp.swift
    ├── Services/
    │   ├── HotkeyManager.swift       # Global hotkey (Cmd+Opt+A)
    │   ├── TextCaptureService.swift  # Text selection capture
    │   ├── OpenRouterService.swift   # LLM API streaming
    │   ├── YouTubeService.swift      # YouTube transcript fetching
    │   └── SecureStorage.swift       # Settings persistence
    ├── Models/
    │   └── ChatMessage.swift
    ├── ViewModels/
    │   └── ChatViewModel.swift
    ├── UI/
    │   ├── Overlay/                  # Floating chat window
    │   ├── MenuBar/                  # Menu bar dropdown
    │   └── Settings/                 # Preferences window
    └── Resources/
        ├── Info.plist
        └── AppIcon.icns
```

### Troubleshooting

**Text capture not working**
1. Open System Settings > Privacy & Security > Accessibility
2. Find Text Assistant and enable the toggle
3. If already enabled, remove and re-add the app

**API errors**
- Verify your OpenRouter API key is correct
- Check your API credit balance at [openrouter.ai](https://openrouter.ai)

**Overlay not appearing**
- Ensure the app is running (check menu bar icon)
- Try the hotkey again - it may take a moment on first use
- Check that no other app is capturing the same hotkey

## License

MIT
