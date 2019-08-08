// simple audio API for OS X 10.4-

#include "Audio.h"

static bool playing;
static AudioDeviceID device;
static UInt32 bufferSize;
static AudioStreamBasicDescription format;
static AudioCallback callback;

static OSStatus proc(AudioDeviceID, const AudioTimeStamp *, const AudioBufferList *, const AudioTimeStamp *, AudioBufferList *outOutputData, const AudioTimeStamp *, void *) {
	if (callback) callback((float *)outOutputData->mBuffers[0].mData, bufferSize / format.mBytesPerFrame);
	return noErr;
}

static OSStatus prop(AudioObjectID objID, AudioObjectPropertySelector sel, int _len, void *outData) {
	AudioObjectPropertyAddress pa;
	pa.mSelector = sel;
	pa.mScope = kAudioDevicePropertyScopeOutput;
	pa.mElement = 0;
	UInt32 len = _len;
	return AudioObjectGetPropertyData(objID, &pa, 0, NULL, &len, outData);
}

void AudioSetup(AudioCallback func) {
	if (prop(kAudioObjectSystemObject, kAudioHardwarePropertyDefaultOutputDevice, sizeof(device), &device) != noErr) return;
	if (prop(device, kAudioDevicePropertyBufferSize, sizeof(bufferSize), &bufferSize) != noErr) return;
	if (prop(device, kAudioDevicePropertyStreamFormat, sizeof(format), &format) != noErr) return;
	if (format.mFormatID != kAudioFormatLinearPCM) return;
	if (!(format.mFormatFlags & kLinearPCMFormatFlagIsFloat)) return;
	callback = func;
}

void AudioStart() {
	if (!callback || playing) return;
	AudioDeviceIOProcID procID;
	if (AudioDeviceCreateIOProcID(device, proc, NULL, &procID) != noErr) return;
	if (AudioDeviceStart(device, proc) != noErr) return;
	playing = true;
}

void AudioStop() {
	if (!callback || !playing) return;
	if (AudioDeviceStop(device, proc) != kAudioHardwareNoError) return;
	if (AudioDeviceDestroyIOProcID(device, proc) != kAudioHardwareNoError) return;
	playing = false;
}

