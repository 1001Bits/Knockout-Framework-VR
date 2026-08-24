ScriptName KFManagerQuestMainScript Extends Quest

;-- Variables ---------------------------------------

;-- Properties --------------------------------------
koframeworkevents Property FrameworkEventsScript Auto Const
kfmanagerquesteventsscript Property EventsScript Auto Const
kfmanagerquesttriggervictimscript Property TriggerVictimScript Auto Const
kfmanagerquestkocollectionscript Property KOCollectionScript Auto Const
ReferenceAlias Property TempAlias Auto Const
GlobalVariable Property KFUnarmedEnabled Auto Const
GlobalVariable Property KFBashEnabled Auto Const
GlobalVariable Property KFReanimationHealth Auto Const
GlobalVariable Property KFKoPushStrength Auto Const
GlobalVariable Property KFDisarmKoNPC Auto Const
GlobalVariable Property KFFallEnabled Auto Const
GlobalVariable Property KFKoSound Auto Const
GlobalVariable Property KFKoTimeMin Auto Const
GlobalVariable Property KFKoTimeMax Auto Const
GlobalVariable Property KFKoXPMult Auto Const
GlobalVariable Property KFCanBeKoFollowers Auto Const
GlobalVariable Property KFChancesToDieIfNotHelped Auto Const
GlobalVariable Property KFConvalescenceEffectEnabled Auto Const
Keyword Property VATSRestrictedTargetKeyword Auto Const
Keyword Property KFKnockedOutKeyword Auto Const
Keyword Property KFKnockoutAggressorKeyword Auto Const
Keyword Property CompanionDisableMenuAll Auto Const
Keyword Property KFKoExitRagdollKeyword Auto Const
FormList Property KFKnockoutDispelList Auto Const
ActorValue Property Health Auto Const
ActorValue Property Paralysis Auto Const
ActorValue Property LeftMobilityCondition Auto Const
ActorValue Property RightMobilityCondition Auto Const
ActorValue Property KFKoXPEarned Auto Const
Perk Property KFIncomingMonitoringPerk Auto Const
Potion Property KFConvalescencePotion Auto Const
Potion Property KFConvalescenceDispel1Potion Auto Const
Potion Property KFConvalescenceDispel2Potion Auto Const
Potion Property KFConvalescenceDispel3Potion Auto Const
Spell Property KFTriggerAggressionSpell Auto Const
Spell Property KFTryToKillVictimSpell Auto Const
Spell Property KFKoExitRagdollSpell Auto Const
Spell Property KFDisarmSpell Auto Const
Sound Property UIVATSTargetLock Auto Const
Actor Property Player Auto Const

;-- Functions ---------------------------------------

