// SPDX-License-Identifier: MIT
// Offline only: compile with U6ReadingFingerprint.swift and ModelPlanWire objects.
// No App entry, AppKit initialization, GUI, permission lookup or provider execution.
import Foundation
import ModelPlanWire
let data=FileHandle.standardInput.readDataToEndOfFile()
let accounts=try JSONDecoder().decode([RowsAccount].self,from:data)
print(try U6ReadingFingerprint.sha256(accounts))
