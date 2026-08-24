ScriptName KFPlayerDefaultKnockoutQuestScript Extends Quest

;-- Variables ---------------------------------------
ObjectReference LastBed
ObjectReference ActiveBedMarker
Actor ActiveVictim
Float TimeScaleBackup
Bool TimeScaleOverridden
Bool ScenarioActive
Bool CrossFadeOwned
Bool DeathEventSuppressionOwned
Bool CleanupInProgress
Int ScenarioGeneration
Int ActiveScenarioGeneration
Int ActiveTimeScaleTimerID = -1
Int ActiveWatchdogTimerID = -1
Int TimeScaleOwnerGeneration
Int CrossFadeOwnerGeneration
Int BedMarkerOwnerGeneration
Int DeathEventSuppressionOwnerGeneration

;-- Properties --------------------------------------
koframeworkevents Property KFManagerQuest Auto Const
workshopparentscript Property WorkshopParent Auto Const
hardcore:hc_managerscript Property HCScript Auto Const
ImageSpaceModifier Property KFPlayerConvalescenceImod Auto Const
RefCollectionAlias Property Aggressors Auto Const
GlobalVariable Property TimeScale Auto Const
GlobalVariable Property KFDefScenarioChances Auto Const
GlobalVariable Property KFDefScenarioItemsCanBeStolen Auto Const
GlobalVariable Property KFDefScenarioShareStolenItemsWithAllies Auto Const
GlobalVariable Property KFDefScenarioStolenItemsTrackingQuest Auto Const
GlobalVariable Property KFDefScenarioUnconsciousnessDuration Auto Const
GlobalVariable Property KFDefScenarioRespawn Auto Const
GlobalVariable Property KFIgnorePlayerDeathEvent Auto Const
Keyword Property IsSleepFurniture Auto Const
Keyword Property AnimFurnBedAnims Auto Const
Keyword Property AnimFurnFloorBedAnims Auto Const
Message Property KFDefScenarioCheckpointUpdatedMessage Auto Const
Spell Property KFFindNearestNPCsSpell Auto Const
Form Property XMarker Auto Const
Form[] Property SafeLocationsAndKeywords Auto Const
ObjectReference[] Property NearestNPCs Auto hidden

;-- Functions ---------------------------------------

Function Initialization()
  Self.RecoverInterruptedScenario()
  Self.RegisterForQuestEvents() ; #DEBUG_LINE_NO:33
EndFunction

Bool Function OwnsScenario(Int Generation)
  Return Generation > 0 && Generation == ActiveScenarioGeneration
EndFunction

Bool Function IsScenarioGenerationCurrent(Int Generation)
  Return ScenarioActive && !CleanupInProgress && Self.OwnsScenario(Generation)
EndFunction

Int Function ClaimScenario(Actor Victim)
  ScenarioGeneration += 1
  ; Keep generated timer IDs positive even after an eventual signed Int wrap.
  If ScenarioGeneration < 1 || ScenarioGeneration > 1000000000
    ScenarioGeneration = 1
  EndIf
  ActiveScenarioGeneration = ScenarioGeneration
  ActiveTimeScaleTimerID = 100 + ScenarioGeneration * 2
  ActiveWatchdogTimerID = ActiveTimeScaleTimerID + 1
  ActiveVictim = Victim
  ScenarioActive = True
  Return ActiveScenarioGeneration
EndFunction

Function RestoreTimeScale(Int Generation)
  If TimeScaleOwnerGeneration != Generation
    Return
  EndIf
  If ActiveTimeScaleTimerID >= 0
    Self.CancelTimer(ActiveTimeScaleTimerID)
  EndIf
  If TimeScaleOverridden
    TimeScale.SetValue(TimeScaleBackup)
    TimeScaleOverridden = False
  EndIf
  TimeScaleOwnerGeneration = 0
EndFunction

