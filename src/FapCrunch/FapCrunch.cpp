#define _CRT_SECURE_NO_WARNINGS

#include <stdlib.h>
#include <stdio.h>
#include <cstring>
#include "YmData.h"
#include "Lzss.h"

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

bool WriteFile(char* fileName,
	YmData& ymData,
	uint8_t* crunchData[NR_FAP_REGISTERS],
	int crunchSize[NR_FAP_REGISTERS],
	int loopOffset[NR_FAP_REGISTERS],
	uint8_t registersToPlay)

{
	FILE* out = fopen(fileName, "wb");
	uint8_t r12IsConst = ymData.R12IsConst();

	if (out == NULL)
	{
		return false;
	}

	// Write "SkipR12" flag
	fwrite(&r12IsConst, 1, sizeof(uint8_t), out);

	// The player behaves badly if R12 is not constant. Hopefully, this is a very uncommon case.
	// However, in this case, we have to take a large security gap to reach a sufficient decrunch ratio :(
	if (!ymData.R12IsConst())
		registersToPlay = registersToPlay + 2;

	// Write number of registers to play
	fwrite(&registersToPlay, 1, sizeof(uint8_t), out);

	// Write: initial values for each register
	uint8_t* initValues = ymData.GetInitValues();
	fwrite(initValues, NR_YM_REGISTERS, sizeof(uint8_t), out);

	// Write: address of buffers for each register
	uint16_t bufferOffset[NR_FAP_REGISTERS] = { 0 };
	bufferOffset[0] = 2 + NR_YM_REGISTERS + 2 * NR_FAP_REGISTERS;

	for (int r = 1; r < NR_FAP_REGISTERS; r++)
	{
		bufferOffset[r] = bufferOffset[r - 1] + crunchSize[r - 1] + 3;
	}
	fwrite(bufferOffset, NR_FAP_REGISTERS, sizeof(uint16_t), out);

	// Write: register data + loop marker + start address of register data in memory
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
	printf("  - File size: %ld (0x%lX)\n", fileSize, fileSize);

	return true;
}

///////////////////////////////////////////////////////////////////////////////////
//
// Entry Point
//
///////////////////////////////////////////////////////////////////////////////////

void PrintUsageAndExit()
{
	printf("Invalid number of arguments.\nUsage: FapCrunch <Source YM file> <Destination Hicks file> [-1|-2]\n");
	exit(-1);
}

int main(int argc, char* argv[])
{
	float threshold = 0;
	YmData ymData;

	if (argc < 3 || argc > 4)
	{
		PrintUsageAndExit();
	}

	if (argc == 4)
	{
		if (strlen(argv[3]) != 2 || argv[3][0] != '-')
		{
			PrintUsageAndExit();
		}
		switch (argv[3][1])
		{
		case '1':
			threshold = 0.005f;
			break;

		case '2':
			threshold = 0.01f;
			break;

		case '3':
			threshold = 0.015f;
			break;

		default:
			PrintUsageAndExit();
		}
	}

	char* srcFile = argv[1];
	char* dstFile = argv[2];

	if (!ymData.LoadFile(srcFile))
	{
		printf("Cannot load file %s\n", srcFile);
		return -1;
	}

	ymData.Optimize();
	uint8_t nrRegistersToPlay = ymData.CountAndLimitRegChanges(threshold);

	uint8_t* crunchData[NR_FAP_REGISTERS] = { 0 };
	int crunchSize[NR_FAP_REGISTERS] = { 0 };
	int loopOffset[NR_FAP_REGISTERS] = { 0 };

	CrunchSong(ymData, crunchData, crunchSize, loopOffset);

	printf("\nSummary:\n");
	printf("  - Max registers to program: %d\n", nrRegistersToPlay);
	printf("  - Constant Register 12: %s\n", ymData.R12IsConst() ? "YES" : "NO... Damn your musician!");

	bool success = WriteFile(dstFile, ymData, crunchData, crunchSize, loopOffset, nrRegistersToPlay);
	if (!success)
	{
		printf("Error while writing result file\n");
		abort();
	}

	if (ymData.R12IsConst())
	{
		int exeTime[] = { 596, 620, 644, 668 };
		printf("  - Play time: %d NOPS\n", exeTime[nrRegistersToPlay - 11]);
		printf("  - Decrunch buffer size: 3144 (#B42)\n");
	}
	else
	{
		int exeTime[] = { 664, 688, 712, 736 };

		printf("  - Play time: %d NOPS\n", exeTime[nrRegistersToPlay - 11]);
		printf("  - Decrunch buffer size: 2888 (#C48)\n");
	}

	return 0;
}
