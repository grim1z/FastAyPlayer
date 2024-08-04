#include <stdio.h>
#include <math.h>
#include <string.h>
#include <algorithm> 

#include "YmData.h"
#include "Lzss.h"

#define _DIST_MAX 100000

//
// Smooth envelope registers.
//
void YmData::FixHoles()
{
	// Some YM exports can insert zeroes in registers R11 / R12 / R13 when bit 4 is
	// not set in volume control registers. This could decrease the quality of the
	// compression routine.

	uint8_t* r8 = GetRegister(8);
	uint8_t* r9 = GetRegister(9);
	uint8_t* r10 = GetRegister(10);
	uint8_t* r11 = GetRegister(11);
	uint8_t* r12 = GetRegister(12);
	uint8_t* r13 = GetRegister(13);
	for (int i = 1; i < nbFrames; i++)
	{
		if (((r8[i] & 0x10) == 0) &&
			((r9[i] & 0x10) == 0) &&
			((r10[i] & 0x10) == 0))
		{
			r11[i] = r11[i - 1];
			r12[i] = r12[i - 1];
			r13[i] = r13[i - 1];
		}
	}
}

//
// Backup registers first frame value for future use.
//
void YmData::BackupInitValue()
{
	for (int r = 0; r < NR_YM_REGISTERS; r++)
	{
		initValues[r] = pRegisters[r][0];
	}
	initValues[7] = 0x3F;
	initValues[8] = 0;
	initValues[9] = 0;
	initValues[10] = 0;
}

//
// Check if the R12 register is constant.
//
void YmData::CheckR12IsConstant()
{
	R12IsConstant = true;

	for (int f = 0; f < nbFrames; f++)
	{
		if (pRegisters[12][f] != pRegisters[12][0])
		{
			R12IsConstant = false;
			break;
		}
	}
}

//
//
//
void YmData::SmoothRegisters(uint8_t* periodLow, uint8_t* periodHigh, uint8_t* volume, int voice)
{
	uint8_t* mixer = pRegisters[7];

	int voiceToneMask = 1 << (voice - 1);
	int voiceNoiseMask = voiceToneMask << 3;

	for (int i = 1; i < nbFrames; i++)
	{
		int curVol = volume[i] & 0x0F;
		int prevVol = volume[i - 1] & 0x0F;
		int volMode = volume[i] & 0x10;
		bool toneOff = (mixer[i] & voiceToneMask) == voiceToneMask;
		bool noiseOff = (mixer[i] & voiceNoiseMask) == voiceNoiseMask;

		// Smooth Period if volume is 0 or tone if off.
		if (volume[i] == 0 || toneOff)
		{
			periodLow[i] = periodLow[i - 1];
			periodHigh[i] = periodHigh[i - 1];
		}

		// Smooth volume if tone is off
		// In this case, volume is not used by the PSG.
		if (toneOff && noiseOff)
			volume[i] = volMode | prevVol;
	}
}

//
// Switch all 1 to 0 for period low byte.The 1 value will later be use to mark a "delta-play".
//
void YmData::FixPeriodLow(uint8_t* periodLow)
{
	for (int i = 0; i < nbFrames; i++)
		// 0 and 1 encode the same value. Smooth all 1 to 0.
		if (periodLow[i] == 1)
		{
			periodLow[i] = 0;
		}
}

//
// Smooth noise register when noise is off on every channels
//
void YmData::SmoothNoise()
{
	uint8_t* noise = pRegisters[6];
	uint8_t* mixer = pRegisters[7];

	for (int i = 1; i < nbFrames; i++)
	{
		bool noiseOff = (mixer[i] & 0b00111000) == 0b00111000;
		if (noiseOff)
			noise[i] = noise[i - 1];
	}
}

//
// Merge two 4 bits registers into one register.
//
void YmData::MergeRegisters(uint8_t* R1, uint8_t* R2)
{
	for (int i = 0; i < nbFrames; i++)
	{
		R1[i] = ((R2[i] & 0x0f) << 4) | (R1[i] & 0x0f);
	}
}

//
// Add delta-play flags for registers 6 and 13 in the register 5.
//
void YmData::AdjustR6andR13()
{
	uint8_t* R5 = pRegisters[5];
	uint8_t* R6 = pRegisters[6];
	uint8_t* R13 = pRegisters[13];

	for (int i = 1; i < nbFrames; i++)
	{
		if (R5[i] == R5[i - 1])
		{
			R6[i] = R6[i] | 0x20; // TODO: ajouter une macro
		}
	}

	for (int i = 0; i < nbFrames; i++)
	{
		if (R13[i] == 0xFF)
		{
			R6[i] = R6[i] | 0x40; // TODO: ajouter une macro
			R13[i] = R13[i - 1];   // TODO: this line is probably useless... Check this.
		}
	}
}

