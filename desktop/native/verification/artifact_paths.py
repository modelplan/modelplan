# SPDX-License-Identifier: MIT
"""Reserved macOS transport metadata is never a verification artifact."""
from pathlib import Path

def is_appledouble(path):
    """Ignore ._* basenames, including descendants of a metadata directory.

    This is a name rule, not a decoder-error fallback: corrupt ordinary artifacts
    still fail their existing validation. No file content is read to classify it.
    """
    return any(part.startswith('._') for part in Path(path).parts)
