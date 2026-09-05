#include "KFVRAnimationBridge.h"

#include "f4se/GameReferences.h"
#include "f4se/PapyrusNativeFunctions.h"
#include "f4se/PapyrusVM.h"

#include <array>
#include <cstring>

namespace
{
	// Fallout 4 VR 1.2.72 PairedStopHandler::executeHandler. The handler performs
	// the engine-owned paired-scene teardown, including
	// BGSSynchronizedAnimationManager::RemoveScenesContainingReference.
	constexpr uintptr_t kPairedStopHandlerRva = 0x00FF1870;
	constexpr uintptr_t kSynchronizedAnimationManagerRva = 0x05A38C38;
	constexpr uintptr_t kActorGetHandleRva = 0x003F9720;
	constexpr uintptr_t kCollectSceneReferenceHandlesRva = 0x00801EC0;
	constexpr uintptr_t kAreReferencesInSameSceneRva = 0x00802330;
	constexpr uintptr_t kRemoveScenesContainingReferenceRva = 0x008023F0;

	constexpr uintptr_t kCleanupTailOffset = 0x78;
	constexpr uintptr_t kManagerLoadOffset = 0x78;
	constexpr uintptr_t kActorGetHandleCallOffset = 0x87;
	constexpr uintptr_t kRemoveScenesCallOffset = 0x92;
	constexpr uintptr_t kSameSceneCollectCallOffset = 0x46;

	constexpr std::array<UInt8, 38> kExpectedPairedStopPrologue = {
		0x48, 0x89, 0x5C, 0x24, 0x08, 0x48, 0x89, 0x74,
		0x24, 0x18, 0x57, 0x48, 0x83, 0xEC, 0x20, 0x48,
		0x8B, 0x82, 0x28, 0x01, 0x00, 0x00, 0x48, 0x8D,
		0x8A, 0x28, 0x01, 0x00, 0x00, 0x48, 0x8B, 0xFA,
		0xFF, 0x90, 0x28, 0x01, 0x00, 0x00
	};

	constexpr std::array<UInt8, 31> kExpectedCleanupTail = {
		0x48, 0x8B, 0x1D, 0x49, 0x73, 0xA4, 0x04,
		0x48, 0x8D, 0x54, 0x24, 0x38,
		0x48, 0x8B, 0xCF,
		0xE8, 0x24, 0x7E, 0x40, 0xFF,
		0x48, 0x8B, 0xCB,
		0x48, 0x8B, 0xD0,
		0xE8, 0xE9, 0x0A, 0x81, 0xFF
	};

	// Fallout 4 VR's same-scene predicate takes two reference handles. It asks
	// the manager for the handles belonging to the first handle's scene, then
	// searches that bounded result for the second handle. The equivalent desktop
	// 1.11.221 function is RVA 0x8126C0, immediately before the symbolized
	// RemoveScenesContainingReference function.
	constexpr std::array<UInt8, 46> kExpectedSameScenePrologue = {
		0x48, 0x8B, 0xC4,
		0x48, 0x89, 0x58, 0x08,
		0x48, 0x89, 0x68, 0x18,
		0x48, 0x89, 0x70, 0x20,
		0x57,
		0x48, 0x83, 0xEC, 0x40,
		0x33, 0xED,
		0x48, 0x8B, 0xF9,
		0x48, 0x8D, 0x48, 0xF0,
		0x49, 0x8B, 0xF0,
		0x48, 0x8B, 0xDA,
		0x48, 0x89, 0x68, 0xD8,
		0x48, 0x89, 0x68, 0xE0,
		0x89, 0x68, 0xE8
	};

	constexpr std::array<UInt8, 24> kExpectedSameSceneCollectDispatch = {
		0x8B, 0x03,
		0x4C, 0x8D, 0x44, 0x24, 0x20,
		0x48, 0x8D, 0x54, 0x24, 0x58,
		0x48, 0x8B, 0xCF,
		0x89, 0x44, 0x24, 0x58,
		0xE8, 0x45, 0xFB, 0xFF, 0xFF
	};

