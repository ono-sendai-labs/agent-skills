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

- **`scripts/transcribe.py`** — Uploads an audio file to the Gemini Files API, transcribes it, and writes the transcript to a `.txt` file.

## Workflow

1. Verify the audio file exists and confirm `GEMINI_API_KEY` is set in the environment.

2. Run the transcription script:
   ```bash
   uv run scripts/transcribe.py <audio-file> [--output <output.txt>]
   ```

   Examples:
   ```bash
   # Saves transcript to spoken-notes-transcript.txt next to the audio file
   uv run scripts/transcribe.py spoken-notes.m4a

   # Save to an explicit output path
   uv run scripts/transcribe.py spoken-notes.m4a --output transcript.txt

   # Print transcript to stdout
   uv run scripts/transcribe.py spoken-notes.m4a --output -
   ```

   Default output: `<audio-file-stem>-transcript.txt` in the same directory as the audio file.

3. Read the transcript file and use it as the basis for further work (drafting a document, summarizing, extracting action items, etc.).

## Supported audio formats

Gemini supports: mp3, wav, aiff, aac, ogg, flac, m4a, and other common formats.

## Troubleshooting

- `GEMINI_API_KEY not set` — Export the key: `export GEMINI_API_KEY=your-key-here`
- `Audio file not found` — Check that the path is correct relative to your working directory.
- `API error` — Ensure your API key is valid and the Gemini API is enabled in your Google AI Studio project.
