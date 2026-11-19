// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

/// Fixture helpers for tests that spawn a real child through `ProcessCLITransport`.
///
/// The fixtures are `/bin/sh` scripts that call only absolute-path system tools. They used to be
/// `#!/usr/bin/python3` scripts: on macOS that is the xcrun shim, which resolves the developer toolchain and then
/// starts a full interpreter. Under an empty environment on a loaded compile Mac that start-up alone took longer than
/// the 10 s production timeout of `consent --json` and `publication --json --offline`, so the tests failed with
/// `timeout` before the child had printed anything (mac-compile runs 44526295009 and 44552055119).
enum SubprocessFixture {
    /// Tests that are not about the timeout pass this instead of the production per-command timeout, so a slow child
    /// start on a loaded host cannot turn into a false failure. It stays bounded so a hung child still fails the test.
    static let generousTimeout: TimeInterval = 60

    /// Prints its argv as a JSON string array. Arguments are fixed CLI words; anything that would need JSON escaping
    /// makes the fixture fail (exit 70) instead of printing something that could decode to a different array.
    static let printArgv = """
    print_argv() {
      out='['; sep=''
      for a in "$@"; do
        case $a in *'"'*|*'\\'*) exit 70;; esac
        out="$out$sep\\"$a\\""; sep=','
      done
      printf '%s]\\n' "$out"
    }
    """

    /// Writes `#!/bin/sh` + `body` to a fresh private directory and returns the executable. The caller removes
    /// `url.deletingLastPathComponent()`.
    static func write(_ name: String, body: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let file = root.appendingPathComponent(name)
        try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return file
    }

    /// The argv fixture: prints its arguments as JSON.
    static func argv(_ name: String = "argv-fixture") throws -> URL {
        try write(name, body: printArgv + "\nprint_argv \"$@\"")
    }
}
