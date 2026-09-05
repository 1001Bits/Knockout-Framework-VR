#include "f4se_common/F4SE_version.h"
#include "f4se_common/BranchTrampoline.h"
#include "f4se/PapyrusEvents.h"

#include <array>
#include <atomic>
#include <cstring>
#include <memory>
#include <shlobj.h>

#include "KFVRAnimationBridge.h"
#include "KnockoutFramework.h"

#define PLUGIN_VERSION_MAJOR	1
#define PLUGIN_VERSION_MINOR	4
#define PLUGIN_VERSION_BUILD	0
#define PLUGIN_VR_REVISION		5

#define PLUGIN_NAME		"Knockout Framework VR"
#define FILE_NAME		"KnockoutFramework"
#define BGS_PLUGIN_NAME	(std::string)"Knockout Framework.esm"
#define PLUGIN_VERSION	((PLUGIN_VERSION_MAJOR * 10000) + (PLUGIN_VERSION_MINOR * 100) + PLUGIN_VERSION_BUILD + PLUGIN_VR_REVISION)

IDebugLog						gLog;
PluginHandle					g_pluginHandle = kPluginHandle_Invalid;
F4SEMessagingInterface			* g_messaging = nullptr;
F4SEPapyrusInterface			* papyrusInterface = nullptr;

/** Fallout 4 VR 1.2.72 Actor::DoHitMe(HitData&).
	The callsite and target are checked byte-for-byte before the hook is installed.
	The original target is decoded from the live CALL instead of being invoked via
	a second hardcoded address. */
using _Process = void(*)(Actor *, DamageFrame *);
_Process ProcessDamageFrame = nullptr;

constexpr uintptr_t kProcessDamageFrameCallsiteRva = 0x00DB176D;
constexpr uintptr_t kProcessDamageFrameRva = 0x00E526D0;
// Official F4SEVR 0.6.21 was built with the desktop 1.10.138 runtime token
// even though its loader pins Fallout4VR.exe 1.2.72. This is the token that
// stock F4SEVR actually supplies to plugins; the nominal VR token is not used.
// The live callsite and target are also validated byte-for-byte before patching.
constexpr UInt32 kF4SEVR0621ReportedRuntime = RUNTIME_VERSION_1_10_138;
static_assert(kF4SEVR0621ReportedRuntime == 0x010A08A0, "Unexpected F4SEVR runtime token");
constexpr std::array<UInt8, 13> kExpectedCallsite = {
	0xE8, 0x5E, 0x0F, 0x0A, 0x00, 0x48, 0x85, 0xFF, 0x74, 0x36, 0x48, 0x8B, 0xCF
};
constexpr std::array<UInt8, 13> kExpectedProcessPrologue = {
	0x48, 0x8B, 0xC4, 0x48, 0x89, 0x50, 0x10, 0x55, 0x56, 0x41, 0x56, 0x41, 0x57
};

std::atomic<bool> g_gameFormsReady{ false };
ModGlobals_Struct ModGlobals;
ModKeywords_Struct ModKeywords;
ModMiscForms_Struct ModMiscForms;

struct HandleRefReleaser {
	void operator()(TESObjectREFR * reference) const {
		if (reference) {
			reference->handleRefObject.DecRefHandle();
		}
	}
};

using ScopedHandleRef = std::unique_ptr<TESObjectREFR, HandleRefReleaser>;

