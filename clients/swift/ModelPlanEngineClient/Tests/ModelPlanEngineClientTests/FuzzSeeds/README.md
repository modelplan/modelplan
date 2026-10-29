<!-- SPDX-License-Identifier: MIT -->
# Swift decoder crash seeds

Both minimized inputs are seven bytes and were found by the capture-seeded
mutation campaign on Linux Swift 6.0.3:

- `invalid-utf8-dictionary-key.bin`: a JSON key containing byte FF.
- `unescaped-control-dictionary-key.bin`: a JSON key containing a literal tab.

Before their guards, both trap Foundation's dictionary decoder instead of
throwing. The second is valid UTF-8, so UTF-8 validation alone is insufficient.
WireDecoder and IncomingFrame replay both. The framer already rejects invalid
UTF-8; JSON syntax validation is the decoder's responsibility. These synthetic
fixtures contain no user data.
