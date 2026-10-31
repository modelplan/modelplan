// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

// R2: no credential backend exists in this executable. It cannot import a reader,
// accept a backend switch, or return token material. One generated request per child.
DispatchQueue.global().asyncAfter(deadline: .now() + 5) { exit(70) }
do {
    guard CommandLine.arguments.count == 1 else { exit(64) }
    var bytes = Data()
    while let chunk = try FileHandle.standardInput.read(upToCount: 4096), !chunk.isEmpty {
        guard bytes.count + chunk.count <= 65536 else { exit(64) }
        bytes.append(chunk)
    }
    let request = try JSONDecoder().decode(WireCredentialRequest.self, from: bytes)
    let result = try WireCredentialResult(operationId: request.operationId, outcome: .denied)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    var reply = try encoder.encode(result); reply.append(10)
    try FileHandle.standardOutput.write(contentsOf: reply)
} catch {
    // No raw request, decoder error, stderr or environment value is echoed.
    exit(64)
}