namespace Main {
	DamageFrame * SetKnockoutStatus(DamageFrame * pDamageFrame) {
		if (!g_gameFormsReady.load(std::memory_order_acquire) || !pDamageFrame || pDamageFrame->totalDamage == 0.0f) return pDamageFrame;

		TESObjectREFR * victim = nullptr;
		TESObjectREFR * attacker = nullptr;
		UInt32 victimHandle = pDamageFrame->victimHandle;
		UInt32 attackerHandle = pDamageFrame->attackerHandle;

		const bool victimFound = LookupREFRByHandle(&victimHandle, &victim);
		ScopedHandleRef victimOwner(victim);
		if (!victimFound || !victim || victim->formType != kFormType_ACHR) {
			return pDamageFrame;
		}

		const bool attackerFound = LookupREFRByHandle(&attackerHandle, &attacker);
		ScopedHandleRef attackerOwner(attacker);
		if (!attackerFound || !attacker || attacker->formType != kFormType_ACHR) {
			return pDamageFrame;
		}

		TESObjectWEAP * weaponForm = nullptr;
		TESObjectWEAP::InstanceData * weaponInstance = nullptr;

		if (pDamageFrame->damageSourceForm) {
			if (pDamageFrame->damageSourceForm->formType == kFormType_WEAP) {
				weaponForm = reinterpret_cast<TESObjectWEAP*>(pDamageFrame->damageSourceForm);
			}
		}

		if (weaponForm && pDamageFrame->instanceData) {
			weaponInstance = reinterpret_cast<TESObjectWEAP::InstanceData*>(pDamageFrame->instanceData);
		} else if (weaponForm) {
			weaponInstance = &weaponForm->weapData;
		}

		UInt32 attackType = 0; // Ranged attack
		if (pDamageFrame->attackData) {
			if (weaponForm) {
				if (weaponForm->weapData.ammo) attackType = 3; // Gun Bash
				else attackType = 1; // Melee weapon
			} else attackType = 2; // Melee attack
		}

		if (!KnockoutFramework::IsAttackKoEligible(attacker, victim, weaponForm, weaponInstance, attackType)) return pDamageFrame;
		else {
			float damagesMult = KnockoutFramework::GetDamagesMult(victim->formID == 0x14);
			//_DMESSAGE("INFO: HitData | total: %f | physical: %f | health: %f", pDamageFrame->totalDamage, pDamageFrame->physicalDamage, pDamageFrame->healthDamage);

			bool victim_alive = ((victim->actorValueOwner.GetValue(ModMiscForms.Health) - (pDamageFrame->healthDamage * damagesMult)) > 0.0f ? true : false);
			if (!victim_alive) {
				if (!KnockoutFramework::IsVictimKoEligible(victim, (victim->formID == 0x14)) \
					|| !KnockoutFramework::IsAttackerKoEligible(attacker, (attacker->formID == 0x14))) {
					return pDamageFrame;
				}
				if (KnockoutFramework::HasKeyword_Native(&victim->keywordFormBase, ModKeywords.KFKnockoutTriggerKeyword) \
					|| KnockoutFramework::HasKeyword_Native(&victim->keywordFormBase, ModKeywords.KFKnockedOutKeyword)) {
					return KnockoutFramework::CancelDamages(pDamageFrame);
				}

				//_DMESSAGE("INFO: %s triggered Knockout event on %s because his theorical health reached %.4f.",
				//	attacker->baseForm->GetFullName(), victim->baseForm->GetFullName(),
				//	victim->actorValueOwner.GetValue(ModMiscForms.Health) - (pDamageFrame->healthDamage * damagesMult));

				struct KoEventData_Struct {
					Actor * akVictim;
					Actor * akAttacker;
				} KoEventData;

				KoEventData.akVictim = reinterpret_cast<Actor*>((TESObjectREFR*)victim);
				KoEventData.akAttacker = reinterpret_cast<Actor*>((TESObjectREFR*)attacker);

				papyrusInterface->GetExternalEventRegistrations("TriggerKoEvent", &KoEventData, [](UInt64 handle, const char * scriptName, const char * callbackName, void * dataPtr) {
					KoEventData_Struct * KoEventData = static_cast<KoEventData_Struct*>(dataPtr);
					SendPapyrusEvent2<Actor*, Actor*>(handle, scriptName, callbackName, KoEventData->akVictim, KoEventData->akAttacker);
				});

				return KnockoutFramework::CancelDamages(pDamageFrame);
			}
		}
		
		return pDamageFrame;
	}
};

SimpleLock globalDamageLock;
class ActorEx : public Actor {
public:
	static void ProcessDamageFrame_Hook(Actor * pObj, DamageFrame * pDamageFrame) {
		{
			SimpleLocker locker(&globalDamageLock);
			pDamageFrame = Main::SetKnockoutStatus(pDamageFrame);
		}
		ProcessDamageFrame(pObj, pDamageFrame);
	}
};

