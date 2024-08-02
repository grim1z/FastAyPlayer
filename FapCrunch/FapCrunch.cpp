#include <stdlib.h>
#include <stdio.h>
#include <cstring>
#include "YmData.h"
#include "Lzss.h"

#define FileName "D:\\Dropbox\\RetroGaming\\CPC\\Projets\\HicksPlayer\\resources\\src-ym\\Boblines.ym"
#define FileNameOut "D:\\Dropbox\\RetroGaming\\CPC\\Projets\\HicksPlayer\\Boblines.fap"

uint8_t regOrder[] = { 0, 2, 1, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
#define NR_FAP_REGISTERS sizeof(regOrder)

void CrunchSong(YmData& ymData,
	uint8_t* crunchData[NR_FAP_REGISTERS],
	int crunchSize[NR_FAP_REGISTERS],
	int loopOffset[NR_FAP_REGISTERS])
{
	int rLoop[NR_FAP_REGISTERS] = { 0 };
	Lzss cruncher(256, 31);

	int loopFrame = ymData.GetLoopFrame();
	int nbFrames = ymData.GetNbFrames();

	printf("\nCrunching:\n");

	for (int r = 0; r < NR_FAP_REGISTERS; r++)
	{
		uint8_t regIndex = regOrder[r];
		uint8_t* registerData = ymData.GetRegister(regIndex);

		if (regIndex == 1) {
			printf("  - Crunch register 1+3 : ");
		}
		else if (regIndex == 5)
		{
			printf("  - Crunch register 5+13: ");
		}
		else {
			printf("  - Crunch register %2d  : ", regIndex);
		}

		if (regIndex == 12 && ymData.R12IsConst())
		{
			printf("Skipped (register is constant)\n");
			continue;
		}
		else if (loopFrame != 0)
		{
			cruncher.LoadData(registerData, loopFrame, nbFrames);
			crunchSize[r] = cruncher.Crunch(false);
			loopOffset[r] = crunchSize[r];

			registerData = &registerData[loopFrame];
			cruncher.ReloadData(registerData, nbFrames - loopFrame);
			crunchSize[r] = cruncher.Crunch(true);
		}
		else
		{
			cruncher.LoadData(registerData, nbFrames, nbFrames);
			crunchSize[r] = cruncher.Crunch(true);

			loopOffset[r] = 0;
		}

		crunchData[r] = new uint8_t[crunchSize[r]];
		memcpy(crunchData[r], cruncher.GetCunchData(), crunchSize[r]);

		printf("%d -> %d\n", nbFrames, crunchSize[r]);
	}
}

void WriteFile(YmData& ymData,
	uint8_t* crunchData[NR_FAP_REGISTERS],
	int crunchSize[NR_FAP_REGISTERS],
	int loopOffset[NR_FAP_REGISTERS],
	uint8_t registersToPlay)

{
	FILE* out;
	errno_t err = fopen_s(&out, FileNameOut, "wb");
	uint8_t r12IsConst = ymData.R12IsConst();

	printf("\nWriting file:\n");

	// Write "SkipR12" flag
	fwrite(&r12IsConst, 1, sizeof(uint8_t), out);

	// The player behaves badly if R12 is not constant.Hopefully, this is a very uncommon case.
	// However, in this case, we have to take a large secutiry gap to reach a sufficient decrunch ratio :(
	if (!ymData.R12IsConst())
		registersToPlay = registersToPlay + 3;

	// Write number of registers to play
	fwrite(&registersToPlay, 1, sizeof(uint8_t), out);

	// Write: initial values for each register
	uint8_t* initValues = ymData.GetInitValues();
	fwrite(initValues, NR_YM_REGISTERS, sizeof(uint8_t), out);

	// Write : address of buffers for each register
	uint16_t bufferOffset[NR_FAP_REGISTERS] = { 0 };
	bufferOffset[0] = 2 + NR_YM_REGISTERS + 2 * NR_FAP_REGISTERS;

	for (int r = 1; r < NR_FAP_REGISTERS; r++)
	{
		bufferOffset[r] = bufferOffset[r - 1] + crunchSize[r - 1] + 3;
	}
	fwrite(bufferOffset, NR_FAP_REGISTERS, sizeof(uint16_t), out);

	// Write : register data + loop marker + start address of register data in memory
	uint8_t loopMarker = 0x1F;
	for (int r = 0; r < NR_FAP_REGISTERS; r++)
	{
		if (crunchSize[r])
		{
			fwrite(crunchData[r], crunchSize[r], sizeof(uint8_t), out);
			fwrite(&loopMarker, 1, sizeof(uint8_t), out);
			loopOffset[r] += bufferOffset[r];
			fwrite(&loopOffset[r], 1, sizeof(uint16_t), out);
		}
	}

	long fileSize = ftell(out);
	printf("  - File size: %d (0x%X)\n", fileSize, fileSize);
}

///////////////////////////////////////////////////////////////////////////////////
//
// Entry Point
//
///////////////////////////////////////////////////////////////////////////////////

int main(int argc, char* argv[])
{
	YmData ymData;

	if (!ymData.LoadFile(FileName))
	{
		printf("Error in loading file %s:\n", FileName);
		return -1;
	}

	ymData.Optimize();
	uint8_t nrRegistersToPlay = ymData.CountAndLimitRegChanges(0);

	uint8_t* crunchData[NR_FAP_REGISTERS] = { 0 };
	int crunchSize[NR_FAP_REGISTERS] = { 0 };
	int loopOffset[NR_FAP_REGISTERS] = { 0 };

	CrunchSong(ymData, crunchData, crunchSize, loopOffset);
	WriteFile(ymData, crunchData, crunchSize, loopOffset, nrRegistersToPlay);

	printf("  - Play time: %d NOPS\n", 640);

	return 0;
}