	constexpr std::array<UInt8, 38> kExpectedSameSceneSearch = {
		0x45, 0x85, 0xC9,
		0x74, 0x1B,
		0x4D, 0x8B, 0xC2,
		0x83, 0xF8, 0xFF,
		0x75, 0x16,
		0x8B, 0x0E,
		0x41, 0x39, 0x08,
		0x0F, 0x44, 0xC2,
		0xFF, 0xC2,
		0x49, 0x83, 0xC0, 0x04,
		0x41, 0x3B, 0xD1,
		0x72, 0xE8,
		0x83, 0xF8, 0xFF,
		0x0F, 0x95, 0xC3
	};

	using PairedStopHandler = bool(*)(void* thisPtr, Actor* actor, const BSFixedString* eventData);
	using ActorGetHandle = UInt32*(*)(Actor* actor, UInt32* result);
	using AreReferencesInSameScene = bool(*)(void* manager, const UInt32* firstHandle, const UInt32* secondHandle);
	PairedStopHandler g_pairedStopHandler = nullptr;
	ActorGetHandle g_actorGetHandle = nullptr;
	AreReferencesInSameScene g_areReferencesInSameScene = nullptr;
	void** g_synchronizedAnimationManager = nullptr;

	uintptr_t DecodeRelativeTarget(uintptr_t instruction, uintptr_t displacementOffset, uintptr_t instructionLength)
	{
		SInt32 displacement = 0;
		std::memcpy(&displacement,
			reinterpret_cast<const void*>(instruction + displacementOffset),
			sizeof(displacement));
		return instruction + instructionLength + displacement;
	}

	bool SkipPlayerPairedAnimation(StaticFunctionTag*, Actor* player, Actor* pairedActor)
	{
		// This bridge cannot authorize teardown of an NPC-only paired scene. Its
		// required primary reference is the base-game player ACHR (form 0x14).
		if (!g_pairedStopHandler || !g_actorGetHandle || !g_areReferencesInSameScene ||
			!g_synchronizedAnimationManager || !player || !pairedActor ||
			player->formID != 0x14) {
			return false;
		}

		void* manager = *g_synchronizedAnimationManager;
		if (!manager) {
			return false;
		}

		UInt32 playerHandle = 0;
		UInt32 pairedActorHandle = 0;
		g_actorGetHandle(player, &playerHandle);
		g_actorGetHandle(pairedActor, &pairedActorHandle);

		// Equal handles are intentional for the player-victim callback: the query
		// still proves that the player is a live scene participant. When the player
		// is the aggressor, the second handle proves the victim shares that scene.
		if (!g_areReferencesInSameScene(manager, &playerHandle, &pairedActorHandle)) {
			return false;
		}

		// PairedStopHandler does not read its handler instance or event payload in
		// Fallout 4 VR 1.2.72; the validated function consumes the Actor in RDX.
		return g_pairedStopHandler(nullptr, player, nullptr);
	}
}

