#pragma once

#include "YmLoad.h"

#define NR_YM_REGISTERS 14

class YmData
{
public:
	bool LoadFile(const char* FileName);
	void Optimize();
	uint8_t CountAndLimitRegChanges(float Threshold);

	inline uint8_t* GetRegister(int r) { return pRegisters[r]; }
	inline int GetNbFrames() { return nbFrames; }
	inline int GetLoopFrame() { return loopFrame; }
	inline bool R12IsConst() { return R12IsConstant; }
	inline uint8_t* GetInitValues() { return initValues; }

private:
	void FixHoles();
	void BackupInitValue();
	void CheckR12IsConstant();
	void SmoothRegisters(uint8_t* periodLow, uint8_t* periodHigh, uint8_t* volume, int voice);
	void FixPeriodLow(uint8_t* periodLow);
	void SmoothNoise();
	void MergeRegisters(uint8_t* R1, uint8_t* R2);
	void PrecaclDeltaPlay(int regId, int markerValue);
	void AdjustR6andR13();
	int CountAndLimitRegChangesOneFrame(int Current, int Prev, int Next, bool Limit11, bool Limit12);
	int DelayOneRegister(int Current, int Next);
	int DistFromPrevValue(uint8_t* registerData, int current, int next, uint8_t markerValue, bool volumeRegister);
	void CountAndLimitRegChangesInternal(int* maxChanges, bool Limit11, bool Limit12);

private:
	int nbFrames;
	int loopFrame;
	bool R12IsConstant;

	uint8_t* pRegisters[NR_YM_REGISTERS];
	uint8_t initValues[NR_YM_REGISTERS];
};