Bool Function KnockOutActor(Actor Victim, Actor Aggressor, Int KillMoveType, Bool SilentKo)
  If !Victim ; #DEBUG_LINE_NO:57
    Return False ; #DEBUG_LINE_NO:58
  ElseIf Victim == Player && !Self.IsPlayerKnockoutEnabled()
    ; Monitoring and native KO requests can already be queued when the setting is
    ; disabled. Never let a stale request mutate the VR player's actor state.
    Self.RestorePlayerVRState(Victim)
    Return False
  ElseIf !Aggressor ; #DEBUG_LINE_NO:59
    If KillMoveType > 0 && Player.GetDistance(Victim as ObjectReference) < 250.0 ; #DEBUG_LINE_NO:60
      Aggressor = Player ; #DEBUG_LINE_NO:61
    EndIf
    If !Aggressor ; #DEBUG_LINE_NO:63
      Aggressor = Victim ; #DEBUG_LINE_NO:64
    EndIf
  EndIf
  If Victim.HasKeyword(KFKnockedOutKeyword) || Victim.IsBleedingOut() ; #DEBUG_LINE_NO:68
    Return False ; #DEBUG_LINE_NO:69
  EndIf
  If Victim.IsPlayerTeammate() ; #DEBUG_LINE_NO:73
    If KFCanBeKoFollowers.GetValue() ; #DEBUG_LINE_NO:74
      Victim.AddKeyword(CompanionDisableMenuAll) ; #DEBUG_LINE_NO:75
      Victim.SetCanDoCommand(False) ; #DEBUG_LINE_NO:76
    Else
      Return False ; #DEBUG_LINE_NO:78
    EndIf
  EndIf
  If KillMoveType == 2 && Aggressor.GetEquippedWeapon(0) == None ; #DEBUG_LINE_NO:82
    KillMoveType = 1 ; #DEBUG_LINE_NO:83
  EndIf
  If Victim.IsDismembered("") || KillMoveType == 1 && Aggressor.GetEquippedWeapon(0) == None && (KFUnarmedEnabled.GetValue() as Int == 0) || KillMoveType == 2 && (KFBashEnabled.GetValue() as Int == 0) ; #DEBUG_LINE_NO:85
    If !Victim.IsEssential() ; #DEBUG_LINE_NO:86
      Victim.Kill(Aggressor) ; #DEBUG_LINE_NO:87
      Return False ; #DEBUG_LINE_NO:88
    EndIf
  ElseIf KillMoveType == 1 && Aggressor.GetEquippedWeapon(0) != None && !Victim.IsEssential() ; #DEBUG_LINE_NO:90
    Aggressor.DoCombatSpellApply(KFTryToKillVictimSpell, Victim as ObjectReference) ; #DEBUG_LINE_NO:91
  EndIf
  If Victim != Player ; #DEBUG_LINE_NO:94
    If Victim != Aggressor ; #DEBUG_LINE_NO:95
      Aggressor.DoCombatSpellApply(KFTriggerAggressionSpell, Victim as ObjectReference) ; #DEBUG_LINE_NO:96
    EndIf
    If KFDisarmKoNPC.GetValue() as Int == 1 ; #DEBUG_LINE_NO:98
      Aggressor.DoCombatSpellApply(KFDisarmSpell, Victim as ObjectReference) ; #DEBUG_LINE_NO:99
    EndIf
  EndIf
  Weapon EquippedWeapon = Victim.GetEquippedWeapon(0) ; #DEBUG_LINE_NO:102
  If EquippedWeapon ; #DEBUG_LINE_NO:103
    Victim.UnequipItem(EquippedWeapon as Form, False, True) ; #DEBUG_LINE_NO:104
  EndIf
  If Aggressor == Player && Victim != Aggressor ; #DEBUG_LINE_NO:106
    If Victim.GetValue(KFKoXPEarned) == 0.0 && !Victim.IsPlayerTeammate() ; #DEBUG_LINE_NO:107
      Int GainedXP = ((Math.Sqrt(Victim.GetBaseValue(Health)) * 3.0 + Victim.GetLevel() as Float) / 2.0 * KFKoXPMult.GetValue()) as Int ; #DEBUG_LINE_NO:108
      If GainedXP > Player.GetLevel() / 6 ; #DEBUG_LINE_NO:109
        Game.RewardPlayerXP(GainedXP, False) ; #DEBUG_LINE_NO:110
      EndIf
      Victim.SetValue(KFKoXPEarned, 1.0) ; #DEBUG_LINE_NO:112
    EndIf
    If (KFKoSound.GetValue() as Int == 1) && !SilentKo ; #DEBUG_LINE_NO:114
      Game.ShakeCamera(None, 0.5, 0.600000024) ; #DEBUG_LINE_NO:115
      UIVATSTargetLock.Play(Aggressor as ObjectReference) ; #DEBUG_LINE_NO:116
    EndIf
  EndIf
  If !KOCollectionScript.AddKOActor(Victim) ; #DEBUG_LINE_NO:120
    ; Reserve collection state before changing knockout actor state. If another
    ; request already owns the player, leave that transaction intact.
    If Victim == Player && !KOCollectionScript.IsKOActor(Victim)
      Self.RestorePlayerVRState(Victim)
    EndIf
    Return False ; #DEBUG_LINE_NO:121
  EndIf
  Self.SetKOStatusOn(Victim, Aggressor, KillMoveType as Bool || SilentKo) ; #DEBUG_LINE_NO:119
  FrameworkEventsScript.OnKnockOutStartEvent(Victim, Aggressor) ; #DEBUG_LINE_NO:124
  String Result = EventsScript.OnUniqueActorEvent(Victim, Aggressor, "KnockOutStart") ; #DEBUG_LINE_NO:125
  If Result != "" ; #DEBUG_LINE_NO:126
    FrameworkEventsScript.OnUniqueKnockOutStartEvent(Result, Victim, Aggressor) ; #DEBUG_LINE_NO:127
  EndIf
  Return True ; #DEBUG_LINE_NO:129
