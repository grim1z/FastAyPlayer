#include <stdlib.h>
#include <stdio.h>
#include <cstring>
#include "YmData.h"
#include "Lzss.h"

#define FileName "D:\\Dropbox\\RetroGaming\\CPC\\Projets\\HicksPlayer\\resources\\src-ym\\From_Scratch-Part1.ym"
#define FileNameOut "D:\\Dropbox\\RetroGaming\\CPC\\Projets\\HicksPlayer\\From_Scratch-Part1.fap"

uint8_t RegOrder[] = { 0, 2, 1, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
#define NR_FAP_REGISTERS sizeof(RegOrder)

void CrunchSong(YmData& ymData,
	uint8_t* crunchData[NR_FAP_REGISTERS],
	int crunchSize[NR_FAP_REGISTERS],
	int loopOffset[NR_FAP_REGISTERS])
{
	int rLoop[NR_FAP_REGISTERS] = { 0 };
	Lzss cruncher(256, 31);

	int loopFrame = ymData.GetLoopFrame();
	int nbFrames = ymData.GetNbFrames();

	for (int r = 0; r < NR_FAP_REGISTERS; r++)
	{
		uint8_t regIndex = RegOrder[r];
		uint8_t* registerData = ymData.GetRegister(regIndex);

		if (regIndex == 1) {
			printf("  - Crunch register 1+3: ");
		}
		else if (regIndex == 5)
		{
			printf(" - Crunch register 5 + 13: ");
		}
		else {
			printf("  - Crunch register %d", regIndex);
		}

		if (regIndex == 12 && ymData.R12IsConst())
		{
			continue;
		}
		else if (loopFrame != 0)
		{
			cruncher.LoadData(registerData, loopFrame);
			crunchSize[r] = cruncher.Crunch(false);
			loopOffset[r] = crunchSize[r];

			registerData = &registerData[loopFrame];
			cruncher.ReloadData(registerData, nbFrames - loopFrame);
			crunchSize[r] = cruncher.Crunch(true);
		}
		else
		{
			cruncher.LoadData(registerData, nbFrames);
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
	int loopOffset[NR_FAP_REGISTERS])

{
	FILE* out;
	errno_t err = fopen_s(&out, FileNameOut, "wb");
	uint8_t RegistersToPlay = 13;
	uint8_t R12IsConst = ymData.R12IsConst();

	// Write "SkipR12" flag
	fwrite(&R12IsConst, 1, sizeof(uint8_t), out);

	// The player behaves badly if R12 is not constant.Hopefully, this is a very uncommon case.
	// However, in this case, we have to take a large secutiry gap to reach a sufficient decrunch ratio :(
	if (!ymData.R12IsConst())
		RegistersToPlay = RegistersToPlay + 3;

	// Write number of registers to play
	fwrite(&RegistersToPlay, 1, sizeof(uint8_t), out);

	// Write: initial values for each register
	uint8_t* initValues = ymData.GetInitValues();
	fwrite(initValues, NR_YM_REGISTERS, sizeof(uint8_t), out);

	// Write : address of buffers for each register
	uint16_t BufferOffset[NR_FAP_REGISTERS] = { 0 };
	BufferOffset[0] = 2 + NR_YM_REGISTERS + 2 * NR_FAP_REGISTERS;

	for (int r = 1; r < NR_FAP_REGISTERS; r++)
	{
		BufferOffset[r] = BufferOffset[r - 1] + crunchSize[r - 1] + 3;
	}
	fwrite(BufferOffset, NR_FAP_REGISTERS, sizeof(uint16_t), out);


	// Write : register data + loop marker + start address of register data in memory
	uint8_t loopMarker = 0x1F;
	for (int r = 0; r < NR_FAP_REGISTERS; r++)
	{
		if (crunchSize[r])
		{
			fwrite(crunchData[r], crunchSize[r], sizeof(uint8_t), out);
			fwrite(&loopMarker, 1, sizeof(uint8_t), out);
			fwrite(&BufferOffset[r], 1, sizeof(uint16_t), out);
		}
	}
}

///////////////////////////////////////////////////////////////////////////////////
//
// Entry Point
//
///////////////////////////////////////////////////////////////////////////////////

int main(int argc, char* argv[])
{
	//	if (argc != 3)
	//	{
	//		printf("Usage: YM2WAV <ym music file> <wav file>\n\n");
	//		return -1;
	//	}

	YmData ymData;

	if (!ymData.LoadFile(FileName))
	{
		printf("Error in loading file %s:\n", FileName);
		return -1;
	}
	uint8_t* crunchData[NR_FAP_REGISTERS] = { 0 };
	int crunchSize[NR_FAP_REGISTERS] = { 0 };
	int loopOffset[NR_FAP_REGISTERS] = { 0 };

	CrunchSong(ymData, crunchData, crunchSize, loopOffset);
	WriteFile(ymData, crunchData, crunchSize, loopOffset);

	return 0;
}