//
//Insert markers for repeating value(used to quickly avoid to program a register)
//
void YmData::PrecaclDeltaPlay(int regId, int markerValue)
{
	uint8_t* registerData = pRegisters[regId];
	uint8_t initVal = registerData[nbFrames - 1];
	uint8_t prevVal = initVal;

	for (int f = 0; f < nbFrames; f++)
	{
		bool deltaPlay = true;

		if (registerData[f] != prevVal)
		{
			deltaPlay = false;
		}

		// Special case for 1st mixer and volume values.Avoid a delta - play since the mixer and volume are forced to mute in init values.
		if ((f == 0) &&
			(regId >= 7) &&
			(regId <= 10))
		{
			deltaPlay = false;
		}

		// Special case for a non 0 loop frame.The current value must also be equal to the one in last frame to enable delta - play.
		if (GetLoopFrame() != 0 &&
			GetLoopFrame() == f &&
			registerData[f] != initVal)
		{
			deltaPlay = false;
		}

		if (deltaPlay)
		{
			registerData[f] = markerValue;
		}
		else
		{
			prevVal = registerData[f];
		}
	}
}

///////////////////////////////////////////////////////////////////////////////////
//
// Delay register programming
//
///////////////////////////////////////////////////////////////////////////////////

//
//Compute the distance between the current register value and the previous value
//
int YmData::DistFromPrevValue(uint8_t* registerData, int current, int next, uint8_t markerValue, bool volumeRegister)
{
	int start = 0;

	if (registerData[current] == markerValue)
	{
		return _DIST_MAX;
	}
	if (volumeRegister and ((registerData[current] & 0x80) == (registerData[next] & 0x80)))
	{
		return _DIST_MAX;
	}

	if (current == 0)
	{
		start = nbFrames - 1;
	}
	else
	{
		start = current - 1;
	}

	for (int i = start; i > 0; i--)
	{
		if (registerData[i] != markerValue)
		{
			return abs(registerData[i] - registerData[current]);
		}
	}

	return _DIST_MAX;
}

//
// Delay one register programming to the next frame.
//
int YmData::DelayOneRegister(int current, int next)
{
	uint8_t RegisterMapping[] = { 0, 2, 4, 11, 8, 9, 10 };
	int Distance[sizeof(RegisterMapping)];

	for (int i = 0; i < sizeof(RegisterMapping); i++)
	{
		Distance[i] = _DIST_MAX;
	}

	for (int i = 0; i < 4; i++)
	{
		int regId = RegisterMapping[i];
		Distance[i] = DistFromPrevValue(pRegisters[regId], current, next, 1, false);
	}

	for (int i = 4; i < sizeof(RegisterMapping); i++)
	{
		int regId = RegisterMapping[i];
		Distance[i] = DistFromPrevValue(pRegisters[regId], current, next, 0xF4, true) * 8;
	}

	// Find the register hosting the minimal distance for the current frame.
	uint8_t* selectedReg = nullptr;
	int MinValue = _DIST_MAX;
	uint8_t replayVal;
	for (int i = 0; i < sizeof(RegisterMapping); i++)
	{
		if (Distance[i] < MinValue)
		{
			int regId = RegisterMapping[i];
			selectedReg = pRegisters[regId];
			MinValue = Distance[i];

			if (i < 4)
			{
				replayVal = 1;
			}
			else
			{
				replayVal = 0xF4;
			}

		}
	}

	// Shift the current value
	if (selectedReg != nullptr)
	{
		selectedReg[next] = selectedReg[current];
		selectedReg[current] = replayVal;
		return 1;
	}

	return 0;
}

//
//Count max register changes for one frame and limit changes to 11.
//
int YmData::CountAndLimitRegChangesOneFrame(int current, int prev, int next, bool limit11, bool limit12)
{
	int changes = 0;

	if (pRegisters[0][current] != 1)
		changes = changes + 1;

	if (pRegisters[1][current] != pRegisters[1][prev])
		changes = changes + 2;

	if (pRegisters[2][current] != 1)
		changes = changes + 1;

	// Register[3] handled with register 1
	if (pRegisters[4][current] != 1)
		changes = changes + 1;

	if ((pRegisters[6][current] & 0x80) == 0) // Register 6
		changes = changes + 1;

	if ((pRegisters[6][current] & 0x40) == 0) // Register 13
		changes = changes + 1;

	if ((pRegisters[6][current] & 0x20) == 0) // Register 5
		changes = changes + 1;

	if (pRegisters[7][current] != 0xF4)
		changes = changes + 1;

	if (pRegisters[8][current] != 0xF4)
		changes = changes + 1;

	if (pRegisters[9][current] != 0xF4)
		changes = changes + 1;

	if (pRegisters[10][current] != 0xF4)
		changes = changes + 1;

	if (pRegisters[11][current] != 1)
		changes = changes + 1;

	if (pRegisters[12][current] != pRegisters[12][prev])
		changes = changes + 1;

	if (limit12 and changes > 12)
		changes = changes - DelayOneRegister(current, next);

	if (limit11 and changes > 11)
		changes = changes - DelayOneRegister(current, next);


	return changes;
}

