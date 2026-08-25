#include "KnockoutFramework.h"

#include <array>
#include <cmath>
#include <cstring>

namespace
{
	// Fallout 4 VR 1.2.72 engine functions.  The vendored F4SEVR settings
	// helpers cannot be used here: its INIPref singleton RVA aliases the game
	// settings map, which makes GetINISetting traverse a map as a linked list.
	using _GetDifficultyLevel = UInt32(*)(PlayerCharacter*);
	using _GetDifficultyMultiplier = float(*)(SInt32, ActorValueInfo*, bool);

	constexpr uintptr_t kGetDifficultyLevelRva = 0x00F1DBD0;
	constexpr uintptr_t kGetDifficultyMultiplierRva = 0x00652FE0;

	RelocAddr<_GetDifficultyLevel> GetDifficultyLevelVR(kGetDifficultyLevelRva);
	RelocAddr<_GetDifficultyMultiplier> GetDifficultyMultiplierVR(kGetDifficultyMultiplierRva);

	constexpr std::array<UInt8, 39> kExpectedGetDifficultyLevel = {
		0x8B, 0x05, 0xCA, 0x28, 0x8B, 0x02, 0x83, 0xF8, 0x06, 0x7F,
		0x0C, 0x85, 0xC0, 0x79, 0x03, 0x33, 0xC0, 0xC3, 0x83, 0xF8,
		0x05, 0x7C, 0x0E, 0x33, 0xC0, 0x38, 0x05, 0x31, 0x2A, 0x8B,
		0x02, 0x0F, 0x95, 0xC0, 0x83, 0xC0, 0x05, 0xF3, 0xC3
	};

	constexpr std::array<UInt8, 30> kExpectedGetDifficultyMultiplierPrologue = {
		0x48, 0x89, 0x5C, 0x24, 0x08, 0x48, 0x89, 0x74, 0x24, 0x10,
		0x57, 0x48, 0x83, 0xEC, 0x20, 0x41, 0x0F, 0xB6, 0xF0, 0x48,
		0x8B, 0xFA, 0x48, 0x63, 0xD9, 0xE8, 0x22, 0x8E, 0xA1, 0xFF
	};
}

namespace KnockoutFramework
{
	bool HasKeyword_Native(IKeywordFormBase * keywordBase, BGSKeyword * checkKW)
	{
		if (!checkKW || !keywordBase) {
			return false;
		}
		auto HasKeyword_Internal = GetVirtualFunction<_IKeywordFormBase_HasKeyword>(keywordBase, 1);
		return HasKeyword_Internal(keywordBase, checkKW, 0);
	}

	bool IsAttackKoEligible(TESObjectREFR * attacker, TESObjectREFR * victim, TESObjectWEAP * weaponForm, TESObjectWEAP::InstanceData * weaponInstance, UInt32 attackType)
	{
		if (weaponInstance && weaponInstance->keywords && weaponInstance->keywords->numKeywords > 0) {
			if (attackType == 3) {
				if (HasKeyword_Native(&weaponInstance->keywords->keywordBase, ModKeywords.AnimsBayonet)) return false; // Bayonet : Lethal
				else return ((int)ModGlobals.KFBashEnabled->value == 1);
			}
			if (HasKeyword_Native(&weaponInstance->keywords->keywordBase, ModKeywords.KFWeaponCanKnockoutKeyword)) {
				return true; // Certified non-lethal weapon
			}
			if ((attackType == 1 || attackType == 2) \
				&& HasKeyword_Native(&weaponInstance->keywords->keywordBase, ModKeywords.WeaponTypeUnarmed) \
				&& !HasKeyword_Native(&weaponInstance->keywords->keywordBase, ModKeywords.QuickkeyMelee)) {
				return ((int)ModGlobals.KFUnarmedEnabled->value == 1); // Unarmed attack
			}
		}
		if (weaponForm && &weaponForm->keyword) {
			if (attackType == 3) {
				if (HasKeyword_Native(&weaponForm->keyword.keywordBase, ModKeywords.AnimsBayonet)) return false; // Bayonet : Lethal
				else return ((int)ModGlobals.KFBashEnabled->value == 1);
			}
			if (HasKeyword_Native(&weaponForm->keyword.keywordBase, ModKeywords.KFWeaponCanKnockoutKeyword)) {
				return true; // Certified non-lethal weapon
			}
			if ((attackType == 1 || attackType == 2) \
				&& HasKeyword_Native(&weaponForm->keyword.keywordBase, ModKeywords.WeaponTypeUnarmed) \
				&& !HasKeyword_Native(&weaponForm->keyword.keywordBase, ModKeywords.QuickkeyMelee)) {
				return ((int)ModGlobals.KFUnarmedEnabled->value == 1); // Unarmed attack
			}
		}

		return false;
	}

