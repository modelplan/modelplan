// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
  import AppKit
  import ApplicationServices
  import Foundation

  struct StatusMenuSelection: Decodable {
    let itemName: String, statusItemIdentifier: String?, arrivals: String
    let openMenu: Bool, timeoutSeconds: Double
    let request: StatusMenuActionRequest
  }
  struct StatusMenuDrivePlan: Decodable {
    let pointer: PointerPlan
    let selection: StatusMenuSelection
    enum CodingKeys: String, CodingKey { case statusMenu }
    init(from decoder: Decoder) throws {
      pointer = try PointerPlan(from: decoder)
      selection = try decoder.container(keyedBy: CodingKeys.self).decode(
        StatusMenuSelection.self, forKey: .statusMenu)
    }
  }
  @MainActor enum StatusMenuDrive {
    static func validate(_ plan: StatusMenuDrivePlan, now: Double) throws {
      let p = plan.pointer
      let s = plan.selection
      let r = s.request
      guard p.profile == "synthetic", p.subjectPID > 0, p.runID == r.runID, p.epoch == r.epoch,
        p.subjectPID == r.subjectPID,
        p.steps.isEmpty, p.allowedRectangles.isEmpty, !s.itemName.isEmpty,
        s.itemName.utf16.count <= 128,
        !s.itemName.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
        s.timeoutSeconds.isFinite, (0.1...10).contains(s.timeoutSeconds), s.arrivals != p.output
      else { throw StatusMenuError.invalidRequest }
      try r.validate(now: now)
    }
    static func selfTest() throws {
      let object: [String: Any] = [
        "profile": "synthetic", "runID": "run", "epoch": "epoch", "lease": "unused",
        "stop": "unused", "output": "out",
        "subjectPID": 42, "subjectBundle": "unused", "allowedRectangles": [], "steps": [],
        "statusMenu": [
          "itemName": "Refresh / 刷新", "openMenu": true, "timeoutSeconds": 5,
          "arrivals": "arrivals",
          "request": [
            "profile": "synthetic", "runID": "run", "epoch": "epoch", "subjectPID": 42,
            "requestID": UUID().uuidString, "action": "refresh", "notBefore": 1000,
            "expiresAt": 1100,
          ],
        ],
      ]
      func decode(_ value: [String: Any]) throws -> StatusMenuDrivePlan {
        try JSONDecoder().decode(
          StatusMenuDrivePlan.self, from: JSONSerialization.data(withJSONObject: value))
      }
      try validate(decode(object), now: 1005)
      for change: (String, Any) in [
        ("subjectPID", 43), ("profile", "owner"), ("runID", "other"),
        ("allowedRectangles", [[0, 0, 100, 100]]),
      ] {
        var invalid = object
        invalid[change.0] = change.1
        do {
          try validate(decode(invalid), now: 1005)
          preconditionFailure("invalid menu correlation admitted")
        } catch StatusMenuError.invalidRequest {}
      }
    }
    static func execute(_ plan: StatusMenuDrivePlan, file: FileHandle) throws {
      try validate(plan, now: Date().timeIntervalSince1970)
      let p = plan.pointer
      let s = plan.selection
      let r = s.request
      try PointerDrive.live(p)
      guard AXIsProcessTrusted() else { throw StatusMenuError.unsupported }  // Never prompts.
      let path = URL(fileURLWithPath: s.arrivals)
      let attributes = try path.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else {
        throw StatusMenuError.invalidRequest
      }
      let input = try FileHandle(forReadingFrom: path)
      defer { try? input.close() }
      _ = try input.seekToEnd()  // Older receipt rows cannot prove this operation.
      let tree = NativeStatusMenuTree()
      let extras = try tree.extras(subjectPID: p.subjectPID)
      let status = try StatusMenuLocator.statusItem(
        tree: tree, extras: extras, subjectPID: p.subjectPID, identifier: s.statusItemIdentifier)
      let deadline = ProcessInfo.processInfo.systemUptime + s.timeoutSeconds
      if s.openMenu {
        try PointerDrive.live(p)
        _ = try tree.press(status)
      }
      var item: NativeMenuElement?
      repeat {
        try PointerDrive.live(p)
        do {
          item = try StatusMenuLocator.item(
            tree: tree, statusItem: status, subjectPID: p.subjectPID, name: s.itemName)
        } catch StatusMenuError.notFound {
          Thread.sleep(forTimeInterval: 0.02)
        } catch StatusMenuError.unsupported { Thread.sleep(forTimeInterval: 0.02) }
      } while item == nil && ProcessInfo.processInfo.systemUptime < deadline
      guard let item else { throw StatusMenuError.notFound }
      try PointerDrive.append(
        [
          "event": "status-menu-item-located", "runID": p.runID, "epoch": p.epoch,
          "subjectPID": p.subjectPID, "requestID": r.requestID.uuidString,
          "actionID": r.action.rawValue, "locator": "owned-AXExtrasMenuBar",
        ], to: file)
      try PointerDrive.live(p)
      try r.validate(now: Date().timeIntervalSince1970)
      let sent = ProcessInfo.processInfo.systemUptime
      let accepted = try tree.press(item)
      try PointerDrive.append(
        [
          "event": "status-menu-press-requested", "runID": p.runID, "epoch": p.epoch,
          "subjectPID": p.subjectPID, "requestID": r.requestID.uuidString,
          "actionID": r.action.rawValue, "inputKind": "AXPress", "transportAccepted": accepted,
          "arrivalProof": "requires-native-receipt",
        ], to: file)
      var buffer = Data()
      var total = 0
      while ProcessInfo.processInfo.systemUptime < deadline {
        try PointerDrive.live(p)
        if let bytes = try input.read(upToCount: 8192), !bytes.isEmpty {
          total += bytes.count
          buffer.append(bytes)
          guard total <= 1_048_576, buffer.count <= 65536 else { throw StatusMenuError.limit }
          while let newline = buffer.firstIndex(of: 10) {
            let row = buffer.prefix(upTo: newline)
            buffer.removeSubrange(...newline)
            if let object = (try? JSONSerialization.jsonObject(with: row)) as? [String: Any],
              StatusMenuArrivalReceipt.matches(
                object, request: r, afterUptime: sent,
                nowUptime: ProcessInfo.processInfo.systemUptime)
            {
              try PointerDrive.append(
                [
                  "event": "status-menu-result", "outcome": "arrived", "runID": p.runID,
                  "epoch": p.epoch, "subjectPID": p.subjectPID, "requestID": r.requestID.uuidString,
                  "actionID": r.action.rawValue, "arrivalProof": "native-NSMenu.didSendAction",
                ], to: file)
              return
            }
          }
        }
        Thread.sleep(forTimeInterval: 0.02)
      }
      throw StatusMenuError.arrivalTimeout
    }
    static func entry(path: String) throws {
      let data = try Data(contentsOf: URL(fileURLWithPath: path))
      guard data.count <= 32768 else { throw StatusMenuError.limit }
      let plan = try JSONDecoder().decode(StatusMenuDrivePlan.self, from: data)
      let output = URL(fileURLWithPath: plan.pointer.output)
      guard !FileManager.default.fileExists(atPath: output.path),
        FileManager.default.createFile(
          atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600])
      else { throw StatusMenuError.invalidRequest }
      let file = try FileHandle(forWritingTo: output)
      defer { try? file.close() }
      do { try execute(plan, file: file) } catch {
        try PointerDrive.append(
          [
            "event": "status-menu-result", "outcome": "not-run",
            "reason": "owned-menu-unavailable-or-no-native-arrival",
          ], to: file)
        throw error
      }
    }
  }
#endif