EndFunction

Bool Function IsPlayerKnockoutEnabled()
  ; Dynamic lookups avoid adding new VMAD properties to the v1.4 manager quest.
  GlobalVariable KFCanBeKoPlayer = Game.GetFormFromFile(0x00006AFE, "Knockout Framework.esm") as GlobalVariable
  Return KFCanBeKoPlayer && KFCanBeKoPlayer.GetValue() != 0.0
EndFunction

Bool Function IsPlayerDeferredDeathEnabled()
  GlobalVariable KFDeferPlayerDeathEnabled = Game.GetFormFromFile(0x00018483, "Knockout Framework.esm") as GlobalVariable
  Return Self.IsPlayerKnockoutEnabled() && KFDeferPlayerDeathEnabled && KFDeferPlayerDeathEnabled.GetValue() != 0.0
EndFunction

Bool Function IsPlayerInFrameworkKO()
  Return Player.HasKeyword(KFKnockedOutKeyword) || KOCollectionScript.IsKOActor(Player)
EndFunction

Function RestorePlayerVRState(Actor Victim)
  If !Victim || Victim != Player
    Return
  EndIf

  ; Only clear player state when a KF-owned marker exists. This makes recovery
  ; safe to call repeatedly without breaking vanilla scenes or another mod.
  Bool WasFrameworkKO = Victim.HasKeyword(KFKnockedOutKeyword)
  Bool WasTracked = KOCollectionScript.IsKOActor(Victim)
  Bool RemovedGetUpSpell = Victim.DispelSpell(KFKoExitRagdollSpell)
  Bool HadAggressorLink = Victim.GetLinkedRef(KFKnockoutAggressorKeyword) != None
  Bool HadRagdollExitLink = Victim.GetLinkedRef(KFKoExitRagdollKeyword) != None
  If !WasFrameworkKO && !WasTracked && !RemovedGetUpSpell && !HadAggressorLink && !HadRagdollExitLink
    Return
  EndIf

  If WasTracked
    Bool RemovedFromCollection = KOCollectionScript.RemoveKOActor(Victim, -1)
  EndIf
  If WasFrameworkKO
    Self.SetVictimHealth(Victim, KFReanimationHealth.GetValue())
    Victim.RemoveKeyword(KFKnockedOutKeyword)
  EndIf
  Victim.RemoveKeyword(VATSRestrictedTargetKeyword)
  Victim.SetLinkedRef(None, KFKnockoutAggressorKeyword)
  Victim.SetLinkedRef(None, KFKoExitRagdollKeyword)
  Victim.SetValue(Paralysis, 0.0)
  If !Victim.IsDead()
    If (WasFrameworkKO || WasTracked) && Victim.GetValue(LeftMobilityCondition) < 1.0 && Victim.GetValue(RightMobilityCondition) < 1.0
      ; Match the original fall-KO recovery: free one mobility limb only when
      ; both are fully disabled, instead of healing unrelated injuries.
      If Utility.RandomInt(0, 1)
        Victim.RestoreValue(LeftMobilityCondition, 15.0 - Victim.GetValue(LeftMobilityCondition))
      Else
        Victim.RestoreValue(RightMobilityCondition, 15.0 - Victim.GetValue(RightMobilityCondition))
      EndIf
    EndIf
    Victim.SetUnconscious(False)
    Victim.SetNotShowOnStealthMeter(False)
    Victim.EvaluatePackage(False)
  EndIf
EndFunction

