# NeuralPilot Agent

NeuralPilot Agent is an accessible Android AI assistant built with Lua and AndroLua. It is designed to help everyday users chat with AI, speak to the assistant, listen to responses through text-to-speech, run useful Lua tasks, manage multiple AI providers, save conversations, save generated code, and update itself from a remote source.

The project focuses on accessibility, practical AI use, and simple Android-based automation. It is especially useful for users who prefer voice input, screen reader support, clear button labels, and a direct mobile interface.

Current version:

```text
3.5.5
```

Application and support URL:

[Jieshuo Library Telegram Channel](https://t.me/Jieshuolibrary)

## Repository Files

This project currently uses only two main files:

```text
README.md
main.lua
```

`README.md` contains project information, setup details, feature descriptions, and usage notes.

`main.lua` contains the full application source code for NeuralPilot Agent.

No separate `SECURITY.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, or license file is required for the current simple repository structure, although you may add those files later if you want a more complete open-source project setup.

## Project Purpose

NeuralPilot Agent is built to make AI assistance available directly inside an Android Lua environment. The app can be used for normal conversation, information processing, API requests, local Lua execution, simple automation, and assisted problem solving.

The project is designed around these goals:

- Make AI easier to use on Android.
- Support blind and screen reader users.
- Provide speech input and spoken output.
- Support multiple AI providers.
- Allow useful Lua code execution when needed.
- Save generated code for later review.
- Keep settings and conversations stored locally.
- Provide automatic update support.
- Offer several runtime access levels for different needs.
- Keep the interface simple and reachable on mobile devices.

## Main Features

NeuralPilot Agent includes the following features:

- Chat with AI using a text input box.
- Speak to the assistant using Android speech recognition.
- Hear responses through Android text-to-speech.
- Save conversation history locally.
- Store personal information or instructions for future conversations.
- Enable or disable conversation memory.
- Choose from multiple response styles.
- Use OpenRouter as an AI provider.
- Use Google AI Studio as an AI provider.
- Use NVIDIA NIM as an AI provider.
- Store multiple API keys for each provider.
- Rotate between multiple API keys.
- Load available model lists from provider APIs.
- Select the active AI model.
- Run Lua code internally when the AI decides it is useful.
- Repair incomplete AI-generated Lua code.
- Repair Lua code that fails at runtime.
- Improve Lua code that runs but produces no visible output.
- Save generated Lua code to local storage.
- View and copy generated code.
- Use a clipboard helper.
- Use runtime helper functions such as HTTP GET and URL encoding.
- Use JSON parsing through cjson.
- Support Safe Runtime, Expanded Runtime, Android Runtime, and Unrestricted Runtime.
- Use a full-screen scrolling main page for accessibility.
- Use a scrolling settings page.
- Stop generation at any time.
- Reset the current conversation.
- Automatically check for updated code from GitHub.
- Start the saved latest update if available.
- Fall back to the built-in version if the saved update cannot run.

## Accessibility

Accessibility is one of the most important goals of NeuralPilot Agent.

The app is designed to be usable with screen readers such as TalkBack. The interface uses clear text labels, standard Android widgets, spoken status messages, and a scrollable layout.

Accessibility-related features include:

- Text-to-speech greeting.
- Spoken status updates.
- Speech recognition input.
- Clear button names.
- Conversation text display.
- Full-screen main page scrolling.
- Settings page scrolling.
- Vibration feedback.
- Simple status text such as Ready, Working, and Stopped.
- Conversation reset feedback.
- Error messages spoken through the assistant.

The project is suitable for users who do not want to visually inspect the screen often and prefer audio feedback.

## AI Providers

NeuralPilot Agent supports three AI provider options.

### OpenRouter

OpenRouter is the default provider in the project.

OpenRouter API endpoint used by the app:

```text
https://openrouter.ai/api/v1/chat/completions
```

OpenRouter model list endpoint used by the app:

```text
https://openrouter.ai/api/v1/models
```

OpenRouter application title used by the app:

```text
NeuralPilot Agent v3.5.5
```

OpenRouter application URL used by the app:

[Jieshuo Library Telegram Channel](https://t.me/Jieshuolibrary)

### Google AI Studio

Google AI Studio support is included through the Gemini API format.

Default model:

```text
gemini-2.0-flash
```

Google model list endpoint used by the app:

```text
https://generativelanguage.googleapis.com/v1beta/models
```

### NVIDIA NIM

NVIDIA NIM support is included through an OpenAI-compatible API format.

Default model:

```text
meta/llama-3.1-8b-instruct
```

NVIDIA model list endpoint used by the app:

```text
https://integrate.api.nvidia.com/v1/models
```

## API Key Storage

API keys are stored locally in the app settings file.

Default settings file path:

```text
/storage/emulated/0/NeuralPilot/neuralpilot_settings.json
```

The app supports multiple API keys per provider. Each key should be placed on a separate line in the API key input dialog.

Example format:

```text
first_api_key
second_api_key
third_api_key
```

The app rotates through available keys when making requests.

Do not publish your private API keys in a public repository. If you share this project publicly, make sure the settings file is not included if it contains real API keys.

## Runtime Modes

NeuralPilot Agent includes four runtime modes. These modes control how much access AI-generated Lua code receives.

### Safe Runtime

Safe Runtime is the most restricted mode.

It provides basic Lua features and selected helpers such as:

- `print`
- `math`
- `string`
- `table`
- `json`
- `cjson`
- `httpGet`
- `urlEncode`
- `androidBuild`
- `appInfo`
- `userProfile`

Safe Runtime is recommended for normal use.

### Expanded Runtime

Expanded Runtime provides more access than Safe Runtime.

It can include:

- File-related access
- OS-related access
- Android build information
- URI support
- Basic helper functions

Expanded Runtime is useful when tasks need limited file or system interaction.

### Android Runtime

Android Runtime adds selected Android objects and classes.

It can expose useful Android-related objects such as:

- `activity`
- `Context`
- `Intent`
- `Settings`
- `Toast`
- `Vibrator`
- `ClipboardManager`
- `ClipData`

Android Runtime is useful when a task needs to interact with Android features.

### Unrestricted Runtime

Unrestricted Runtime gives generated Lua code access to the real app environment as much as possible.

It can expose:

- Existing global variables
- App helper functions
- Android objects
- `import`
- `require`
- `package`
- `io`
- `os`
- Files
- Libraries visible to the main script

Unrestricted Runtime is powerful but risky. It should only be used when the user trusts the task and the selected AI model.

Possible risks include:

- App crashes
- File changes
- Unexpected Android API calls
- Access to files allowed by Android permissions
- Changes to app state
- Running unsafe generated code

For normal use, Safe Runtime is recommended.

## Runtime Helpers

The app provides useful helper functions for AI-generated Lua code.

Common helpers include:

```text
httpGet(url)
urlEncode(text)
json.decode(text)
cjson.decode(text)
```

These helpers allow the AI to perform simple API requests, encode URL parameters, and parse JSON responses.

Example concept:

```lua
local topic = "AI"
local url = "https://th.wikipedia.org/w/api.php?action=query&format=json&prop=extracts&exintro=1&explaintext=1&titles=" .. urlEncode(topic)
local raw = httpGet(url)
local data = json.decode(raw)

for pageId, page in pairs(data.query.pages) do
    print(page.extract)
end
```

## Response Styles

NeuralPilot Agent includes multiple response styles.

Available styles:

```text
Balanced
Concise
Detailed
Friendly
Professional
Step-by-step
Beginner-friendly
Accessibility-focused
Technical
Creative
```

These styles change how the AI writes its answers.

For example:

- `Concise` gives short and direct answers.
- `Detailed` gives more complete explanations.
- `Step-by-step` explains in ordered steps.
- `Accessibility-focused` gives clearer guidance for screen reader users.
- `Technical` gives more implementation-aware responses.

## Conversation Memory

The app can remember conversation history during the current session.

Conversation memory can be turned on or off from the settings page.

When memory is enabled, previous user messages and assistant replies are included in later prompts. This helps the AI understand context without asking the user to repeat information.

The app also saves conversation history to a local text file.

Default conversation file path:

```text
/storage/emulated/0/NeuralPilot/neuralpilot_conversations.txt
```

## Personal Information

The app includes a Personal Info feature.

Users can type instructions or personal notes that should be included in future conversations.

Examples of personal information may include:

- Preferred response style
- Accessibility needs
- Project rules
- Coding preferences
- Common instructions
- Personal workflow notes

Personal info is stored locally in the settings file.

## Generated Code System

When NeuralPilot Agent generates Lua code for a task, it saves the code locally.

Generated code folder:

```text
/storage/emulated/0/NeuralPilot/generated_code/
```

Generated code files are saved with names like:

```text
generated_code_1.txt
generated_code_2.txt
generated_code_3.txt
```

The app includes a Generated Code button that lets the user view or copy saved generated code.

This is useful for reviewing what the AI generated during runtime tasks.

## Auto Update System

NeuralPilot Agent includes an automatic update system.

Default remote update URL:

[NeuralPilot Agent remote main.lua](https://raw.githubusercontent.com/aphisitemthong-cpu/NeuralPilot-Agent/main/main.lua)

Default saved update file:

```text
/storage/emulated/0/NeuralPilot/neuralpilot_latest.lua
```

Default auto update log file:

```text
/storage/emulated/0/NeuralPilot/neuralpilot_auto_update_log.txt
```

Auto update behavior:

1. When the app starts, it can check the remote update URL.
2. If a remote script is found, it shows an update dialog.
3. The dialog shows version, size, line count, URL, and saved update information.
4. If the user chooses Update Now, the remote script is saved locally and started.
5. If the user skips the update, the app can start the latest saved update if available.
6. If the remote download fails, the app tries the saved update first.
7. If the saved update does not exist or cannot run, the built-in version starts.

This allows the app to keep working even if the internet connection fails.

## Local Storage

NeuralPilot Agent uses this main folder:

```text
/storage/emulated/0/NeuralPilot/
```

Important local files and folders:

```text
/storage/emulated/0/NeuralPilot/neuralpilot_conversations.txt
/storage/emulated/0/NeuralPilot/neuralpilot_settings.json
/storage/emulated/0/NeuralPilot/neuralpilot_latest.lua
/storage/emulated/0/NeuralPilot/neuralpilot_auto_update_log.txt
/storage/emulated/0/NeuralPilot/generated_code/
```

The app creates these folders and files as needed.

## Settings Page

The Settings page includes controls for:

- Switching AI provider
- Setting OpenRouter API keys
- Setting Google AI Studio API keys
- Setting NVIDIA NIM API keys
- Opening setup help and credits
- Selecting the active model
- Changing response style
- Changing runtime access mode
- Turning conversation memory on or off
- Configuring additional runtime permissions
- Turning automatic update on or off
- Checking for the latest version manually
- Returning to the main page

The Settings page uses a ScrollView so all controls remain reachable on smaller screens.

## Main Page

The main page includes:

- App title and version
- Agent status
- Storage information
- Application URL information
- Selected provider, model, runtime, and style
- Text input field
- Send button
- Stop Generating button
- Set Personal Info button
- Talk to NeuralPilot button
- Settings button
- Generated Code button
- Reset Conversation button
- Help button
- Conversation display area

The main page uses a full-screen ScrollView so the conversation display remains reachable with TalkBack and on smaller screens.

## Permissions

The app may request Android permissions for:

- Recording audio
- Writing to external storage
- Vibration feedback

These are used for speech recognition, saving local files, and vibration feedback.

Depending on Android version, storage permission behavior may vary. Some newer Android versions may require additional manual storage access settings.

## Installation

This project is intended for AndroLua-compatible Android environments.

General setup:

1. Install an AndroLua-compatible environment on Android.
2. Add `main.lua` to the project.
3. Run the script from the Lua environment.
4. Open the app settings.
5. Choose an AI provider.
6. Add at least one API key for the selected provider.
7. Select a model.
8. Return to the main page.
9. Type or speak a message.
10. Press Send to NeuralPilot or use speech input.

## Basic Usage

To chat with NeuralPilot Agent:

1. Open the app.
2. Type a message in the input field.
3. Press Send to NeuralPilot.
4. Wait for the answer.
5. Read the conversation display or listen to the spoken response.

To use voice input:

1. Press Talk to NeuralPilot.
2. Speak your request.
3. The app sends the recognized text to the assistant.
4. The answer is displayed and spoken.

To stop generation:

1. Press Stop Generating.
2. The current request is cancelled.
3. The app returns to a stopped or ready state.

To reset conversation:

1. Press Reset Conversation.
2. The visible conversation and current session memory are cleared.

## Example Tasks

NeuralPilot Agent can be used for tasks such as:

- Asking general questions
- Writing short text
- Explaining code
- Running simple Lua calculations
- Calling simple public APIs
- Parsing JSON responses
- Checking app or device information
- Generating Lua snippets
- Saving generated code
- Reading and summarizing runtime output
- Repairing failed Lua snippets
- Helping with Android Lua development

## Important Safety Notes

NeuralPilot Agent can execute AI-generated Lua code. This is powerful, but it also requires caution.

Recommended safety practices:

- Use Safe Runtime for normal conversation.
- Use Expanded Runtime only when file or OS access is needed.
- Use Android Runtime only when Android APIs are needed.
- Use Unrestricted Runtime only when you trust the task and model.
- Do not run destructive file operations unless you are sure.
- Do not share private API keys.
- Do not publish local settings files containing secrets.
- Review generated code before using it outside the app.
- Be careful when allowing generated code to access storage or Android APIs.

## Privacy Notes

The app stores settings, personal info, conversations, and generated code locally in the app folder.

AI requests are sent to the selected provider. The selected provider receives the prompt content needed to generate a response.

If conversation memory or personal info is enabled, that information may be included in AI prompts.

Users should avoid entering sensitive information unless they understand how their selected AI provider handles data.

## Open Source Notes

This project is open source.

Because the repository currently has only two files, the simplest structure is:

```text
README.md
main.lua
```

If you want to keep the project simple, this is enough.

If you later want a more complete repository, you may add optional files such as:

```text
LICENSE
CHANGELOG.md
CONTRIBUTING.md
SECURITY.md
```

These files are optional and are not required for the current two-file project.

## License Recommendation

If this project is public, it is recommended to add a license in the future so users know what they are allowed to do with the code.

Common open-source license choices include:

- MIT License
- Apache License 2.0
- GPL License

If no license is included, people may not clearly know whether they can copy, modify, redistribute, or use the project commercially.

For now, if you only want two files, you can mention your license choice inside this README.

Example:

```text
This project is open source. License information will be added later.
```

Or:

```text
This project is released under the MIT License.
```

Only use a license statement if it matches your real intention.

## Credits

Developer:

```text
Jieshuo Library
```

Community and support:

[Jieshuo Library Telegram Channel](https://t.me/Jieshuolibrary)

## Disclaimer

NeuralPilot Agent is an experimental AI assistant project. AI-generated responses and AI-generated code may be incorrect, incomplete, unsafe, or unsuitable for some tasks.

Use the app responsibly. Be careful with runtime modes that allow file access, Android API access, imports, or unrestricted execution.

The developer and contributors are not responsible for damage caused by unsafe generated code, incorrect AI output, misused API keys, or user-modified versions of the project.
```