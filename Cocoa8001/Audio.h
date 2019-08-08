#ifndef _AUDIO_H_
#define _AUDIO_H_

typedef void (*AudioCallback)(float *buffer, int numSamples);

void AudioSetup(AudioCallback func);
void AudioStart();
void AudioStop();

#endif
