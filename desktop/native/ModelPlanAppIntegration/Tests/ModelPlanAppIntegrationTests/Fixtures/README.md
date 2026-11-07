<!-- SPDX-License-Identifier: MIT -->
# Recorded consent contract

`consent-v0.5.43-synthetic.json` is unmodified stdout captured from the reviewed native CLI v0.5.43 with an independent synthetic HOME, owner-home/network denial and all readers off. It contains one Codex metadata record, not a multi-tool or owner-account observation. The app tests replay these bytes through the production decoder and Settings backend without executing a helper. The current-release capture provenance must match the native archive pin; historical captures retain their original version.

Multi-tool, free-label and structured host cases are separate synthetic tests; they are not represented as additional captured output.

v0.5.53 is the current native pin; its complete synthetic capture is additive. v0.5.43, v0.5.45, v0.5.46, v0.5.48, v0.5.49 and v0.5.52 remain unchanged historical compatibility inputs. All captures deny owner-home/network access and disable all readers.

The v0.5.48 capture is unmodified stdout from the checksum-verified ordinary `linux_arm64` release at commit `146e959668955d90337ce764b1be39c06456674d`. Its provenance distinguishes the Linux archive checksum and inner executable hash from the two Darwin hashes used for native bundle admission. A disposable HOME contains only a synthetic Codex presence configuration, with empty executable PATH, separate cache/TMPDIR and all reader/history/account/helper switches off. Linux Landlock ABI 4 allows file reads only in that HOME and the verified executable; seccomp denies network syscalls. Outside-directory read and network-socket probes failed before executing the CLI. The resulting Claude/Codex records are consent metadata, not account readings or provider observations; no owner HOME, credentials, Keychain or network was used.

The v0.5.49 capture uses the same isolated Linux arm64 recipe and unmodified stdout, from the repository-tooling-verified release at commit `4011d78d81803d82c7e86a35feebdb2d44cbf364`. Both denial probes passed before exec. Its archive, inner executable and output hashes were computed with the repository release/identity tools; the historical v0.5.48 capture and provenance are unchanged.

The v0.5.52 capture is unmodified stdout from the verified published Linux arm64 archive at commit `b53b251a31162ee019b455ffb7ec7cb01b476018`. Landlock ABI 4 admitted only the synthetic HOME and released executable; explicit outside-directory and socket probes confirmed denial before exec. Readers and history were off. The archive, inner executable and output hashes are recorded in its provenance.

The v0.5.53 capture is unmodified stdout from the verified published Linux arm64 archive at commit `c0d358da89e5669515dbaf930e54e271b7192c81`, with the same recipe and explicit denial probes before exec. The same harness first reproduced the recorded v0.5.52 output byte for byte from the v0.5.52 binary. The v0.5.53 output is byte-identical to v0.5.52: the capture is taken with readers off, so the v0.5.53 default-on change does not appear in it.
