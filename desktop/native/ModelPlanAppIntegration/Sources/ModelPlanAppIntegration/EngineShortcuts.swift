// SPDX-License-Identifier: MIT
import Carbon.HIToolbox
import Foundation
import ModelPlanSettings

/// Global shortcuts (D37: none by default). The registrar reports the exact chord's outcome,
/// which Settings shows; nothing is assumed registered before macOS answers.
@MainActor protocol EngineShortcutRegistering: AnyObject {
    var onPress: ((ShortcutAction) -> Void)? { get set }
    func register(_ chord: ShortcutChord, action: ShortcutAction) -> ShortcutRegistration
    func unregisterAll()
}

private let hotKeySignature: OSType = 0x4D50_5343 // "MPSC"
private let hotKeyHandler: EventHandlerUPP = { _, event, userData in
    var id = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                   MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr, id.signature == hotKeySignature, let userData else { return OSStatus(eventNotHandledErr) }
    let address = UInt(bitPattern: userData), number = id.id
    Task { @MainActor in
        guard let pointer = UnsafeRawPointer(bitPattern: address) else { return }
        Unmanaged<CarbonShortcutRegistrar>.fromOpaque(pointer).takeUnretainedValue().pressed(number)
    }
    return noErr
}

@MainActor final class CarbonShortcutRegistrar: EngineShortcutRegistering {
    var onPress: ((ShortcutAction) -> Void)?
    private var handlerInstalled = false
    private var registered: [UInt32: (ref: EventHotKeyRef, action: ShortcutAction)] = [:]
    private var nextID: UInt32 = 1

    func register(_ chord: ShortcutChord, action: ShortcutAction) -> ShortcutRegistration {
        guard let code = Self.keyCode(chord.key), installHandler() else { return .unavailable }
        var ref: EventHotKeyRef?
        let id = nextID; nextID &+= 1
        let status = RegisterEventHotKey(code, Self.modifiers(chord), EventHotKeyID(signature: hotKeySignature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        if status == OSStatus(eventHotKeyExistsErr) { return .conflict }
        guard status == noErr, let ref else { return .unavailable }
        registered[id] = (ref, action)
        return .registered
    }
    func unregisterAll() {
        for item in registered.values { UnregisterEventHotKey(item.ref) }
        registered = [:]
    }
    fileprivate func pressed(_ id: UInt32) {
        if let action = registered[id]?.action { onPress?(action) }
    }
    private func installHandler() -> Bool {
        guard !handlerInstalled else { return true }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // The registrar lives as long as the app, so the unretained pointer stays valid.
        handlerInstalled = InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &type,
                                               Unmanaged.passUnretained(self).toOpaque(), nil) == noErr
        return handlerInstalled
    }
    static func modifiers(_ chord: ShortcutChord) -> UInt32 {
        var value: UInt32 = 0
        if chord.modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if chord.modifiers.contains(.control) { value |= UInt32(controlKey) }
        if chord.modifiers.contains(.option) { value |= UInt32(optionKey) }
        if chord.modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }
    static func keyCode(_ key: String) -> UInt32? { keyCodes[key].map(UInt32.init) }
    private static let keyCodes: [String: Int] = [
        "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D, "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G,
        "H": kVK_ANSI_H, "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L, "M": kVK_ANSI_M, "N": kVK_ANSI_N,
        "O": kVK_ANSI_O, "P": kVK_ANSI_P, "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T, "U": kVK_ANSI_U,
        "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X, "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    ]
}