Function SetKOStatusOn(Actor Victim, Actor Aggressor, Bool IsKillMove)
  Victim.AddKeyword(KFKnockedOutKeyword) ; #DEBUG_LINE_NO:133
  Victim.AddKeyword(VATSRestrictedTargetKeyword) ; #DEBUG_LINE_NO:134
  If Aggressor != Victim && Aggressor.IsDetectedBy(Victim) && Aggressor.IsHostileToActor(Victim) && Victim.GetCombatState() == 1 ; #DEBUG_LINE_NO:135
    Victim.SetLinkedRef(Aggressor as ObjectReference, KFKnockoutAggressorKeyword) ; #DEBUG_LINE_NO:136
  Else
    Victim.SetLinkedRef(None, KFKnockoutAggressorKeyword) ; #DEBUG_LINE_NO:138
  EndIf
  If Victim == Player
    ; The desktop ragdoll/get-up animation path is not reliable for the VR player.
    Victim.SetValue(Paralysis, 0.0)
  Else
    Victim.SetValue(Paralysis, 1.0) ; #DEBUG_LINE_NO:140
  EndIf
  Victim.SetNotShowOnStealthMeter(True) ; #DEBUG_LINE_NO:141
  Victim.SetUnconscious(True) ; #DEBUG_LINE_NO:142
  If Victim != Player && Victim.Is3DLoaded() && !Victim.IsDead() ; #DEBUG_LINE_NO:143
    If Victim.GetValue(LeftMobilityCondition) < 1.0 && Victim.GetValue(RightMobilityCondition) < 1.0 ; #DEBUG_LINE_NO:144
      If Utility.RandomInt(0, 1) ; #DEBUG_LINE_NO:145
        Victim.RestoreValue(LeftMobilityCondition, 15.0 - Victim.GetValue(LeftMobilityCondition)) ; #DEBUG_LINE_NO:146
      Else
        Victim.RestoreValue(RightMobilityCondition, 15.0 - Victim.GetValue(RightMobilityCondition)) ; #DEBUG_LINE_NO:148
      EndIf
      Victim.AttemptAnimationSetSwitch() ; #DEBUG_LINE_NO:150
    EndIf
    Victim.PushActorAway(Victim, 0.01) ; #DEBUG_LINE_NO:153
  EndIf
  Int Index = KFKnockoutDispelList.GetSize() ; #DEBUG_LINE_NO:156
  While Index
    Index -= 1 ; #DEBUG_LINE_NO:158
    Spell SpellRef = KFKnockoutDispelList.GetAt(Index) as Spell ; #DEBUG_LINE_NO:159
    Victim.DispelSpell(SpellRef) ; #DEBUG_LINE_NO:160
  EndWhile
  Self.SetVictimHealth(Victim, 0.25) ; #DEBUG_LINE_NO:162
EndFunction

Bool Function WakeKnockedOutActor(Actor Victim, Int Index, Actor Helper, Bool NoKill)
  If !Victim
    Return False
  EndIf
  If Index >= 0
    If KOCollectionScript == None || !KOCollectionScript.IsKOActorAtIndex(Victim, Index)
      ; Indexed wakes come from a specific timer/reset slot. Reject stale slot
      ; identities before changing follower commands or any actor state.
      Return False
    EndIf
  EndIf
  If Victim.HasKeyword(CompanionDisableMenuAll) ; #DEBUG_LINE_NO:167
    Victim.RemoveKeyword(CompanionDisableMenuAll) ; #DEBUG_LINE_NO:168
    If Victim.IsPlayerTeammate() ; #DEBUG_LINE_NO:169
      Victim.SetCanDoCommand(True) ; #DEBUG_LINE_NO:170
    EndIf
  EndIf
  If !KOCollectionScript.RemoveKOActor(Victim, Index) ; #DEBUG_LINE_NO:174
    ; Physical cleanup is idempotent and must not depend on collection integrity.
    If Victim.HasKeyword(KFKnockedOutKeyword) || Victim == Player
      Self.SetKOStatusOff(Victim)
    EndIf
    Return False ; #DEBUG_LINE_NO:175
  EndIf
  If !NoKill && !Helper && !Victim.IsEssential() && Victim != Player && Utility.RandomFloat(0.100000001, 100.0) <= KFChancesToDieIfNotHelped.GetValue() ; #DEBUG_LINE_NO:178
    Victim.Kill(Victim.GetLinkedRef(KFKnockoutAggressorKeyword) as Actor) ; #DEBUG_LINE_NO:179
  EndIf
  Self.SetKOStatusOff(Victim) ; #DEBUG_LINE_NO:181
  If !Victim.IsDead() ; #DEBUG_LINE_NO:183
    FrameworkEventsScript.OnKnockOutEndEvent(Victim, Helper) ; #DEBUG_LINE_NO:184
    String Result = EventsScript.OnUniqueActorEvent(Victim, Helper, "KnockOutEnd") ; #DEBUG_LINE_NO:185
    If Result != "" ; #DEBUG_LINE_NO:186
      FrameworkEventsScript.OnUniqueKnockOutEndEvent(Result, Victim, Helper) ; #DEBUG_LINE_NO:187
    EndIf
  Else
    FrameworkEventsScript.OnKoKilledEvent(Victim, Victim.GetKiller()) ; #DEBUG_LINE_NO:190
  EndIf
  Return True ; #DEBUG_LINE_NO:192
