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


def _load_api_key_from_dotenv():
    """Best-effort read of GEMINI_API_KEY from $HOME/.env, without adding a dependency."""
    dotenv_path = Path.home() / ".env"
    if not dotenv_path.is_file():
        return None
    try:
        for line in dotenv_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            if key.startswith("export "):
                key = key[len("export "):].strip()
            if key != "GEMINI_API_KEY":
                continue
            value = value.strip().strip('"').strip("'")
            return value or None
    except OSError:
        return None
    return None


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

    api_key = os.environ.get("GEMINI_API_KEY") or _load_api_key_from_dotenv()
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        print("       Set it in the environment or in $HOME/.env.", file=sys.stderr)
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
                    "Transcribe this audio recording. Output only the transcript text, "
                    "with no commentary, headers, or timestamps unless they are part of "
                    "the spoken content.\n"
                    "\n"
                    "Apply only light, mechanical cleanup as you transcribe:\n"
                    "- Remove filler words and verbal tics (e.g. \"uhm\", \"uh\", \"like\", "
                    "\"you know\") that carry no content.\n"
                    "- If the speaker immediately restarts or self-corrects a word or "
                    "phrase they just said (e.g. \"...the report is due Friday - oh no, "
                    "I mean Monday\"), keep only the corrected version, as if they had "
                    "said it right the first time.\n"
                    "\n"
                    "Do NOT do anything beyond that. In particular:\n"
                    "- Do not reorder, restructure, or move text. If the speaker refers "
                    "back to something they said earlier (e.g. \"I meant to say earlier "
                    "that...\"), transcribe that reference in place, exactly where it "
                    "occurs - do not go back and edit the earlier passage.\n"
                    "- Do not paraphrase, summarize, or otherwise change the speaker's "
                    "wording beyond removing fillers and immediate self-corrections as "
                    "described above.\n"
                    "\n"
                    "Handle unclear audio inline, at the point it occurs, using these "
                    "markers:\n"
                    "- If a word or short phrase is inaudible or too garbled to guess, "
                    "write: [...garbled]\n"
                    "- If a word is unclear but you have multiple plausible guesses, "
                    "write: [unclear: option one | option two]\n"
                    "- If you can't confidently spell a word but can approximate its "
                    "sound, write: [unclear; phonetic: pray-shus]\n"
                    "Use whichever of these three forms is the best fit; do not guess "
                    "silently and present it as certain."
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