namespace Settings {
	TESForm * GetFormFromIdentifier(const std::string & formIdentifier) {
		UInt32 formId = 0;
		if (formIdentifier != "none") {
			std::size_t pos = formIdentifier.find_first_of("|");
			std::string modName = formIdentifier.substr(0, pos);
			std::string modForm = formIdentifier.substr(pos + 1);
			sscanf_s(modForm.c_str(), "%X", &formId);
			if (formId != 0x0) {
				UInt8 modIndex = (*g_dataHandler)->GetLoadedModIndex(modName.c_str());
				if (modIndex != 0xFF) {
					formId |= ((UInt32)modIndex) << 24;
				} else {
					UInt16 lightModIndex = (*g_dataHandler)->GetLoadedLightModIndex(modName.c_str());
					if (lightModIndex != 0xFFFF) {
						formId |= 0xFE000000 | (UInt32(lightModIndex) << 12);
					} else {
						_MESSAGE("FormID %s not found!", formIdentifier.c_str());
						formId = 0;
					}
				}
			}
		}
		return (formId != 0x0) ? LookupFormByID(formId) : nullptr;
	}

	static void DefineGameForms() {
		std::string	string_form = "";
		TESForm * form = nullptr;

		// Misc forms

		string_form = "Fallout4.esm|2D4";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == ActorValueInfo::kTypeID) ModMiscForms.Health = (ActorValueInfo *)form;
		else _FATALERROR("ERROR: The 'Health' (%s) actor value could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|FA0";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSPerk::kTypeID) ModMiscForms.KFIsVictimKoEligiblePerk = (BGSPerk*)form;
		else _FATALERROR("ERROR: The 'KFIsVictimKoEligiblePerk' (%s) perk could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|1ED9";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSPerk::kTypeID) ModMiscForms.KFIsAttackerKoEligiblePerk = (BGSPerk*)form;
		else _FATALERROR("ERROR: The 'KFIsAttackerKoEligiblePerk' (%s) perk could not be found", string_form.c_str());

		// Global Variables