	bool IsVictimKoEligible(TESObjectREFR * victim, bool isPlayer) {
		BGSPerk* conditionalPerk = ModMiscForms.KFIsVictimKoEligiblePerk;
		Condition ** condition = &conditionalPerk->condition;
		if (condition) {
			if (!EvaluationConditions(condition, victim, victim)) return false;
		} else return false;

		if (HasKeyword_Native(&victim->keywordFormBase, ModKeywords.KFActorCantBeKnockedOutKeyword)) return false;
		else if (isPlayer) {
			if ((int)ModGlobals.KFCanBeKoPlayer->value == 0) return false;
		} else if (reinterpret_cast<Actor*>(victim)->IsPlayerTeammate()) {
			if ((int)ModGlobals.KFCanBeKoFollowers->value == 0) return false;
		} else if (HasKeyword_Native(&victim->keywordFormBase, ModKeywords.ActorTypeNPC)) {
			if ((int)ModGlobals.KFCanBeKoHumans->value == 0) return false;
		} else if (HasKeyword_Native(&victim->keywordFormBase, ModKeywords.ActorTypeSuperMutant)) {
			if ((int)ModGlobals.KFCanBeKoSuperMutants->value == 0) return false;
		} else if (HasKeyword_Native(&victim->keywordFormBase, ModKeywords.ActorTypeFeralGhoul)) {
			if ((int)ModGlobals.KFCanBeKoFeralGhoul->value == 0) return false;
		} else if ((int)ModGlobals.KFCanBeKoOthers->value == 0) return false;
		
		return true;
	}

	bool IsAttackerKoEligible(TESObjectREFR * attacker, bool isPlayer) {
		BGSPerk* conditionalPerk = ModMiscForms.KFIsAttackerKoEligiblePerk;
		Condition ** condition = &conditionalPerk->condition;
		if (condition) {
			if (!EvaluationConditions(condition, attacker, attacker)) return false;
		} else return false;
		
		if (HasKeyword_Native(&attacker->keywordFormBase, ModKeywords.KFActorCantKnockoutKeyword)) return false;
		else if (isPlayer) {
			if ((int)ModGlobals.KFCanKoPlayer->value == 0) return false;
		} else if (HasKeyword_Native(&attacker->keywordFormBase, ModKeywords.ActorTypeNPC)) {
			if ((int)ModGlobals.KFCanKoHumans->value == 0) return false;
		} else if (HasKeyword_Native(&attacker->keywordFormBase, ModKeywords.ActorTypeSuperMutant)) {
			if ((int)ModGlobals.KFCanKoSuperMutants->value == 0) return false;
		} else if (HasKeyword_Native(&attacker->keywordFormBase, ModKeywords.ActorTypeFeralGhoul)) {
			if ((int)ModGlobals.KFCanKoFeralGhoul->value == 0) return false;
		} else if ((int)ModGlobals.KFCanKoOthers->value == 0) return false;

		return true;
	}

	bool ValidateVRDifficultyFunctions() {
		const uintptr_t moduleBase = reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));
		const uintptr_t difficultyFunction = moduleBase + kGetDifficultyLevelRva;
		const uintptr_t multiplierFunction = moduleBase + kGetDifficultyMultiplierRva;

		if (std::memcmp(reinterpret_cast<const void*>(difficultyFunction),
			kExpectedGetDifficultyLevel.data(), kExpectedGetDifficultyLevel.size()) != 0) {
			_ERROR("Fallout4VR difficulty function validation failed at RVA 0x%llX.",
				static_cast<unsigned long long>(kGetDifficultyLevelRva));
			return false;
		}

		if (std::memcmp(reinterpret_cast<const void*>(multiplierFunction),
			kExpectedGetDifficultyMultiplierPrologue.data(), kExpectedGetDifficultyMultiplierPrologue.size()) != 0) {
			_ERROR("Fallout4VR difficulty multiplier validation failed at RVA 0x%llX.",
				static_cast<unsigned long long>(kGetDifficultyMultiplierRva));
			return false;
		}

		_MESSAGE("Validated VR difficulty functions: level RVA 0x%llX, multiplier RVA 0x%llX.",
			static_cast<unsigned long long>(kGetDifficultyLevelRva),
			static_cast<unsigned long long>(kGetDifficultyMultiplierRva));
		return true;
	}

	float GetDamagesMult(bool isPlayer) {
		constexpr float damagesMultDefault = 1.0f;

		PlayerCharacter* player = *g_player;
		if (!player || !ModMiscForms.Health) {
			_ERROR("ERROR: Player or Health actor value is unavailable for difficulty scaling.");
			return damagesMultDefault;
		}

		UInt32 difficulty = GetDifficultyLevelVR(player);
		if (difficulty > 4 && difficulty != 6) {
			_ERROR("ERROR: Unknown game difficulty: %u", difficulty);
			return damagesMultDefault;
		}

		// The desktop framework maps true Survival (6) to the legacy *PCSV
		// settings (difficulty slot 5), rather than the *PCTSV slot.  Preserve
		// that behavior so mods which customize those GMSTs retain parity.
		if (difficulty == 6) {
			difficulty = 5;
		}

		const float damagesMult = GetDifficultyMultiplierVR(
			static_cast<SInt32>(difficulty), ModMiscForms.Health, isPlayer);
		return (std::isfinite(damagesMult) && damagesMult != 0.0f) ? damagesMult : damagesMultDefault;
	}

	DamageFrame * CancelDamages(DamageFrame * pDamageFrame, bool noDamages)
	{
		float final_damage = (noDamages ? 0.0 : 0.000001);
		pDamageFrame->healthDamage = final_damage;
		pDamageFrame->physicalDamage = final_damage;
		pDamageFrame->totalDamage = final_damage;
		return pDamageFrame;
	}
}