EndFunction

Function SetKOStatusOff(Actor Victim)
  If !Victim
    Return
  ElseIf Victim == Player
    ; Never wait for the desktop GetUpStart graph on the VR player.
    Self.RestorePlayerVRState(Victim)
    Return
  EndIf
  Self.SetVictimHealth(Victim, KFReanimationHealth.GetValue()) ; #DEBUG_LINE_NO:196
  Victim.RemoveKeyword(KFKnockedOutKeyword) ; #DEBUG_LINE_NO:197
  Victim.RemoveKeyword(VATSRestrictedTargetKeyword) ; #DEBUG_LINE_NO:198
  If Victim.Is3DLoaded() && !Victim.IsDead() ; #DEBUG_LINE_NO:199
    If Victim != Player ; #DEBUG_LINE_NO:200
      Actor Aggressor = Victim.GetLinkedRef(KFKnockoutAggressorKeyword) as Actor ; #DEBUG_LINE_NO:201
      If Aggressor as Bool && Aggressor != Victim ; #DEBUG_LINE_NO:202
        Victim.StartCombat(Aggressor, False) ; #DEBUG_LINE_NO:203
      EndIf
    EndIf
    Self.WaitForRagdollExit(Victim) ; #DEBUG_LINE_NO:206
  Else
    Victim.SetValue(Paralysis, 0.0) ; #DEBUG_LINE_NO:208
  EndIf
  ; Always provide a fallback if the animation effect never receives GetUpStart.
  Victim.SetValue(Paralysis, 0.0)
  Victim.SetLinkedRef(None, KFKnockoutAggressorKeyword) ; #DEBUG_LINE_NO:210
  Victim.SetLinkedRef(None, KFKoExitRagdollKeyword)
  Victim.SetNotShowOnStealthMeter(False) ; #DEBUG_LINE_NO:211
  Victim.SetUnconscious(False) ; #DEBUG_LINE_NO:212
  Victim.EvaluatePackage(False) ; #DEBUG_LINE_NO:213
EndFunction

Function WaitForRagdollExit(Actor Victim)
  If Victim.IsGhost() ; #DEBUG_LINE_NO:217
    Bool RemovedGetUpSpell = Victim.DispelSpell(KFKoExitRagdollSpell)
    Utility.Wait(2.0) ; #DEBUG_LINE_NO:218
    Victim.SetLinkedRef(None, KFKoExitRagdollKeyword)
    Victim.SetValue(Paralysis, 0.0)
    Return  ; #DEBUG_LINE_NO:219
  EndIf
  Victim.SetLinkedRef(None, KFKoExitRagdollKeyword) ; #DEBUG_LINE_NO:222
  Victim.DoCombatSpellApply(KFKoExitRagdollSpell, Victim as ObjectReference) ; #DEBUG_LINE_NO:223
  Int WaitCount = 0 ; #DEBUG_LINE_NO:224
  Bool ReceivedGetUp = False
  While WaitCount < 20 ; #DEBUG_LINE_NO:225
    If Victim.GetLinkedRef(KFKoExitRagdollKeyword) == Victim as ObjectReference ; #DEBUG_LINE_NO:226
      ReceivedGetUp = True
      Victim.SetLinkedRef(None, KFKoExitRagdollKeyword) ; #DEBUG_LINE_NO:227
      WaitCount = 20 ; #DEBUG_LINE_NO:228
    Else
      WaitCount += 1 ; #DEBUG_LINE_NO:230
      Utility.Wait(0.25) ; #DEBUG_LINE_NO:231
    EndIf
  EndWhile
  If !ReceivedGetUp
    ; Unloaded graphs and VR may never emit the get-up event. End KF's effect so
    ; its finish handler can clear Ghost, then force the actor value fallback.
    Bool Result = Victim.DispelSpell(KFKoExitRagdollSpell)
  EndIf
  ; End the framework effect even when its linked-ref completion arrived first.
  Bool RemovedGetUpSpell = Victim.DispelSpell(KFKoExitRagdollSpell)
  Victim.SetValue(Paralysis, 0.0)
