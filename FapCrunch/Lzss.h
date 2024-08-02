#pragma once

typedef unsigned __int8 uint8_t;

class Lzss
{
public:
	Lzss(int _windowSize, int _litMaxSize);
	void LoadData(uint8_t* inData, int dataLen);
	void ReloadData(uint8_t* inData, int dataLen);
	int Crunch(bool loopStart);
	inline int GetCunchSize() { return dstLen; }
	inline uint8_t* GetCunchData() { return dstData; }

private:
	void PushData(uint8_t data);
	void PushData(uint8_t* data, int len);
	bool FindLongestMatch(int& matchDistance, int& matchLen, int start);
	void EncodeLiteral(int start, int len);
	void EncodeMatch(int distance, int len);
	bool GetWrappedSlice(int windowStart, int windowEnd, int candidateStart, int candidateEnd);

private:
	uint8_t* srcData;
	int srcLen;

	uint8_t* dstData;
	int dstLen;

	int windowSize;
	int litMaxSize;

	int matchMaxSize;
	int offsetLen;
};