bool KFVRAnimationBridge::Initialize()
{
	g_pairedStopHandler = nullptr;
	g_actorGetHandle = nullptr;
	g_areReferencesInSameScene = nullptr;
	g_synchronizedAnimationManager = nullptr;

	const uintptr_t moduleBase = reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));
	if (!moduleBase) {
		_ERROR("Could not resolve the Fallout4VR module base for paired-animation cleanup.");
		return false;
	}

	const uintptr_t handler = moduleBase + kPairedStopHandlerRva;
	if (std::memcmp(reinterpret_cast<const void*>(handler),
		kExpectedPairedStopPrologue.data(), kExpectedPairedStopPrologue.size()) != 0) {
		_ERROR("Fallout4VR 1.2.72 PairedStopHandler prologue validation failed at RVA 0x%llX.",
			static_cast<unsigned long long>(kPairedStopHandlerRva));
		return false;
	}

	if (std::memcmp(reinterpret_cast<const void*>(handler + kCleanupTailOffset),
		kExpectedCleanupTail.data(), kExpectedCleanupTail.size()) != 0) {
		_ERROR("Fallout4VR 1.2.72 PairedStopHandler cleanup-tail validation failed at RVA 0x%llX.",
			static_cast<unsigned long long>(kPairedStopHandlerRva + kCleanupTailOffset));
		return false;
	}

	const uintptr_t sameScene = moduleBase + kAreReferencesInSameSceneRva;
	if (std::memcmp(reinterpret_cast<const void*>(sameScene),
		kExpectedSameScenePrologue.data(), kExpectedSameScenePrologue.size()) != 0 ||
		std::memcmp(reinterpret_cast<const void*>(sameScene + 0x33),
			kExpectedSameSceneCollectDispatch.data(), kExpectedSameSceneCollectDispatch.size()) != 0 ||
		std::memcmp(reinterpret_cast<const void*>(sameScene + 0x5A),
			kExpectedSameSceneSearch.data(), kExpectedSameSceneSearch.size()) != 0) {
		_ERROR("Fallout4VR 1.2.72 synchronized same-scene predicate validation failed at RVA 0x%llX.",
			static_cast<unsigned long long>(kAreReferencesInSameSceneRva));
		return false;
	}

	const uintptr_t manager = DecodeRelativeTarget(handler + kManagerLoadOffset, 3, 7);
	const uintptr_t getActorHandle = DecodeRelativeTarget(handler + kActorGetHandleCallOffset, 1, 5);
	const uintptr_t removeScenes = DecodeRelativeTarget(handler + kRemoveScenesCallOffset, 1, 5);
	const uintptr_t collectSceneHandles = DecodeRelativeTarget(sameScene + kSameSceneCollectCallOffset, 1, 5);
	if (manager != moduleBase + kSynchronizedAnimationManagerRva ||
		getActorHandle != moduleBase + kActorGetHandleRva ||
		removeScenes != moduleBase + kRemoveScenesContainingReferenceRva ||
		collectSceneHandles != moduleBase + kCollectSceneReferenceHandlesRva) {
		_ERROR("Fallout4VR 1.2.72 PairedStopHandler target validation failed "
			"(manager RVA 0x%llX, handle RVA 0x%llX, collect RVA 0x%llX, remove RVA 0x%llX).",
			static_cast<unsigned long long>(manager - moduleBase),
			static_cast<unsigned long long>(getActorHandle - moduleBase),
			static_cast<unsigned long long>(collectSceneHandles - moduleBase),
			static_cast<unsigned long long>(removeScenes - moduleBase));
		return false;
	}

	g_pairedStopHandler = reinterpret_cast<PairedStopHandler>(handler);
	g_actorGetHandle = reinterpret_cast<ActorGetHandle>(getActorHandle);
	g_areReferencesInSameScene = reinterpret_cast<AreReferencesInSameScene>(sameScene);
	g_synchronizedAnimationManager = reinterpret_cast<void**>(manager);
	_MESSAGE("Validated VR paired-animation cleanup: same-scene RVA 0x%llX, handler RVA 0x%llX -> RemoveScenesContainingReference RVA 0x%llX.",
		static_cast<unsigned long long>(kAreReferencesInSameSceneRva),
		static_cast<unsigned long long>(kPairedStopHandlerRva),
		static_cast<unsigned long long>(kRemoveScenesContainingReferenceRva));
	return true;
}

bool KFVRAnimationBridge::RegisterPapyrus(VirtualMachine* vm)
{
	if (!vm || !g_pairedStopHandler) {
		_ERROR("KFVRAnimationBridge Papyrus registration rejected because native validation is not ready.");
		return false;
	}

	vm->RegisterFunction(
		new NativeFunction2<StaticFunctionTag, bool, Actor*, Actor*>(
			"SkipPlayerPairedAnimation",
			"KFVRAnimationBridge",
			SkipPlayerPairedAnimation,
			vm));
	_MESSAGE("Registered KFVRAnimationBridge.SkipPlayerPairedAnimation.");
	return true;
}