//
// Count max register changes and limit changes.
//
void YmData::CountAndLimitRegChangesInternal(int maxChanges[NR_YM_REGISTERS + 1], bool Limit11, bool Limit12)
{
	int loopFrame = GetLoopFrame();
	int PrevIndex = nbFrames - 1;
	int NextIndex;
	int nrChanges = 0;

	for (int i = 0; i < NR_YM_REGISTERS + 1; i++)
	{
		maxChanges[i] = 0;
	}

	for (int i = 0; i < nbFrames; i++)
	{
		if (i == nbFrames - 1)
			NextIndex = loopFrame;
		else
			NextIndex = i + 1;

		nrChanges = CountAndLimitRegChangesOneFrame(i, PrevIndex, NextIndex, Limit11, Limit12);
		maxChanges[nrChanges]++;

		PrevIndex = i;
	}

	if (loopFrame != 0)
	{
		nrChanges = CountAndLimitRegChangesOneFrame(loopFrame, nbFrames - 1, loopFrame + 1, Limit11, Limit12);
		maxChanges[nrChanges]++;
	}
}

// 
// Count max register changes and limit changes.
// 
uint8_t YmData::CountAndLimitRegChanges(float Threshold)
{
	int maxChanges[NR_YM_REGISTERS + 1] = { 0 };

	// Dry run to compute the histogram of register changes

	CountAndLimitRegChangesInternal(maxChanges, false, false);

	// Check if we have to limit the number of maximum register changes

	int Count = 0;
	bool Limit11 = false;
	bool Limit12 = false;

	for (int i = 14; i > 12; i--)
	{
		Count = Count + maxChanges[i];
	}

	if (Count != 0 && (float)Count / nbFrames < Threshold)
	{
		Limit12 = true;
	}

	Count = Count + maxChanges[12];
	if (Count != 0 && (float)Count / nbFrames < Threshold)
	{
		Limit11 = true;
	}

	if (Limit11 || Limit12)
	{
		CountAndLimitRegChangesInternal(maxChanges, Limit11, Limit12);
	}

	int registersToPlay = 0;
	for (int i = 0; i < NR_YM_REGISTERS; i++)
	{
		if (maxChanges[i] != 0)
		{
			registersToPlay = i;
		}
	}

	registersToPlay = std::max(11, registersToPlay);

	return registersToPlay;
}

///////////////////////////////////////////////////////////////////////////////////
//
// YM File Reader
//
///////////////////////////////////////////////////////////////////////////////////

bool YmData::LoadFile(const char* FileName)
{
	pYmFile = new CYmMusic;
	ymMusicInfo_t YmFileInfo;

	//
	// Read the Ym file and print some informations.
	//
	if (!pYmFile->load(FileName))
	{
		return false;
	}

	printf("\nFile header:\n");
	printf("  - Nb of frames:    %d\n", pYmFile->GetNbFrame());
	printf("  - Interleaved:     %s\n", pYmFile->getAttrib() & A_STREAMINTERLEAVED ? "Yes" : "No");
	printf("  - Nb of digidrums: %d\n", pYmFile->GetNbDrums());
	printf("  - Loop Frame:      %d\n", pYmFile->GetLoopFrame());

	pYmFile->getMusicInfo(&YmFileInfo);
	printf("\nSong Informations:\n");
	printf("  - Song name: %s\n", YmFileInfo.pSongName);
	printf("  - Author:    %s\n", YmFileInfo.pSongAuthor);
	printf("  - Comment:   %s\n", YmFileInfo.pSongComment);

	//
	// Extract registers from the raw buffer.
	//
	nbFrames = pYmFile->GetNbFrame();
	const uint8_t* pData = pYmFile->GetDataStream();
	for (int r = 0; r < NR_YM_REGISTERS; r++)
	{
		pRegisters[r] = (uint8_t*)&pData[r * nbFrames];
	}

	//
	// Fixup data and perform some basic operations
	//
	FixHoles();
	BackupInitValue();
	CheckR12IsConstant();

	return true;
}

void YmData::Optimize()
{
	SmoothRegisters(pRegisters[0], pRegisters[1], pRegisters[8], 1);
	SmoothRegisters(pRegisters[2], pRegisters[3], pRegisters[9], 2);
	SmoothRegisters(pRegisters[4], pRegisters[5], pRegisters[10], 3);

	FixPeriodLow(pRegisters[0]);
	FixPeriodLow(pRegisters[2]);
	FixPeriodLow(pRegisters[4]);
	FixPeriodLow(pRegisters[11]);

	SmoothNoise();

	MergeRegisters(pRegisters[1], pRegisters[3]);
	MergeRegisters(pRegisters[5], pRegisters[13]);

	PrecaclDeltaPlay(0, 0x01);
	PrecaclDeltaPlay(2, 0x01);
	PrecaclDeltaPlay(4, 0x01);
	PrecaclDeltaPlay(6, 0x80);
	PrecaclDeltaPlay(7, 0xF4);
	PrecaclDeltaPlay(8, 0xF4);
	PrecaclDeltaPlay(9, 0xF4);
	PrecaclDeltaPlay(10, 0xF4);
	PrecaclDeltaPlay(11, 0x01);

	AdjustR6andR13();
}