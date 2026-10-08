import CoreAudio
import Foundation
var deviceAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var device = AudioDeviceID(kAudioObjectUnknown)
var size = UInt32(MemoryLayout<AudioDeviceID>.size)
let lookup = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &size, &device)
print("defaultInputLookup=\(lookup) deviceID=\(device)")
if lookup == noErr && device != kAudioObjectUnknown {
 var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
 let hasMute = AudioObjectHasProperty(device, &address)
 var settable = DarwinBoolean(false)
 let settableStatus = hasMute ? AudioObjectIsPropertySettable(device, &address, &settable) : -1
 var muted: UInt32 = 0
 size = UInt32(MemoryLayout<UInt32>.size)
 let readStatus = hasMute ? AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) : -1
 print("hasMute=\(hasMute) isSettable=\(settable.boolValue) settableStatus=\(settableStatus) readStatus=\(readStatus)")
 if readStatus == noErr { print("muteValue=\(muted) state=\(muted == 0 ? "live" : "muted")") }
}