Function RestorePlayerMovement(Actor Victim, Int Generation)
  If !Self.OwnsScenario(Generation) || !Victim || Victim.IsDead()
    Return
  EndIf
  Victim.SetNoBleedoutRecovery(False)
  Victim.SetUnconscious(False)
  Victim.SetRestrained(False)
  Game.SetPlayerAIDriven(False)
EndFunction

Function RemoveOwnedBedMarker(Int Generation)
  If BedMarkerOwnerGeneration != Generation
    Return
  EndIf
  If ActiveBedMarker
    ActiveBedMarker.Delete()
    ActiveBedMarker = None
  EndIf
  BedMarkerOwnerGeneration = 0
EndFunction

Function FinishOwnedCrossFade(Int Generation, Float FadeSeconds = 0.5)
  If CrossFadeOwned && CrossFadeOwnerGeneration == Generation
    ImageSpaceModifier.RemoveCrossFade(FadeSeconds)
    CrossFadeOwned = False
    CrossFadeOwnerGeneration = 0
  EndIf
EndFunction

Function CleanupScenario(Int Generation, Bool WakePlayer = True)
  If !Self.OwnsScenario(Generation) || CleanupInProgress
    Return
  EndIf
  CleanupInProgress = True
  Actor Victim = ActiveVictim
  Int TimeScaleTimerID = ActiveTimeScaleTimerID
  Int WatchdogTimerID = ActiveWatchdogTimerID
  ; Invalidate every latent continuation before invoking any cleanup operation.
  ScenarioActive = False
  If TimeScaleTimerID >= 0
    Self.CancelTimer(TimeScaleTimerID)
  EndIf
  If WatchdogTimerID >= 0
    Self.CancelTimer(WatchdogTimerID)
  EndIf
  Self.RestoreTimeScale(Generation)
  Self.FinishOwnedCrossFade(Generation, 0.5)
  Self.RemoveOwnedBedMarker(Generation)
  If WakePlayer && Victim && !Victim.IsDead()
    koframeworkfunctions.WakeKnockedOutActor(Victim, None)
  EndIf
  Self.RestorePlayerMovement(Victim, Generation)
  If DeathEventSuppressionOwned && DeathEventSuppressionOwnerGeneration == Generation
    KFIgnorePlayerDeathEvent.SetValue(0.0)
    DeathEventSuppressionOwned = False
    DeathEventSuppressionOwnerGeneration = 0
  EndIf
  NearestNPCs = new ObjectReference[0]
  ActiveVictim = None
  ActiveTimeScaleTimerID = -1
  ActiveWatchdogTimerID = -1
  ActiveScenarioGeneration = 0
  Self.GotoState("")
  CleanupInProgress = False
EndFunction

Function RecoverInterruptedScenario(Bool ForceCleanup = False)
  If CleanupInProgress
    If !ForceCleanup
      Return
    EndIf
    ; A load cannot resume the pre-save cleanup stack reliably. Re-acquire its
    ; serialized ownership and finish it exactly once.
    CleanupInProgress = False
  EndIf
  If ScenarioActive || TimeScaleOverridden || CrossFadeOwned || DeathEventSuppressionOwned || ActiveBedMarker
    ; Adopt fields serialized by a pre-generation build, then clean only that
    ; owned generation. Old fixed-ID timers are harmless but are cancelled too.
    If ActiveScenarioGeneration < 1
      ScenarioGeneration += 1
      If ScenarioGeneration < 1 || ScenarioGeneration > 1000000000
        ScenarioGeneration = 1
      EndIf
      ActiveScenarioGeneration = ScenarioGeneration
    EndIf
    If TimeScaleOverridden && TimeScaleOwnerGeneration < 1
      TimeScaleOwnerGeneration = ActiveScenarioGeneration
    EndIf
    If CrossFadeOwned && CrossFadeOwnerGeneration < 1
      CrossFadeOwnerGeneration = ActiveScenarioGeneration
    EndIf
    If ActiveBedMarker && BedMarkerOwnerGeneration < 1
      BedMarkerOwnerGeneration = ActiveScenarioGeneration
    EndIf
    If DeathEventSuppressionOwned && DeathEventSuppressionOwnerGeneration < 1
      DeathEventSuppressionOwnerGeneration = ActiveScenarioGeneration
    EndIf
    Self.CancelTimer(91)
    Self.CancelTimer(92)
    Self.CleanupScenario(ActiveScenarioGeneration, True)
  ElseIf ForceCleanup
    ; Finish a save made after cleanup invalidated the scenario but before it
    ; cleared its bookkeeping fields.
    If ActiveTimeScaleTimerID >= 0
      Self.CancelTimer(ActiveTimeScaleTimerID)
    EndIf
    If ActiveWatchdogTimerID >= 0
      Self.CancelTimer(ActiveWatchdogTimerID)
    EndIf
    NearestNPCs = new ObjectReference[0]
    ActiveVictim = None
    ActiveTimeScaleTimerID = -1
    ActiveWatchdogTimerID = -1
    ActiveScenarioGeneration = 0
    ; A v1.4 save can have the Running state without the ownership fields added
    ; by this port. Only that state authorizes clearing its legacy globals/fade.
    If Self.GetState() == "Running"
      KFIgnorePlayerDeathEvent.SetValue(0.0)
      ImageSpaceModifier.RemoveCrossFade(0.5)
    EndIf
    Self.GotoState("")
  EndIf