		string_form = BGS_PLUGIN_NAME + "|726D";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFUnarmedEnabled = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFUnarmedEnabled' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|35A3";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFBashEnabled = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFBashEnabled' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AF6";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanKoPlayer = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanKoPlayer' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AF7";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanKoHumans = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanKoHumans' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AF8";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanKoSuperMutants = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanKoSuperMutants' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AF9";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanKoFeralGhoul = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanKoFeralGhoul' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AFA";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanKoOthers = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanKoOthers' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AFE";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanBeKoPlayer = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanBeKoPlayer' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|2E13";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanBeKoFollowers = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanBeKoFollowers' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AFC";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanBeKoHumans = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanBeKoHumans' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AFF";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanBeKoSuperMutants = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanBeKoSuperMutants' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AFB";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanBeKoFeralGhoul = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanBeKoFeralGhoul' (%s) global could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|6AFD";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == TESGlobal::kTypeID) ModGlobals.KFCanBeKoOthers = (TESGlobal*)form;
		else _FATALERROR("ERROR: The 'KFCanBeKoOthers' (%s) global could not be found", string_form.c_str());

		// Keywords

		string_form = "Fallout4.esm|5240E";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.WeaponTypeUnarmed = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'WeaponTypeUnarmed' (%s) keyword could not be found", string_form.c_str());

		string_form = "Fallout4.esm|10C89B";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.QuickkeyMelee = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'QuickkeyMelee' (%s) keyword could not be found", string_form.c_str());
		
		string_form = "Fallout4.esm|444F7";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.AnimsBayonet = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'AnimsBayonet' (%s) keyword could not be found", string_form.c_str());

		string_form = "Fallout4.esm|13794";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.ActorTypeNPC = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'ActorTypeNPC' (%s) keyword could not be found", string_form.c_str());

		string_form = "Fallout4.esm|6D7B6";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.ActorTypeSuperMutant = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'ActorTypeSuperMutant' (%s) keyword could not be found", string_form.c_str());

		string_form = "Fallout4.esm|6B4F2";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.ActorTypeFeralGhoul = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'ActorTypeFeralGhoul' (%s) keyword could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|1ED5";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.KFKnockedOutKeyword = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'KFKnockedOutKeyword' (%s) keyword could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|F413";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.KFKnockoutTriggerKeyword = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'KFKnockoutTriggerKeyword' (%s) keyword could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|FA2";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.KFWeaponCanKnockoutKeyword = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'KFWeaponCanKnockoutKeyword' (%s) keyword could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|AF8B";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.KFActorCantBeKnockedOutKeyword = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'KFActorCantBeKnockedOutKeyword' (%s) keyword could not be found", string_form.c_str());

		string_form = BGS_PLUGIN_NAME + "|AF8D";
		form = GetFormFromIdentifier(string_form);
		if (form && form->formType == BGSKeyword::kTypeID) ModKeywords.KFActorCantKnockoutKeyword = (BGSKeyword *)form;
		else _FATALERROR("ERROR: The 'KFActorCantKnockoutKeyword' (%s) keyword could not be found", string_form.c_str());
	}

	static bool ValidateGameForms() {
		return ModMiscForms.Health && ModMiscForms.KFIsVictimKoEligiblePerk && ModMiscForms.KFIsAttackerKoEligiblePerk
			&& ModGlobals.KFUnarmedEnabled && ModGlobals.KFBashEnabled && ModGlobals.KFCanKoPlayer
			&& ModGlobals.KFCanKoHumans && ModGlobals.KFCanKoSuperMutants && ModGlobals.KFCanKoFeralGhoul
			&& ModGlobals.KFCanKoOthers && ModGlobals.KFCanBeKoPlayer && ModGlobals.KFCanBeKoFollowers
			&& ModGlobals.KFCanBeKoHumans && ModGlobals.KFCanBeKoSuperMutants && ModGlobals.KFCanBeKoFeralGhoul
			&& ModGlobals.KFCanBeKoOthers && ModKeywords.WeaponTypeUnarmed && ModKeywords.QuickkeyMelee
			&& ModKeywords.AnimsBayonet && ModKeywords.ActorTypeNPC && ModKeywords.ActorTypeSuperMutant
			&& ModKeywords.ActorTypeFeralGhoul && ModKeywords.KFKnockedOutKeyword
			&& ModKeywords.KFKnockoutTriggerKeyword && ModKeywords.KFWeaponCanKnockoutKeyword
			&& ModKeywords.KFActorCantBeKnockedOutKeyword && ModKeywords.KFActorCantKnockoutKeyword;
	}

	static bool InitHooks() {
		const uintptr_t moduleBase = reinterpret_cast<uintptr_t>(GetModuleHandleA(nullptr));
		const uintptr_t callsite = moduleBase + kProcessDamageFrameCallsiteRva;
		const uintptr_t expectedTarget = moduleBase + kProcessDamageFrameRva;

		if (!KnockoutFramework::ValidateVRDifficultyFunctions()) {
			return false;
		}

		if (std::memcmp(reinterpret_cast<const void *>(callsite), kExpectedCallsite.data(), kExpectedCallsite.size()) != 0) {
			_ERROR("Fallout4VR 1.2.72 damage callsite validation failed at RVA 0x%llX.",
				static_cast<unsigned long long>(kProcessDamageFrameCallsiteRva));
			return false;
		}

		SInt32 displacement = 0;
		std::memcpy(&displacement, reinterpret_cast<const void *>(callsite + 1), sizeof(displacement));
		const uintptr_t decodedTarget = callsite + 5 + displacement;
		if (decodedTarget != expectedTarget ||
			std::memcmp(reinterpret_cast<const void *>(decodedTarget), kExpectedProcessPrologue.data(), kExpectedProcessPrologue.size()) != 0) {
			_ERROR("Fallout4VR 1.2.72 damage target validation failed (decoded RVA 0x%llX).",
				static_cast<unsigned long long>(decodedTarget - moduleBase));
			return false;
		}

		ProcessDamageFrame = reinterpret_cast<_Process>(decodedTarget);
		if (!g_branchTrampoline.Write5Call(callsite, reinterpret_cast<uintptr_t>(ActorEx::ProcessDamageFrame_Hook))) {
			_ERROR("Could not install the Fallout4VR damage call hook.");
			ProcessDamageFrame = nullptr;
			return false;
		}

		_MESSAGE("Installed VR damage hook: callsite RVA 0x%llX -> target RVA 0x%llX.",
			static_cast<unsigned long long>(kProcessDamageFrameCallsiteRva),
			static_cast<unsigned long long>(kProcessDamageFrameRva));
		return true;
	}
	static void MessageCallback(F4SEMessagingInterface::Message* msg) {
		switch (msg->type) {
		case (F4SEMessagingInterface::kMessage_GameDataReady):
			g_gameFormsReady.store(false, std::memory_order_release);
			if (msg->data == nullptr) {
				_MESSAGE("Game data is no longer ready; damage interception is paused.");
				break;
			}
			DefineGameForms();
			g_gameFormsReady.store(ValidateGameForms(), std::memory_order_release);
			if (!g_gameFormsReady.load(std::memory_order_acquire)) {
				_ERROR("Knockout Framework game forms were not resolved; damage interception will remain inactive.");
			}
			break;
		default:
			// No action
			break;
		}
	}
}

