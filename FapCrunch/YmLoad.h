#pragma once

//
// This code is strongly inspired by the StSoundLibrary (https://github.com/arnaud-carre/StSound) by Arnaud Carre (aka Leonard/Oxygene).
//

typedef	unsigned char uint8_t;
typedef	unsigned short uint16_t;

enum
{
	e_YM5a = ('Y' << 24) | ('M' << 16) | ('5' << 8) | ('!'),	//'YM5!'
	e_YM6a = ('Y' << 24) | ('M' << 16) | ('6' << 8) | ('!'),	//'YM6!'
};

enum
{
	A_STREAMINTERLEAVED = 1,
	A_DRUMSIGNED = 2,
	A_DRUM4BITS = 4,
	A_TIMECONTROL = 8,
	A_LOOPMODE = 16,
};

class YmLoad
{
public:
	bool load(const char* fileName);
	int GetNbFrame()		const { return nbFrame; }
	int GetLoopFrame()		const { return loopFrame; }
	const uint8_t* GetDataStream()		const { return pDataStream; }
	const char* GetLastError() { return pLastError; }

private:
	void setLastError(const char* pError) { pLastError = pError; }
	bool ymDecode(void);

private:
	const char* pLastError;
	uint8_t* pBigMalloc;
	int			nbFrame;
	int			loopFrame;
	int			attrib;
	uint8_t* pDataStream;
	char* pSongName;
	char* pSongAuthor;
	char* pSongComment;
};