EndFunction

Function WaitFor3DLoadBounded(ObjectReference Target, Int Generation, Int MaxChecks = 20)
  Int Check = 0
  While Self.IsScenarioGenerationCurrent(Generation) && Target && !Target.Is3DLoaded() && Check < MaxChecks
    Utility.Wait(0.25)
    Check += 1
  EndWhile
EndFunction

Event OnTimer(Int aiTimerID)
  Int Generation = ActiveScenarioGeneration
  If Self.IsScenarioGenerationCurrent(Generation) && aiTimerID == ActiveTimeScaleTimerID
    Self.RestoreTimeScale(Generation)
  ElseIf Self.IsScenarioGenerationCurrent(Generation) && aiTimerID == ActiveWatchdogTimerID
    Self.CleanupScenario(Generation, True)
  EndIf
EndEvent

Function RegisterForQuestEvents()
  koframeworkfunctions.RegisterForUniqueKnockOutStartEvent("Knockout Framework.esm", "PlayerDefaultKnockout", KFDefScenarioChances.GetValue() as Int, Game.GetPlayer() as Form, None) ; #DEBUG_LINE_NO:37
  Self.RegisterForCustomEvent(KFManagerQuest, "OnUniqueKnockOutStart") ; #DEBUG_LINE_NO:38
  Self.RegisterForPlayerSleep() ; #DEBUG_LINE_NO:39
EndFunction

