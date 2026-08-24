#pragma once
#include "f4se/GameData.h"
#include "f4se/GameReferences.h"
#include "f4se/GameSettings.h"

// Fallout 4 VR 1.2.72 HitData / damage frame.
// The desktop plugin declared only the prefix through 0xA0; VR passes the
// complete 0xE0 object, whose offsets are verified against the engine code.
class BGSAttackData;
struct DamageFrame
{
	NiPoint3 hitLocation;                         // 00
	UInt32 pad0C;                                 // 0C
	float unk10[8];                               // 10
	bhkNPCollisionObject* collisionObj;           // 30
	UInt64 unk38;                                 // 38
	UInt32 attackerHandle;                        // 40
	UInt32 victimHandle;                          // 44
	UInt32 sourceRefHandle;                       // 48
	UInt32 pad4C;                                 // 4C
	BGSAttackData* attackData;                    // 50
	TESForm* damageSourceForm;                    // 58
	TBO_InstanceData* instanceData;               // 60
	void* criticalEffect;                         // 68
	void* hitEffect;                              // 70
	void* vatsCommand;                            // 78
	TESAmmo* ammo;                                // 80
	void* damageTypes;                            // 88
	float healthDamage;                           // 90
	float totalDamage;                            // 94
	float physicalDamage;                         // 98
	float targetedLimbDamage;                     // 9C
	float percentBlocked;                         // A0
	float resistedPhysicalDamage;                 // A4
	float resistedTypedDamage;                    // A8
	UInt32 stagger;                               // AC
	float sneakAttackBonus;                       // B0
	float bonusHealthDamageMult;                  // B4
	float pushBack;                               // B8
	float reflectedDamage;                        // BC
	float criticalDamageMult;                     // C0
	UInt32 flags;                                 // C4
	UInt32 equipIndex;                            // C8
	UInt32 padCC;                                 // CC
	UInt32 material;                              // D0
	UInt32 damageLimb;                            // D4
	UInt64 padD8;                                 // D8
};
STATIC_ASSERT(offsetof(DamageFrame, attackerHandle) == 0x40);
STATIC_ASSERT(offsetof(DamageFrame, victimHandle) == 0x44);
STATIC_ASSERT(offsetof(DamageFrame, attackData) == 0x50);
STATIC_ASSERT(offsetof(DamageFrame, damageSourceForm) == 0x58);
STATIC_ASSERT(offsetof(DamageFrame, instanceData) == 0x60);
STATIC_ASSERT(offsetof(DamageFrame, ammo) == 0x80);
STATIC_ASSERT(offsetof(DamageFrame, healthDamage) == 0x90);
STATIC_ASSERT(offsetof(DamageFrame, totalDamage) == 0x94);
STATIC_ASSERT(offsetof(DamageFrame, physicalDamage) == 0x98);
STATIC_ASSERT(offsetof(DamageFrame, flags) == 0xC4);
STATIC_ASSERT(offsetof(DamageFrame, equipIndex) == 0xC8);
STATIC_ASSERT(sizeof(DamageFrame) == 0xE0);

struct ModMiscForms_Struct {
	ActorValueInfo* Health;
	BGSPerk* KFIsVictimKoEligiblePerk;
	BGSPerk* KFIsAttackerKoEligiblePerk;
};
extern ModMiscForms_Struct ModMiscForms;

struct ModKeywords_Struct {
	BGSKeyword* WeaponTypeUnarmed;
	BGSKeyword* QuickkeyMelee;
	BGSKeyword* AnimsBayonet;
	BGSKeyword* ActorTypeNPC;
	BGSKeyword* ActorTypeSuperMutant;
	BGSKeyword* ActorTypeFeralGhoul;
	BGSKeyword* KFKnockedOutKeyword;
	BGSKeyword* KFKnockoutTriggerKeyword;
	BGSKeyword* KFWeaponCanKnockoutKeyword;
	BGSKeyword* KFActorCantBeKnockedOutKeyword;
	BGSKeyword* KFActorCantKnockoutKeyword;
};
extern ModKeywords_Struct ModKeywords;

struct ModGlobals_Struct {
	TESGlobal* KFUnarmedEnabled;
	TESGlobal* KFBashEnabled;
	TESGlobal* KFCanKoPlayer;
	TESGlobal* KFCanKoHumans;
	TESGlobal* KFCanKoSuperMutants;
	TESGlobal* KFCanKoFeralGhoul;
	TESGlobal* KFCanKoOthers;
	TESGlobal* KFCanBeKoPlayer;
	TESGlobal* KFCanBeKoFollowers;
	TESGlobal* KFCanBeKoHumans;
	TESGlobal* KFCanBeKoSuperMutants;
	TESGlobal* KFCanBeKoFeralGhoul;
	TESGlobal* KFCanBeKoOthers;
};
extern ModGlobals_Struct ModGlobals;

/** native HasKeyword/GetVirtualFunction
	credit: shavkacagarikia (https://github.com/shavkacagarikia/ExtraItemInfo) **/
typedef bool(*_IKeywordFormBase_HasKeyword)(IKeywordFormBase* keywordFormBase, BGSKeyword* keyword, UInt32 unk3);

template <typename T>
T GetVirtualFunction(void* baseObject, int vtblIndex) {
	uintptr_t* vtbl = reinterpret_cast<uintptr_t**>(baseObject)[0];
	return reinterpret_cast<T>(vtbl[vtblIndex]);
}

namespace KnockoutFramework
{
	bool HasKeyword_Native(IKeywordFormBase* keywordBase, BGSKeyword* checkKW);

	bool IsAttackKoEligible(TESObjectREFR* attacker, TESObjectREFR* victim, TESObjectWEAP* weaponForm, TESObjectWEAP::InstanceData* weaponInstance, UInt32 attackType);

	bool IsVictimKoEligible(TESObjectREFR* victim, bool isPlayer = false);

	bool IsAttackerKoEligible(TESObjectREFR* attacker, bool isPlayer = false);

	float GetDamagesMult(bool isPlayer = false);

	DamageFrame* CancelDamages(DamageFrame* pDamageFrame, bool noDamages = false);
}
