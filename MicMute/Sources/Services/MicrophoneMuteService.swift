import CoreAudio

enum MicrophoneState: Equatable {
    case muted
    case live
    case unavailable(String)
}

struct MicrophoneMuteService {
    func state() -> MicrophoneState {
        guard let device = defaultInputDevice() else {
            return .unavailable("No default microphone found")
        }

        var address = muteAddress()
        guard AudioObjectHasProperty(device, &address) else {
            return .unavailable("This microphone has no mute control")
        }

        var settable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
              settable.boolValue else {
            return .unavailable("This microphone cannot be muted")
        }

        var muted: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let result = AudioObjectGetPropertyData(device, &address, 0, nil, &dataSize, &muted)
        guard result == noErr else {
            return .unavailable("Could not read microphone state (\(result))")
        }
        return muted == 0 ? .live : .muted
    }

    func toggle() -> MicrophoneState {
        let current = state()
        guard current == .live || current == .muted,
              let device = defaultInputDevice() else {
            return current
        }

        var address = muteAddress()
        var nextValue: UInt32 = current == .live ? 1 : 0
        let dataSize = UInt32(MemoryLayout<UInt32>.size)
        let result = AudioObjectSetPropertyData(device, &address, 0, nil, dataSize, &nextValue)
        guard result == noErr else {
            return .unavailable("Could not change microphone mute (\(result))")
        }

        let updated = state()
        guard updated != current else {
            return .unavailable("Mute change was not confirmed")
        }
        return updated
    }

    private func defaultInputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &device
        )
        return result == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