Event OnPlayerSleepStop(Bool abInterrupted, ObjectReference akBed)
  If !akBed
    Return
  EndIf
  If KFDefScenarioRespawn.GetValue() == 1.0 ; #DEBUG_LINE_NO:43
    LastBed = akBed ; #DEBUG_LINE_NO:44
    KFDefScenarioCheckpointUpdatedMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:45
    Return  ; #DEBUG_LINE_NO:46
  EndIf
  Location[] UnallowedLocations = new Location[0] ; #DEBUG_LINE_NO:49
  Int Count = 0 ; #DEBUG_LINE_NO:50
  Int Total = WorkshopParent.Workshops.Length ; #DEBUG_LINE_NO:51
  While Count < Total ; #DEBUG_LINE_NO:52
    If WorkshopParent.Workshops[Count].OwnedByPlayer ; #DEBUG_LINE_NO:53
      If akBed.IsWithinBuildableArea(WorkshopParent.Workshops[Count] as ObjectReference) ; #DEBUG_LINE_NO:54
        LastBed = akBed ; #DEBUG_LINE_NO:55
        KFDefScenarioCheckpointUpdatedMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:56
        Return  ; #DEBUG_LINE_NO:57
      EndIf
    ElseIf WorkshopParent.Workshops[Count].GetCurrentLocation() != None ; #DEBUG_LINE_NO:59
      UnallowedLocations.add(WorkshopParent.Workshops[Count].GetCurrentLocation(), 1) ; #DEBUG_LINE_NO:60
    EndIf
    Count += 1 ; #DEBUG_LINE_NO:62
  EndWhile
  Count = 0 ; #DEBUG_LINE_NO:65
  Total = SafeLocationsAndKeywords.Length ; #DEBUG_LINE_NO:66
  Location CurrentLocation = None ; #DEBUG_LINE_NO:67
  While Count < Total ; #DEBUG_LINE_NO:68
    CurrentLocation = akBed.GetCurrentLocation() ; #DEBUG_LINE_NO:69
    If UnallowedLocations.find(CurrentLocation, 0) < 0 ; #DEBUG_LINE_NO:70
      If SafeLocationsAndKeywords[Count] as Location ; #DEBUG_LINE_NO:71
        If CurrentLocation == SafeLocationsAndKeywords[Count] as Location ; #DEBUG_LINE_NO:72
          LastBed = akBed ; #DEBUG_LINE_NO:73
          KFDefScenarioCheckpointUpdatedMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:74
          Return  ; #DEBUG_LINE_NO:75
        EndIf
      ElseIf SafeLocationsAndKeywords[Count] as Keyword ; #DEBUG_LINE_NO:77
        If CurrentLocation && CurrentLocation.HasKeyword(SafeLocationsAndKeywords[Count] as Keyword) ; #DEBUG_LINE_NO:78
          LastBed = akBed ; #DEBUG_LINE_NO:79
          KFDefScenarioCheckpointUpdatedMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:80
          Return  ; #DEBUG_LINE_NO:81
        EndIf
      EndIf
    EndIf
    Count += 1 ; #DEBUG_LINE_NO:85
  EndWhile
EndEvent

