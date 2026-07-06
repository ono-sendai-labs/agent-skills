#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "google-genai>=0.8.0",
# ]
# ///
"""Transcribe an audio file to text using the Google Gemini API."""

import argparse
import os
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(
        description="Transcribe an audio file to text using the Gemini API.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  uv run scripts/transcribe.py spoken-notes.m4a
  uv run scripts/transcribe.py spoken-notes.m4a --output my-transcript.txt
  uv run scripts/transcribe.py spoken-notes.m4a --output -

Exit codes:
  0  Success
  1  Invalid arguments or file not found
  2  API error
""",
    )
    parser.add_argument("audio_file", help="Path to the audio file to transcribe")
    parser.add_argument(
        "--output",
        default=None,
        help=(
            "Output file path (default: <audio_file_stem>-transcript.txt "
            "in the same directory as the audio file). Use '-' for stdout."
        ),
    )
    parser.add_argument(
        "--model",
        default="gemini-flash-latest",
        help="Gemini model to use.",
    )
    args = parser.parse_args()

    audio_path = Path(args.audio_file)
    if not audio_path.exists():
        print(f"Error: Audio file not found: {audio_path}", file=sys.stderr)
        print(f"       Provide a valid path to an audio file.", file=sys.stderr)
        sys.exit(1)

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        print("       Get a key at https://aistudio.google.com/apikey", file=sys.stderr)
        sys.exit(2)

    # Determine output destination
    if args.output == "-":
        output_file = None  # stdout
    elif args.output:
        output_file = Path(args.output)
    else:
        output_file = audio_path.parent / f"{audio_path.stem}-transcript.txt"

    from google import genai

    client = genai.Client(api_key=api_key)

    print(f"Uploading {audio_path.name}...", file=sys.stderr)
    try:
        uploaded_file = client.files.upload(file=str(audio_path))
    except Exception as e:
        print(f"Error: Failed to upload audio file: {e}", file=sys.stderr)
        sys.exit(2)

    print("Transcribing...", file=sys.stderr)
    try:
        response = client.models.generate_content(
            model=args.model,
            contents=[
                (
                    "Transcribe this audio recording verbatim. "
                    "Output only the transcript text with no commentary, "
                    "headers, or timestamps unless they are part of the spoken content."
                ),
                uploaded_file,
            ],
        )
    except Exception as e:
        print(f"Error: Transcription failed: {e}", file=sys.stderr)
        sys.exit(2)
    finally:
        # Clean up uploaded file regardless of success/failure
        try:
            client.files.delete(name=uploaded_file.name)
        except Exception:
            pass

    transcript = response.text

    if output_file is None:
        print(transcript)
    else:
        output_file.write_text(transcript, encoding="utf-8")
        print(f"Transcript written to: {output_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
