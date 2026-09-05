#pragma once

class VirtualMachine;

namespace KFVRAnimationBridge
{
	/** Resolve and validate Fallout 4 VR's native paired-animation stop handler. */
	bool Initialize();

	/** Register KFVRAnimationBridge.SkipPlayerPairedAnimation with Papyrus. */
	bool RegisterPapyrus(VirtualMachine* vm);
}
