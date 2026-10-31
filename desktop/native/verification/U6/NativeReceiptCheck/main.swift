// SPDX-License-Identifier: MIT
// Offline fixture capture only. It never initializes NSApplication or invokes the App.
import Foundation
let input=FileHandle.standardInput.readDataToEndOfFile()
guard let rows=try JSONSerialization.jsonObject(with:input) as? [[String:Any]] else { fatalError("fixture-array-required") }
for row in rows {
    guard let event=row["kind"] as? String,let run=row["runID"] as? String,let epoch=row["epoch"] as? String,
          let pid=row["pid"] as? Int32,let seq=row["seq"] as? UInt64,let mono=row["mono"] as? Double,
          let at=row["at"] as? Double else { fatalError("fixture-envelope-required") }
    var fields=row
    for key in ["runID","epoch","pid","seq","mono","at"] { fields.removeValue(forKey:key) }
    if event != "refresh" { fields.removeValue(forKey:"kind") }
    let data=try U6NativeReceiptSerializer.encode(event:event,fields:fields,runID:run,epoch:epoch,pid:pid,seq:seq,mono:mono,at:at)
    try FileHandle.standardOutput.write(contentsOf:data)
}
