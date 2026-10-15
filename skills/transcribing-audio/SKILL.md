---
name: transcribing-audio
description: Transcribe audio files (m4a, mp3, wav, aac, flac, ogg, etc.) containing spoken notes or recordings into text using the Gemini API. Use when the user provides an audio file and wants it transcribed, mentions spoken notes, voice memos, or dictated content that needs to be converted to text before further processing (e.g. drafting a document from spoken notes).
compatibility: Requires uv (https://docs.astral.sh/uv/) and a GEMINI_API_KEY environment variable.
---

# Transcribing Audio

Transcribe audio files to text using the Google Gemini API. The transcript is saved as a `.txt` file alongside the audio file (or to a specified output path).

## Prerequisites

- **uv** must be installed. Check with `uv --version`. Install via:
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
- **GEMINI_API_KEY** environment variable must be set. Get a key at https://aistudio.google.com/apikey

## Available scripts

- **`scripts/transcribe.py`** — Uploads an audio file to the Gemini Files API, transcribes it using the dedicated Gemini transcription API (`gemini-3.5-transcribe`), and writes the transcript to a `.txt` file.

## Workflow

1. Verify the audio file exists and confirm `GEMINI_API_KEY` is set in the environment.

2. Run the transcription script:
   ```bash
   uv run scripts/transcribe.py <audio-file> [options]
   ```

   Examples:
   ```bash
   # Transcribe using the dedicated transcription API in smart mode (default)
   # Saves transcript to spoken-notes-transcript.txt next to the audio file
   uv run scripts/transcribe.py spoken-notes.m4a

   # Transcribe verbatim (preserves exact filler words and repetitions)
   uv run scripts/transcribe.py spoken-notes.m4a --mode verbatim

   # Transcribe using regular Gemini Flash with the legacy prompt
   uv run scripts/transcribe.py spoken-notes.m4a --flash

   # Save to an explicit output path
   uv run scripts/transcribe.py spoken-notes.m4a --output transcript.txt

   # Print transcript to stdout
   uv run scripts/transcribe.py spoken-notes.m4a --output -
   ```

   Options:
   - `--mode {smart,verbatim}`: Transcription mode for the dedicated API (default: `smart`). `smart` removes fillers and self-corrections while applying structured formatting; `verbatim` preserves word-for-word audio.
   - `--flash`, `--legacy`: Fall back to regular Gemini Flash (`gemini-flash-latest`) using `models.generate_content` and prompt-based transcription.
   - `--model MODEL`: Override the model (defaults to `gemini-3.5-transcribe`, or `gemini-flash-latest` with `--flash`).
   - `--output OUTPUT`: Output file path (default: `<stem>-transcript.txt`), or `-` for stdout.

3. Read the transcript file and use it as the basis for further work (drafting a document, summarizing, extracting action items, etc.).

## Supported audio formats

Gemini supports: mp3, wav, aiff, aac, ogg, flac, m4a, and other common formats.

## Troubleshooting

- `GEMINI_API_KEY not set` — Export the key: `export GEMINI_API_KEY=your-key-here`
- `Audio file not found` — Check that the path is correct relative to your working directory.
- `API error` — Ensure your API key is valid and the Gemini API is enabled in your Google AI Studio project.