EndFunction

Function StartKoCountdown(Int Index)
  If KFKoTimeMin.GetValue() > KFKoTimeMax.GetValue() ; #DEBUG_LINE_NO:237
    KFKoTimeMin.SetValue(KFKoTimeMax.GetValue()) ; #DEBUG_LINE_NO:238
  EndIf
  KOCollectionScript.StartKOActorTimer(Index, Utility.RandomFloat(KFKoTimeMin.GetValue(), KFKoTimeMax.GetValue())) ; #DEBUG_LINE_NO:240
EndFunction

Bool Function SetKoCountdown(Actor Victim, Float KoDuration)
  If !Victim || !Victim.HasKeyword(KFKnockedOutKeyword) ; #DEBUG_LINE_NO:244
    Return False ; #DEBUG_LINE_NO:245
  EndIf
  If KOCollectionScript == None || KOCollectionScript.KOActors == None
    Return False
  EndIf
  Actor[] KOActors = KOCollectionScript.KOActors
  Int Index = KOActors.find(Victim, 0) ; #DEBUG_LINE_NO:247
  If Index < 0 ; #DEBUG_LINE_NO:248
    Return False ; #DEBUG_LINE_NO:249
  EndIf
  KOCollectionScript.StartKOActorTimer(Index, KoDuration) ; #DEBUG_LINE_NO:251
  Return True ; #DEBUG_LINE_NO:252
EndFunction

Function FallDamages(Actor Victim, Float FallDamages)
  If !KFFallEnabled.GetValue() || Victim.IsDead() ; #DEBUG_LINE_NO:256
    Return  ; #DEBUG_LINE_NO:257
  EndIf
  String[] DiffMultString = new String[7] ; #DEBUG_LINE_NO:260
  DiffMultString[0] = "fDiffMultHPToPCVE" ; #DEBUG_LINE_NO:261
  DiffMultString[1] = "fDiffMultHPToPCE" ; #DEBUG_LINE_NO:262
  DiffMultString[2] = "fDiffMultHPToPCN" ; #DEBUG_LINE_NO:263
  DiffMultString[3] = "fDiffMultHPToPCH" ; #DEBUG_LINE_NO:264
  DiffMultString[4] = "fDiffMultHPToPCVH" ; #DEBUG_LINE_NO:265
  DiffMultString[6] = "fDiffMultHPToPCSV" ; #DEBUG_LINE_NO:266
  Float DiffMult = Game.GetGameSettingFloat(DiffMultString[Game.GetDifficulty()]) ; #DEBUG_LINE_NO:267
  FallDamages *= DiffMult ; #DEBUG_LINE_NO:269
  Float NewHealth = Victim.GetValue(Health) + FallDamages ; #DEBUG_LINE_NO:270
  Float HealthLoss = FallDamages * 100.0 ; #DEBUG_LINE_NO:271
  If NewHealth - HealthLoss < 0.100000001 ; #DEBUG_LINE_NO:272
    If HealthLoss > Victim.GetBaseValue(Health) + NewHealth ; #DEBUG_LINE_NO:273
      Victim.Kill(None) ; #DEBUG_LINE_NO:274
    Else
      Victim.DamageValue(LeftMobilityCondition, Victim.GetValue(LeftMobilityCondition)) ; #DEBUG_LINE_NO:276
      Victim.DamageValue(RightMobilityCondition, Victim.GetValue(RightMobilityCondition)) ; #DEBUG_LINE_NO:277
      Bool Result = Self.KnockOutActor(Victim, Victim, 0, False) ; #DEBUG_LINE_NO:278
      If !Result
        ; The vanilla perk already applied one percent. Apply the remaining
        ; simulated fall damage if KO is disabled or admission loses a race.
        Victim.DamageValue(Health, HealthLoss - FallDamages)
      EndIf
    EndIf
  Else
    Victim.DamageValue(Health, HealthLoss - FallDamages) ; #DEBUG_LINE_NO:281
  EndIf
EndFunction

