"""Ingest PDFs into normalized, citable text chunks.

Pipeline: PDF -> page text -> normalized UTF-8 (NFC) -> chunks with metadata -> JSONL.
Optionally uploads the JSONL to the Nebius Object Storage bucket (S3-compatible).

Usage:
  python ingest.py --src ./corpus --out ./chunks.jsonl [--upload]

Corpus layout (language and tradition come from the path):
  corpus/<lang>/<tradition>/<work>.pdf      e.g. corpus/sa/hindu/bhagavad-gita.pdf
"""

from __future__ import annotations

import argparse
import json
import os
import unicodedata
from pathlib import Path

from pypdf import PdfReader

CHUNK_CHARS = 1200      # target chunk size; split on paragraph boundaries
CHUNK_OVERLAP = 150     # characters repeated between neighbouring chunks


def normalize(text: str) -> str:
    """Unicode NFC so visually identical strings compare equal across scripts."""
    text = unicodedata.normalize("NFC", text)
    return "\n".join(line.rstrip() for line in text.splitlines()).strip()


def pages(pdf_path: Path):
    reader = PdfReader(str(pdf_path))
    for number, page in enumerate(reader.pages, start=1):
        text = normalize(page.extract_text() or "")
        if text:
            yield number, text


def chunk_paragraphs(text: str, size: int = CHUNK_CHARS, overlap: int = CHUNK_OVERLAP):
    """Split on blank lines, then pack paragraphs into chunks up to `size` characters."""
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]
    buffer = ""
    for para in paragraphs:
        if len(buffer) + len(para) + 2 <= size:
            buffer = f"{buffer}\n\n{para}" if buffer else para
            continue
        if buffer:
            yield buffer
            buffer = buffer[-overlap:] + "\n\n" + para if overlap else para
        else:
            # A single paragraph longer than the limit: hard-split it.
            for start in range(0, len(para), size - overlap):
                yield para[start:start + size]
            buffer = ""
    if buffer:
        yield buffer


def describe(pdf: Path, root: Path) -> dict:
    """Derive language, tradition, and work from the folder layout."""
    parts = pdf.relative_to(root).parts
    lang = parts[0] if len(parts) > 2 else "unknown"
    tradition = parts[1] if len(parts) > 2 else "unknown"
    return {"lang": lang, "tradition": tradition, "work": pdf.stem, "source": str(pdf.relative_to(root))}


def ingest(src: Path, out: Path) -> int:
    count = 0
    with out.open("w", encoding="utf-8") as fh:
        for pdf in sorted(src.rglob("*.pdf")):
            meta = describe(pdf, src)
            for page_no, page_text in pages(pdf):
                for index, chunk in enumerate(chunk_paragraphs(page_text)):
                    record = {
                        **meta,
                        "page": page_no,
                        "chunk_index": index,
                        "text": chunk,
                        "id": f"{meta['source']}#p{page_no}c{index}",
                    }
                    fh.write(json.dumps(record, ensure_ascii=False) + "\n")
                    count += 1
    return count


def upload(local: Path, key: str) -> None:
    """Upload to the bucket. Credentials come from the environment, never from code."""
    import boto3

    s3 = boto3.client(
        "s3",
        endpoint_url=os.environ["NEBIUS_S3_ENDPOINT"],          # VERIFY the endpoint for your region
        aws_access_key_id=os.environ["NEBIUS_S3_ACCESS_KEY"],
        aws_secret_access_key=os.environ["NEBIUS_S3_SECRET_KEY"],
    )
    s3.upload_file(str(local), os.environ["NEBIUS_BUCKET"], key)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--src", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--upload", action="store_true", help="upload the output to chunks/ in the bucket")
    args = parser.parse_args()

    total = ingest(args.src, args.out)
    print(f"wrote {total} chunks to {args.out}")

    if args.upload:
        upload(args.out, f"chunks/{args.out.name}")
        print("uploaded to bucket")


if __name__ == "__main__":
    main()
