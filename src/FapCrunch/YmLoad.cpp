//
// This code is strongly inspired by the StSoundLibrary (https://github.com/arnaud-carre/StSound) by Arnaud Carre (aka Leonard/Oxygene).
//

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _MSC_VER
#define bswap_16(x) _byteswap_ushort(x)
#define bswap_32(x) _byteswap_ulong(x)
#elif defined(__APPLE__)
#include <libkern/OSByteOrder.h>  
#define bswap_16(x) OSSwapInt16(x)
#define bswap_32(x) OSSwapInt32(x)
#else
#include <byteswap.h>
#endif

#include "YmLoad.h"

///////////////////////////////////////////////////////////////////////////////////
//
// Helper functions
//
///////////////////////////////////////////////////////////////////////////////////

static int FileSizeGet(FILE* h)
{
	int size;

	fseek(h, 0, SEEK_END);
	size = ftell(h);
	fseek(h, 0, SEEK_SET);

	return size;
}

int Read32ByteSwap(uint8_t** ptr)
{
	unsigned int* valPtr = (unsigned int*)*ptr;
	*ptr += 4;
	return bswap_32(*valPtr);
}

short Read16ByteSwap(uint8_t** ptr)
{
	unsigned short* valPtr = (unsigned short*)*ptr;
	*ptr += 2;
	return bswap_16(*valPtr);
}

char* ReadNtString(char** ptr)
{
	char* p;

	p = *ptr;
	(*ptr) += strlen(*ptr) + 1;
	return p;
}

///////////////////////////////////////////////////////////////////////////////////
//
// YM File Reader
//
///////////////////////////////////////////////////////////////////////////////////

bool YmLoad::load(const char* fileName)
{
	FILE* in = fopen(fileName, "rb");
	if (!in)
	{
		setLastError("File not Found");
		return false;
	}

	//---------------------------------------------------
	// Allocation d'un buffer pour lire le fichier.
	//---------------------------------------------------
	int fileSize = FileSizeGet(in);
	pBigMalloc = (unsigned char*)malloc(fileSize);
	if (!pBigMalloc)
	{
		setLastError("MALLOC Error");
		fclose(in);
		return false;
	}

	//---------------------------------------------------
	// Chargement du fichier complet.
	//---------------------------------------------------
	if (fread(pBigMalloc, 1, fileSize, in) != (size_t)fileSize)
	{
		free(pBigMalloc);
		setLastError("File is corrupted.");
		fclose(in);
		return false;
	}
	fclose(in);

	//---------------------------------------------------
	// Lecture des donn?es YM:
	//---------------------------------------------------
	if (!ymDecode())
	{
		free(pBigMalloc);
		pBigMalloc = NULL;
		puts(GetLastError());
		return false;
	}


	printf("\nFile header:\n");
	printf("  - Nb of frames:    %d\n", nbFrame);
	printf("  - Loop Frame:      %d\n", loopFrame);
	printf("  - Interleaved:     %s\n", attrib & A_STREAMINTERLEAVED ? "Yes" : "No");

	printf("\nSong Information:\n");
	printf("  - Song name: %s\n", pSongName);
	printf("  - Author:    %s\n", pSongAuthor);
	printf("  - Comment:   %s\n", pSongComment);
	return true;
}

bool YmLoad::ymDecode(void)
{
	uint8_t* ptr;

	//
	// Check YM file is valid and we support the format version.
	//
	if (strncmp((const char*)(pBigMalloc + 3), "!LeOnArD!", 9) || strncmp((const char*)(pBigMalloc), "YM", 2))
	{
		setLastError("Not a valid YM format!");
		return false;
	}

	char ymVersion = pBigMalloc[2];
	if ((ymVersion != '5') && (ymVersion != '6'))
	{
		setLastError("YM format not supported...");
		return false;
	}

	ptr = pBigMalloc + 12;
	nbFrame = Read32ByteSwap(&ptr);
	attrib = Read32ByteSwap(&ptr);
	if (!(attrib & A_STREAMINTERLEAVED))
	{
		setLastError("YM must be in interleaved format (not frame by frame)...");
		return false;
	}

	int nbDrum = Read16ByteSwap(&ptr);
	int clock = Read32ByteSwap(&ptr);
	int playrate = Read16ByteSwap(&ptr);
	loopFrame = Read32ByteSwap(&ptr);
	ptr += Read16ByteSwap(&ptr);
	if (nbDrum > 0)
	{
		setLastError("Digidrums not supported by the Fast Ay Player...");
		return false;
	}

	pSongName = ReadNtString((char**)&ptr);
	pSongAuthor = ReadNtString((char**)&ptr);
	pSongComment = ReadNtString((char**)&ptr);

	pDataStream = ptr;

	return true;
}