Function SetVictimHealth(Actor Victim, Float HealthPercent)
  Float RestoredHealth = Victim.GetBaseValue(Health) * HealthPercent ; #DEBUG_LINE_NO:286
  Float CurrentHealth = Victim.GetValue(Health) ; #DEBUG_LINE_NO:287
  If RestoredHealth > CurrentHealth ; #DEBUG_LINE_NO:288
    Victim.RestoreValue(Health, RestoredHealth - CurrentHealth) ; #DEBUG_LINE_NO:289
  Else
    Victim.DamageValue(Health, CurrentHealth - RestoredHealth) ; #DEBUG_LINE_NO:291
  EndIf
EndFunction

Bool Function KnockOutFollower(Actor Victim)
  If !KFCanBeKoFollowers.GetValue() || !Victim.HasPerk(KFIncomingMonitoringPerk) ; #DEBUG_LINE_NO:296
    Return False ; #DEBUG_LINE_NO:297
  Else
    Return True ; #DEBUG_LINE_NO:299
  EndIf
EndFunction

Bool Function BleedingOut(Actor Victim, Actor Aggressor)
  If Victim.IsPlayerTeammate() ; #DEBUG_LINE_NO:304
    If KFCanBeKoFollowers.GetValue() ; #DEBUG_LINE_NO:305
      Victim.StopCombatAlarm() ; #DEBUG_LINE_NO:306
      Victim.SetNoBleedoutRecovery(False) ; #DEBUG_LINE_NO:307
    Else
      Return False ; #DEBUG_LINE_NO:309
    EndIf
  EndIf
  Int WaitCount = 0 ; #DEBUG_LINE_NO:313
  While WaitCount < 15 ; #DEBUG_LINE_NO:314
    If Victim.IsBleedingOut() ; #DEBUG_LINE_NO:315
      WaitCount += 1 ; #DEBUG_LINE_NO:316
      Utility.Wait(0.200000003) ; #DEBUG_LINE_NO:317
    Else
      WaitCount = 15 ; #DEBUG_LINE_NO:319
    EndIf
  EndWhile
  If !Victim.GetNoBleedoutRecovery() ; #DEBUG_LINE_NO:323
    Return Self.KnockOutActor(Victim, Aggressor, 3, False) ; #DEBUG_LINE_NO:324
  EndIf
  Return False ; #DEBUG_LINE_NO:326
EndFunction

Function StealActorItems(Actor Victim, ObjectReference[] Destinations)
  If !Victim || Destinations.Length < 1 ; #DEBUG_LINE_NO:330
    Return  ; #DEBUG_LINE_NO:331
  EndIf
  TempAlias.ForceRefTo(Victim as ObjectReference) ; #DEBUG_LINE_NO:333
  (TempAlias as kfmanagerquesttempaliasscript).StealActorItems(Destinations) ; #DEBUG_LINE_NO:334
  TempAlias.Clear() ; #DEBUG_LINE_NO:335
EndFunction

Bool Function ApplyPlayerConvalescenceEffect()
  If KFConvalescenceEffectEnabled.GetValue() ; #DEBUG_LINE_NO:339
    Player.EquipItem(KFConvalescencePotion as Form, False, True) ; #DEBUG_LINE_NO:340
    Return True ; #DEBUG_LINE_NO:341
  Else
    Return False ; #DEBUG_LINE_NO:343
  EndIf
EndFunction

Function DispelPlayerConvalescenceEffect(Int Stage)
  If Stage == 1 ; #DEBUG_LINE_NO:348
    Player.EquipItem(KFConvalescenceDispel1Potion as Form, False, True) ; #DEBUG_LINE_NO:349
  ElseIf Stage == 2 ; #DEBUG_LINE_NO:350
    Player.EquipItem(KFConvalescenceDispel2Potion as Form, False, True) ; #DEBUG_LINE_NO:351
  Else
    Player.EquipItem(KFConvalescenceDispel3Potion as Form, False, True) ; #DEBUG_LINE_NO:353
  EndIf
EndFunction

;-- State -------------------------------------------
Auto State Uninitialized

  Bool Function KnockOutActor(Actor Victim, Actor Aggressor, Int KillMoveType, Bool SilentKo)
    Return False ; #DEBUG_LINE_NO:52
  EndFunction
EndState
