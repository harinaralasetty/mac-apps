from pathlib import Path
source=(Path(__file__).resolve().parents[1] / 'MicMute/Sources/Services/MicrophoneMuteService.swift').read_text()
prefix='''import Foundation
 typealias AudioDeviceID = UInt32
 typealias AudioObjectID = UInt32
 struct AudioObjectPropertyAddress { var mSelector: UInt32; var mScope: UInt32; var mElement: UInt32 }
 let noErr: Int32 = 0
 let kAudioHardwarePropertyDefaultInputDevice: UInt32 = 1
 let kAudioObjectPropertyScopeGlobal: UInt32 = 2
 let kAudioObjectPropertyElementMain: UInt32 = 3
 let kAudioObjectUnknown: UInt32 = 0
 let kAudioObjectSystemObject: UInt32 = 4
 let kAudioDevicePropertyMute: UInt32 = 5
 let kAudioDevicePropertyScopeInput: UInt32 = 6
 var available = true, hasMute = true, settable = true, writeApplies = true
 var readResult: Int32 = 0, writeResult: Int32 = 0, settableResult: Int32 = 0
 var muteValue: UInt32 = 0, writes = 0
 var defaultSequence: [UInt32] = []
 func AudioObjectHasProperty(_ id: UInt32, _ address: UnsafeMutablePointer<AudioObjectPropertyAddress>) -> Bool { hasMute }
 func AudioObjectIsPropertySettable(_ id: UInt32, _ address: UnsafeMutablePointer<AudioObjectPropertyAddress>, _ value: UnsafeMutablePointer<DarwinBoolean>) -> Int32 { value.pointee = DarwinBoolean(settable); return settableResult }
 func AudioObjectGetPropertyData(_ id: UInt32, _ address: UnsafeMutablePointer<AudioObjectPropertyAddress>, _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?, _ size: UnsafeMutablePointer<UInt32>, _ value: UnsafeMutableRawPointer) -> Int32 {
  if address.pointee.mSelector == kAudioHardwarePropertyDefaultInputDevice {
   let next = defaultSequence.isEmpty ? (available ? UInt32(85) : UInt32(0)) : defaultSequence.removeFirst()
   value.storeBytes(of: next, as: UInt32.self); return 0
  }
  value.storeBytes(of: muteValue, as: UInt32.self); return readResult
 }
 func AudioObjectSetPropertyData(_ id: UInt32, _ address: UnsafeMutablePointer<AudioObjectPropertyAddress>, _ qualifierSize: UInt32, _ qualifier: UnsafeRawPointer?, _ size: UInt32, _ value: UnsafeRawPointer) -> Int32 {
  writes += 1
  if writeResult == 0 && writeApplies { muteValue = value.load(as: UInt32.self) }
  return writeResult
 }
 func reset() { available = true; hasMute = true; settable = true; writeApplies = true; readResult = 0; writeResult = 0; settableResult = 0; muteValue = 0; writes = 0; defaultSequence = [] }
 func check(_ name: String, _ condition: Bool) { if !condition { fatalError(name) }; print("PASS " + name) }
 let service = MicrophoneMuteService()
'''
tests='''
 reset(); check("read live performs no writes", service.state() == .live && writes == 0)
 reset(); muteValue = 1; check("read muted performs no writes", service.state() == .muted && writes == 0)
 reset(); available = false; check("missing device rejects toggle", service.toggle() == .unavailable("No default microphone found") && writes == 0)
 reset(); hasMute = false; check("missing control rejects toggle", service.toggle() == .unavailable("This microphone has no mute control") && writes == 0)
 reset(); settable = false; check("read-only control rejects toggle", service.toggle() == .unavailable("This microphone cannot be muted") && writes == 0)
 reset(); settableResult = -3; check("settable query error rejects toggle", service.toggle() == .unavailable("This microphone cannot be muted") && writes == 0)
 reset(); readResult = -4; check("read error rejects toggle", service.toggle() == .unavailable("Could not read microphone state (-4)") && writes == 0)
 reset(); check("fake live-to-muted verified", service.toggle() == .muted && writes == 1 && muteValue == 1)
 reset(); muteValue = 1; check("fake muted-to-live verified", service.toggle() == .live && writes == 1 && muteValue == 0)
 reset(); writeResult = -5; check("write failure reported", service.toggle() == .unavailable("Could not change microphone mute (-5)") && writes == 1 && muteValue == 0)
 reset(); writeApplies = false; check("unconfirmed write reported", service.toggle() == .unavailable("Mute change was not confirmed") && writes == 1 && muteValue == 0)
 reset(); defaultSequence = [85, 86]; check("default input change rejects toggle without a write", service.toggle() == .unavailable("Default microphone changed; try again") && writes == 0)
 print("12/12 fake-backend checks passed; no real audio APIs linked or invoked")
'''
import subprocess, tempfile
with tempfile.TemporaryDirectory(prefix='micmute-tests-') as folder:
    test_source = Path(folder) / 'main.swift'
    test_source.write_text(prefix + source.replace('import CoreAudio', '') + tests)
    binary = Path(folder) / 'tests'
    subprocess.run(['swiftc', str(test_source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
