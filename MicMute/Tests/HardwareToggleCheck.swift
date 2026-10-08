import CoreAudio
import Foundation

// Explicit opt-in hardware test; never part of the normal test script.
@main
enum HardwareToggleCheck {
    static func inputDevicesAreIdle() -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return false }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else { return false }
        for device in devices {
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var bufferSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &bufferSize) == noErr, bufferSize > 0 else { return false }
            let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(bufferSize), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { memory.deallocate() }
            guard AudioObjectGetPropertyData(device, &streams, 0, nil, &bufferSize, memory) == noErr else { return false }
            let buffers = UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to: AudioBufferList.self))
            guard buffers.contains(where: { $0.mNumberChannels > 0 }) else { continue }
            var runningAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            guard AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &runningSize, &running) == noErr, running == 0 else { return false }
        }
        return true
    }

    static func main() {
        guard CommandLine.arguments.contains("--confirm-idle") else {
            print("Run explicitly with --confirm-idle only when no call/recording is in progress.")
            exit(2)
        }
        guard inputDevicesAreIdle() else {
            print("SKIP: input-capable audio device active or unreadable; no audio writes")
            exit(2)
        }
        var deviceAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &size, &device) == noErr, device != 0 else { exit(2) }
        var muteAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var original: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &original) == noErr else { exit(2) }
        let service = MicrophoneMuteService()
        let initial: MicrophoneState = original == 0 ? .live : .muted
        guard inputDevicesAreIdle() else { exit(2) }
        var passed = false
        do {
            defer {
                var current: UInt32 = 0
                size = UInt32(MemoryLayout<UInt32>.size)
                if AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &current) != noErr || current != original {
                    let result = AudioObjectSetPropertyData(device, &muteAddress, 0, nil, size, &original)
                    if result != noErr { print("FAIL: restoring original mute state failed (\(result))") }
                }
            }
            let toggled = service.toggle(device: device)
            let expected: MicrophoneState = initial == .live ? .muted : .live
            print("original=\(initial) toggled=\(toggled)")
            if toggled == expected {
                let restored = service.toggle(device: device)
                print("restored=\(restored)")
                passed = restored == initial
            }
        }
        var final: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        let readResult = AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &final)
        passed = passed && readResult == noErr && final == original
        print(passed ? "PASS: real hardware transition and original state restored" : "FAIL: hardware transition check; restoration attempted")
        exit(passed ? 0 : 1)
    }
}