extern "C" {
	bool F4SEPlugin_Query(const F4SEInterface * f4se, PluginInfo * info) {
		std::unique_ptr<char[]> sPath(new char[MAX_PATH]);
		sprintf_s(sPath.get(), MAX_PATH, "%s%s.log", "\\My Games\\Fallout4VR\\F4SE\\", FILE_NAME);
		gLog.OpenRelative(CSIDL_MYDOCUMENTS, sPath.get());

		_MESSAGE("%s library v%d.%d.%d (VR port revision %d, plugin version %d) - Loaded", PLUGIN_NAME, PLUGIN_VERSION_MAJOR, PLUGIN_VERSION_MINOR, PLUGIN_VERSION_BUILD, PLUGIN_VR_REVISION, PLUGIN_VERSION);

		info->infoVersion = PluginInfo::kInfoVersion;
		info->name = FILE_NAME;
		info->version = PLUGIN_VERSION;

		g_pluginHandle = f4se->GetPluginHandle();

		if (f4se->isEditor) {
			_FATALERROR("WARNING: Plugin loaded in the editor, shutting down...");
			return false;
		}

		if (f4se->runtimeVersion != kF4SEVR0621ReportedRuntime) {
			_FATALERROR("ERROR: Unsupported F4SE runtime token 0x%08X; Fallout 4 VR 1.2.72 with F4SEVR is required.", f4se->runtimeVersion);
			return false;
		}
		_MESSAGE("Accepted F4SEVR runtime token 0x%08X for Fallout 4 VR 1.2.72.", f4se->runtimeVersion);

		if (f4se->f4seVersion < MAKE_EXE_VERSION(0, 6, 21)) {
			_FATALERROR("ERROR: F4SEVR 0.6.21 or later is required (found 0x%08X).", f4se->f4seVersion);
			return false;
		}

		g_messaging = (F4SEMessagingInterface *)f4se->QueryInterface(kInterface_Messaging);
		if (!g_messaging) {
			_FATALERROR("ERROR: Couldn't get the messaging interface.");
			return false;
		}

		papyrusInterface = (F4SEPapyrusInterface*)f4se->QueryInterface(kInterface_Papyrus);
		if (!papyrusInterface) {
			_FATALERROR("ERROR: Couldn't get the papyrus interface.");
			return false;
		}

		return true;
	}

	bool F4SEPlugin_Load(const F4SEInterface * f4se) {
		if (!KFVRAnimationBridge::Initialize()) {
			_FATALERROR("ERROR: Fallout 4 VR paired-animation cleanup validation failed.");
			MessageBoxA(nullptr, "ERROR: Fallout 4 VR 1.2.72 paired-animation cleanup validation failed. Knockout Framework VR was not loaded.", PLUGIN_NAME, MB_ICONASTERISK);
			return false;
		}

		if (!g_branchTrampoline.Create(1024 * 64)) {
			_FATALERROR("ERROR: The trampoline just experienced its last bounce. Wait for a mod update.");
			return false;
		}

		if (!Settings::InitHooks()) {
			_FATALERROR("ERROR: Fallout 4 VR damage hook validation failed.");
			MessageBoxA(nullptr, "ERROR: Fallout 4 VR 1.2.72 damage hook validation failed. Knockout Framework VR was not loaded.", PLUGIN_NAME, MB_ICONASTERISK);
			return false;
		}

		if (!papyrusInterface->Register(KFVRAnimationBridge::RegisterPapyrus)) {
			// The damage hook is live at this point, so keep the DLL resident. The
			// bridge remains inaccessible and therefore fails closed.
			_ERROR("ERROR: Could not register KFVRAnimationBridge with Papyrus; paired-animation skipping is disabled.");
			MessageBoxA(nullptr, "ERROR: Could not register the Knockout Framework VR animation bridge. The native plugin will remain loaded, but player paired-animation skipping is disabled.", PLUGIN_NAME, MB_ICONASTERISK);
		}

		if (g_messaging != nullptr) g_messaging->RegisterListener(g_pluginHandle, "F4SE", Settings::MessageCallback);

		return true;
	}
};