Event KoFrameworkEvents.OnUniqueKnockOutStart(koframeworkevents akSender, Var[] Arguments)
  If Arguments.Length < 3
    Return
  EndIf
  String EventName = Arguments[0] as String ; #DEBUG_LINE_NO:90
  Actor Victim = Arguments[1] as Actor ; #DEBUG_LINE_NO:91
  Actor Aggressor = Arguments[2] as Actor ; #DEBUG_LINE_NO:92
  If EventName != "PlayerDefaultKnockout" || !Victim ; #DEBUG_LINE_NO:93
    Return  ; #DEBUG_LINE_NO:94
  EndIf
  Self.RecoverInterruptedScenario()
  If CleanupInProgress
    Return
  EndIf
  Int Generation = Self.ClaimScenario(Victim)
  Self.GotoState("Running") ; #DEBUG_LINE_NO:99
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Self.StartTimer(60.0, ActiveWatchdogTimerID)
  DeathEventSuppressionOwned = True
  DeathEventSuppressionOwnerGeneration = Generation
  KFIgnorePlayerDeathEvent.SetValue(1.0) ; #DEBUG_LINE_NO:100
  ObjectReference CurrentLastBed = LastBed ; #DEBUG_LINE_NO:101
  Int RespawnMethod = KFDefScenarioRespawn.GetValue() as Int ; #DEBUG_LINE_NO:102
  If RespawnMethod <= 1 && !Self.TestBedAvailability(CurrentLastBed) ; #DEBUG_LINE_NO:104
    Self.CantBeKnockedOutForGeneration(Victim, Generation) ; #DEBUG_LINE_NO:105
    Return  ; #DEBUG_LINE_NO:106
  EndIf
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  CrossFadeOwned = True
  CrossFadeOwnerGeneration = Generation
  KFPlayerConvalescenceImod.ApplyCrossFade(3.0) ; #DEBUG_LINE_NO:109
  NearestNPCs = new ObjectReference[0] ; #DEBUG_LINE_NO:111
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Victim.DoCombatSpellApply(KFFindNearestNPCsSpell, Victim as ObjectReference) ; #DEBUG_LINE_NO:112
  Utility.Wait(1.5) ; #DEBUG_LINE_NO:113
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Actor Thief = None ; #DEBUG_LINE_NO:115
  If KFDefScenarioItemsCanBeStolen.GetValue() ; #DEBUG_LINE_NO:116
    If Aggressor as Bool && NearestNPCs.find(Aggressor as ObjectReference, 0) >= 0 ; #DEBUG_LINE_NO:117
      Thief = Aggressor ; #DEBUG_LINE_NO:118
    ElseIf NearestNPCs.Length > 0 ; #DEBUG_LINE_NO:119
      Thief = NearestNPCs[0] as Actor ; #DEBUG_LINE_NO:120
    EndIf
  EndIf
  NearestNPCs = new ObjectReference[0] ; #DEBUG_LINE_NO:124
  If Thief ; #DEBUG_LINE_NO:125
    If KFDefScenarioShareStolenItemsWithAllies.GetValue() ; #DEBUG_LINE_NO:126
      NearestNPCs.add(Thief as ObjectReference, 2) ; #DEBUG_LINE_NO:127
      If !Self.IsScenarioGenerationCurrent(Generation)
        Return
      EndIf
      Thief.DoCombatSpellApply(KFFindNearestNPCsSpell, Thief as ObjectReference) ; #DEBUG_LINE_NO:128
    Else
      NearestNPCs.add(Thief as ObjectReference, 1) ; #DEBUG_LINE_NO:130
    EndIf
  EndIf
  Utility.Wait(1.5) ; #DEBUG_LINE_NO:134
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Int NearestNPCsLength = NearestNPCs.Length ; #DEBUG_LINE_NO:135
  Bool StealItems = NearestNPCsLength > 0 ; #DEBUG_LINE_NO:136
  Int Index = 0 ; #DEBUG_LINE_NO:137
  If RespawnMethod < 3 ; #DEBUG_LINE_NO:140
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    koframeworkfunctions.WakeKnockedOutActor(Victim, None) ; #DEBUG_LINE_NO:141
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    Self.RestorePlayerMovement(Victim, Generation)
    If RespawnMethod == 2 ; #DEBUG_LINE_NO:145
      ObjectReference[] ListBedFound = Victim.FindAllReferencesWithKeyword(IsSleepFurniture as Form, 17507.0) ; #DEBUG_LINE_NO:146
      If !Self.IsScenarioGenerationCurrent(Generation)
        Return
      EndIf
      Index = 0 ; #DEBUG_LINE_NO:147
      Int Total = ListBedFound.Length ; #DEBUG_LINE_NO:148
      Bool LookForSafeBed = True ; #DEBUG_LINE_NO:149
      Float FoundDistance = 99999.0 ; #DEBUG_LINE_NO:150
      Actor ClosestActor = None ; #DEBUG_LINE_NO:151
      ObjectReference BedFound = None ; #DEBUG_LINE_NO:152
      While Index < Total && Self.IsScenarioGenerationCurrent(Generation) ; #DEBUG_LINE_NO:153
        If ListBedFound[Index] && (ListBedFound[Index].HasKeyword(AnimFurnBedAnims) || ListBedFound[Index].HasKeyword(AnimFurnFloorBedAnims)) ; #DEBUG_LINE_NO:154
          ClosestActor = Game.FindClosestActorFromRef(ListBedFound[Index], 2801.120117188) ; #DEBUG_LINE_NO:155
          If !LookForSafeBed || !ClosestActor || ClosestActor.IsDead() || !ClosestActor.IsHostileToActor(Victim) ; #DEBUG_LINE_NO:156
            Float CandidateDistance = 0.0
            Bool CandidateIsBetter = False
            If LookForSafeBed
              CandidateDistance = ListBedFound[Index].GetDistance(Victim as ObjectReference)
              CandidateIsBetter = CandidateDistance < FoundDistance
            ElseIf ClosestActor
              CandidateDistance = ListBedFound[Index].GetDistance(ClosestActor as ObjectReference)
              CandidateIsBetter = CandidateDistance > FoundDistance
            Else
              ; No nearby actor is safer than any measured fallback candidate.
              CandidateDistance = 2801.120117188
              CandidateIsBetter = CandidateDistance > FoundDistance
            EndIf
            If CandidateIsBetter && Self.TestBedAvailability(ListBedFound[Index]) ; #DEBUG_LINE_NO:157
              BedFound = ListBedFound[Index] ; #DEBUG_LINE_NO:158
              FoundDistance = CandidateDistance
            EndIf
          EndIf
        EndIf
        Index += 1 ; #DEBUG_LINE_NO:167
        If Index == Total && LookForSafeBed && !BedFound ; #DEBUG_LINE_NO:168
          LookForSafeBed = False ; #DEBUG_LINE_NO:169
          FoundDistance = -1.0
          Index = 0 ; #DEBUG_LINE_NO:170
        EndIf
      EndWhile
      If !Self.IsScenarioGenerationCurrent(Generation)
        Return
      EndIf
      If BedFound ; #DEBUG_LINE_NO:174
        CurrentLastBed = BedFound ; #DEBUG_LINE_NO:175
      ElseIf !Self.TestBedAvailability(CurrentLastBed) ; #DEBUG_LINE_NO:176
        Self.CantBeKnockedOutForGeneration(Victim, Generation) ; #DEBUG_LINE_NO:177
        Return  ; #DEBUG_LINE_NO:178
      EndIf
    EndIf
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    ObjectReference NewBedMarker = CurrentLastBed.PlaceAtMe(XMarker, 1, False, False, True) ; #DEBUG_LINE_NO:182
    If !Self.IsScenarioGenerationCurrent(Generation)
      If NewBedMarker
        NewBedMarker.Delete()
      EndIf
      Return
    EndIf
    ActiveBedMarker = NewBedMarker
    BedMarkerOwnerGeneration = Generation
    If ActiveBedMarker
      Victim.MoveTo(ActiveBedMarker, 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:183
    Else
      Self.CantBeKnockedOutForGeneration(Victim, Generation)
      Return
    EndIf
    Utility.Wait(2.5) ; #DEBUG_LINE_NO:185
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    Self.WaitFor3DLoadBounded(Victim, Generation, 20) ; #DEBUG_LINE_NO:186
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
  EndIf
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  koframeworkfunctions.ApplyPlayerConvalescenceEffect() ; #DEBUG_LINE_NO:189
  Bool WaitSupTime = False ; #DEBUG_LINE_NO:191
  If StealItems ; #DEBUG_LINE_NO:192
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    koframeworkfunctions.StealActorItems(Victim, NearestNPCs) ; #DEBUG_LINE_NO:193
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    Index = 0 ; #DEBUG_LINE_NO:195
    Actor NearestNPC = None ; #DEBUG_LINE_NO:196
    While Index < NearestNPCsLength && Self.IsScenarioGenerationCurrent(Generation) ; #DEBUG_LINE_NO:197
      NearestNPC = NearestNPCs[Index] as Actor ; #DEBUG_LINE_NO:198
      If koframeworkfunctions.IsKnockedOut(NearestNPC) ; #DEBUG_LINE_NO:199
        If NearestNPC.Is3DLoaded() ; #DEBUG_LINE_NO:200
          WaitSupTime = True ; #DEBUG_LINE_NO:201
        EndIf
        If !Self.IsScenarioGenerationCurrent(Generation)
          Return
        EndIf
        koframeworkfunctions.WakeKnockedOutActor(NearestNPC, None) ; #DEBUG_LINE_NO:203
      EndIf
      Index += 1 ; #DEBUG_LINE_NO:205
    EndWhile
  EndIf
  If WaitSupTime ; #DEBUG_LINE_NO:208
    Utility.Wait(3.5) ; #DEBUG_LINE_NO:209
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
  EndIf
  If RespawnMethod < 3 ; #DEBUG_LINE_NO:213
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    Victim.MoveTo(CurrentLastBed, 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:215
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    Self.RemoveOwnedBedMarker(Generation)
  Else
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    koframeworkfunctions.SetKnockOutCountdown(Victim, 9999.0) ; #DEBUG_LINE_NO:217
  EndIf
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  TimeScaleBackup = TimeScale.GetValue() ; #DEBUG_LINE_NO:220
  TimeScaleOverridden = True
  TimeScaleOwnerGeneration = Generation
  TimeScale.SetValue(1440.0 * KFDefScenarioUnconsciousnessDuration.GetValue()) ; #DEBUG_LINE_NO:221
  Self.StartTimer(5.0, ActiveTimeScaleTimerID)
  Utility.Wait(2.5) ; #DEBUG_LINE_NO:222
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Self.RestoreTimeScale(Generation) ; #DEBUG_LINE_NO:223
  If Game.GetDifficulty() == 6 ; #DEBUG_LINE_NO:225
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    HCScript.ModDrinkPoolAndUpdateThirstEffects(HCScript.iDrinkPoolSeverelyDehydratedAmount + HCScript.MaxDrinkValue * -1) ; #DEBUG_LINE_NO:226
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    HCScript.ModFoodPoolAndUpdateHungerEffects((HCScript.iFoodPoolStarvingAmount + HCScript.MaxFoodValue * -1) as Float, False) ; #DEBUG_LINE_NO:227
  EndIf
  If RespawnMethod < 3 ; #DEBUG_LINE_NO:230
    Self.WaitFor3DLoadBounded(Victim, Generation, 20) ; #DEBUG_LINE_NO:231
    Self.WaitFor3DLoadBounded(CurrentLastBed, Generation, 20) ; #DEBUG_LINE_NO:232
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    Self.FinishOwnedCrossFade(Generation, 4.0) ; #DEBUG_LINE_NO:233
    Utility.Wait(0.5) ; #DEBUG_LINE_NO:234
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
  Else
    Self.FinishOwnedCrossFade(Generation, 4.0) ; #DEBUG_LINE_NO:236
    Utility.Wait(3.0) ; #DEBUG_LINE_NO:237
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    koframeworkfunctions.WakeKnockedOutActor(Victim, None) ; #DEBUG_LINE_NO:238
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    Self.RestorePlayerMovement(Victim, Generation)
  EndIf
  If Game.GetDifficulty() == 6 ; #DEBUG_LINE_NO:241
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    HCScript.ModDrinkPoolAndUpdateThirstEffects(HCScript.iDrinkPoolSeverelyDehydratedAmount * -1 + HCScript.iDrinkPoolThirstyAmount) ; #DEBUG_LINE_NO:242
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    HCScript.ModFoodPoolAndUpdateHungerEffects((HCScript.iFoodPoolStarvingAmount * -1 + HCScript.iFoodPoolHungryAmount) as Float, False) ; #DEBUG_LINE_NO:243
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    Victim.SetValue(HCScript.HC_SleepEffect, HCScript.HC_SE_Rested.GetValue()) ; #DEBUG_LINE_NO:244
    If !Self.IsScenarioGenerationCurrent(Generation)
      Return
    EndIf
    HCScript.ApplyEffect(HCScript.HC_Rule_SleepEffects, HCScript.SleepEffects, HCScript.HC_SleepEffect, False, 0, False, True, True, False, True) ; #DEBUG_LINE_NO:245
  EndIf
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Self.RestorePlayerMovement(Victim, Generation)
  If StealItems ; #DEBUG_LINE_NO:265
    Index = 0 ; #DEBUG_LINE_NO:266
    While Index < NearestNPCsLength && Self.IsScenarioGenerationCurrent(Generation) ; #DEBUG_LINE_NO:267
      If !Self.IsScenarioGenerationCurrent(Generation)
        Return
      EndIf
      Self.AddAggressor(NearestNPCs[Index] as Actor) ; #DEBUG_LINE_NO:268
      Index += 1 ; #DEBUG_LINE_NO:269
    EndWhile
  EndIf
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  NearestNPCs = new ObjectReference[0] ; #DEBUG_LINE_NO:273
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Self.CleanupScenario(Generation, False) ; #DEBUG_LINE_NO:274
EndEvent

Bool Function TestBedAvailability(ObjectReference Bed)
  If !Bed || Bed.IsDisabled() || Bed.IsDeleted() || Bed.IsFurnitureInUse(False) ; #DEBUG_LINE_NO:279
    Return False ; #DEBUG_LINE_NO:280
  EndIf
  Return True ; #DEBUG_LINE_NO:282
EndFunction

Function CantBeKnockedOut(Actor Victim)
  ; Retain the v1.4 public signature for any scenario extension compiled against
  ; it while routing framework calls through the active generation.
  Self.CantBeKnockedOutForGeneration(Victim, ActiveScenarioGeneration)
EndFunction

Function CantBeKnockedOutForGeneration(Actor Victim, Int Generation)
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Victim.EndDeferredKill() ; #DEBUG_LINE_NO:287
  If !Self.IsScenarioGenerationCurrent(Generation)
    Return
  EndIf
  Victim.Kill(None) ; #DEBUG_LINE_NO:288
  Utility.Wait(0.5) ; #DEBUG_LINE_NO:289
  If Self.IsScenarioGenerationCurrent(Generation) && !Victim.IsDead() ; #DEBUG_LINE_NO:290
    koframeworkfunctions.WakeKnockedOutActor(Victim, None) ; #DEBUG_LINE_NO:291
  EndIf
  Self.CleanupScenario(Generation, False)
EndFunction

Function AddAggressor(Actor Aggressor)
  If Aggressors.Find(Aggressor as ObjectReference) >= 0 ; #DEBUG_LINE_NO:296
    Return  ; #DEBUG_LINE_NO:297
  EndIf
  Aggressors.AddRef(Aggressor as ObjectReference) ; #DEBUG_LINE_NO:299
  Self.UpdateQuestObjective() ; #DEBUG_LINE_NO:300
EndFunction

Function RemoveAggressor(Actor Aggressor)
  If Aggressors.Find(Aggressor as ObjectReference) < 0 ; #DEBUG_LINE_NO:304
    Return  ; #DEBUG_LINE_NO:305
  EndIf
  Aggressors.RemoveRef(Aggressor as ObjectReference) ; #DEBUG_LINE_NO:307
  Self.UpdateQuestObjective() ; #DEBUG_LINE_NO:308
EndFunction

Function UpdateQuestObjective()
  Int RefCount = Aggressors.GetCount() ; #DEBUG_LINE_NO:312
  If RefCount > 0 && !Self.IsObjectiveDisplayed(10) && KFDefScenarioStolenItemsTrackingQuest.GetValue() as Bool ; #DEBUG_LINE_NO:313
    Self.SetObjectiveCompleted(10, False) ; #DEBUG_LINE_NO:314
    Self.SetObjectiveDisplayed(10, True, True) ; #DEBUG_LINE_NO:315
  ElseIf Self.IsObjectiveDisplayed(10) && (RefCount < 1 || !KFDefScenarioStolenItemsTrackingQuest.GetValue()) ; #DEBUG_LINE_NO:316
    Self.SetObjectiveCompleted(10, True) ; #DEBUG_LINE_NO:317
    Self.SetObjectiveDisplayed(10, False, True) ; #DEBUG_LINE_NO:318
  EndIf
EndFunction

;-- State -------------------------------------------
State Running

  Event KoFrameworkEvents.OnUniqueKnockOutStart(koframeworkevents akSender, Var[] Arguments)
    If Arguments.Length < 2
      Return
    EndIf
    String EventName = Arguments[0] as String ; #DEBUG_LINE_NO:324
    Actor Victim = Arguments[1] as Actor ; #DEBUG_LINE_NO:325
    If EventName == "PlayerDefaultKnockout" ; #DEBUG_LINE_NO:327
      Self.CantBeKnockedOutForGeneration(Victim, ActiveScenarioGeneration) ; #DEBUG_LINE_NO:328
    EndIf
  EndEvent
EndState
