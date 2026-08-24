ScriptName KFManagerQuestConfigScript Extends Quest

CustomEvent UpdateMonitoringSpellEv

;-- Variables ---------------------------------------
ObjectReference CallBack
Bool CriticalUpdate = False
Bool MustUpdateMonitoringSpells = False
Bool MustUpdatePlayerDeferredKillState = False
Bool CallbackOwned = False
Bool CrossFadeOwned = False
Bool RefreshCleanupRunning = False

;-- Properties --------------------------------------
ObjectReference Property KFConfigurationMarker Auto Const
Message Property KFConfigRefreshMessage Auto Const
Spell Property KFMonitoringCloakSpell Auto Const
Spell Property KFMonitoringPlayerSpell Auto Const
Spell Property KFMonitoringSpell Auto Const
Spell Property KFTriggerKoSpell Auto Const
ImageSpaceModifier Property HoldAtBlackImod Auto
Static Property XMarkerHeading Auto Const
Actor Property Player Auto Const
Keyword Property KFActorCantKnockoutKeyword Auto Const
Keyword Property KFActorCantBeKnockedOutKeyword Auto Const
Keyword Property ActorTypeNPC Auto Const
Keyword Property ActorTypeSuperMutant Auto Const
Keyword Property ActorTypeFeralGhoul Auto Const
GlobalVariable Property KFCanKoPlayer Auto Const
GlobalVariable Property KFCanKoHumans Auto Const
GlobalVariable Property KFCanKoSuperMutants Auto Const
GlobalVariable Property KFCanKoFeralGhoul Auto Const
GlobalVariable Property KFCanKoOthers Auto Const
GlobalVariable Property KFCanBeKoPlayer Auto Const
GlobalVariable Property KFCanBeKoFollowers Auto Const
GlobalVariable Property KFCanBeKoHumans Auto Const
GlobalVariable Property KFCanBeKoSuperMutants Auto Const
GlobalVariable Property KFCanBeKoFeralGhoul Auto Const
GlobalVariable Property KFCanBeKoOthers Auto Const
GlobalVariable Property KFDeferPlayerDeathEnabled Auto Const

;-- Functions ---------------------------------------

Function RefreshActorsSpell(Bool CriticalUpdateFunc)
  CriticalUpdate = CriticalUpdateFunc
  MustUpdateMonitoringSpells = True
  Self.GotoState("RefreshState")
EndFunction

Function RefreshPlayerDeferredKillState(Bool CriticalUpdateFunc)
  CriticalUpdate = CriticalUpdateFunc
  MustUpdatePlayerDeferredKillState = True
  Self.GotoState("RefreshState")
EndFunction

Function OnLoadGame()
  RefreshCleanupRunning = False
  If CriticalUpdate || CallbackOwned || CrossFadeOwned || CallBack
    Self.RefreshStateEnd()
  EndIf
  Self.RegisterForExternalEvent("TriggerKoEvent", "TriggerKoEvent") ; #DEBUG_LINE_NO:42
  If !Player.HasSpell(KFMonitoringCloakSpell as Form) ; #DEBUG_LINE_NO:43
    Player.AddSpell(KFMonitoringCloakSpell, False) ; #DEBUG_LINE_NO:44
  EndIf
EndFunction

Function TriggerKoEvent(Actor Victim, Actor Aggressor)
  Aggressor.DoCombatSpellApply(KFTriggerKoSpell, Victim as ObjectReference) ; #DEBUG_LINE_NO:49
EndFunction

Function UpdateMonitoringCloakSpell()
  If Player.HasSpell(KFMonitoringCloakSpell as Form) ; #DEBUG_LINE_NO:65
    Player.RemoveSpell(KFMonitoringCloakSpell) ; #DEBUG_LINE_NO:66
    Utility.WaitMenuMode(0.25) ; #DEBUG_LINE_NO:67
  EndIf
  Player.AddSpell(KFMonitoringCloakSpell, False) ; #DEBUG_LINE_NO:69
EndFunction

Function UpdatePlayerMonitoringSpell()
  If Player.HasSpell(KFMonitoringPlayerSpell as Form) ; #DEBUG_LINE_NO:73
    Player.RemoveSpell(KFMonitoringPlayerSpell) ; #DEBUG_LINE_NO:74
    Utility.WaitMenuMode(0.25) ; #DEBUG_LINE_NO:75
  EndIf
  Player.AddSpell(KFMonitoringPlayerSpell, False) ; #DEBUG_LINE_NO:77
EndFunction

Function UpdateNPCsMonitoringSpells()
  Var[] kargs = new Var[1] ; #DEBUG_LINE_NO:81
  kargs[0] = KFMonitoringSpell as Var ; #DEBUG_LINE_NO:82
  Self.SendCustomEvent("UpdateMonitoringSpellEv", kargs) ; #DEBUG_LINE_NO:83
EndFunction

Function UpdatePlayerDeferredKillState()
  Bool DeferredDeath = KFDeferPlayerDeathEnabled.GetValue() as Bool && KFCanBeKoPlayer.GetValue() as Bool ; #DEBUG_LINE_NO:87
  Bool WasEssential = Player.IsEssential() ; #DEBUG_LINE_NO:88
  If !WasEssential && !DeferredDeath ; #DEBUG_LINE_NO:89
    Player.SetEssential(True) ; #DEBUG_LINE_NO:90
  EndIf
  Utility.WaitMenuMode(0.100000001) ; #DEBUG_LINE_NO:92
  If DeferredDeath ; #DEBUG_LINE_NO:93
    Player.StartDeferredKill() ; #DEBUG_LINE_NO:94
  Else
    Player.EndDeferredKill() ; #DEBUG_LINE_NO:96
    If KFCanBeKoPlayer.GetValue() == 0.0 && !Player.IsDead()
      ; Only undo actor state when the manager can prove framework ownership.
      KFManagerQuestMainScript Manager = Game.GetFormFromFile(0x00000F99, "Knockout Framework.esm") as KFManagerQuestMainScript
      If Manager
        Manager.RestorePlayerVRState(Player)
      EndIf
    EndIf
    Utility.Wait(1.0) ; #DEBUG_LINE_NO:97
  EndIf
  Utility.Wait(0.100000001) ; #DEBUG_LINE_NO:99
  If !WasEssential && !DeferredDeath ; #DEBUG_LINE_NO:100
    Player.SetEssential(False) ; #DEBUG_LINE_NO:101
  EndIf
EndFunction

Function SetPlayerValue(ActorValue AV, Float SavedValue)
  Float CurrentValue = Player.GetValue(AV) ; #DEBUG_LINE_NO:106
  If SavedValue > CurrentValue ; #DEBUG_LINE_NO:107
    Player.RestoreValue(AV, SavedValue - CurrentValue) ; #DEBUG_LINE_NO:108
  Else
    Player.DamageValue(AV, CurrentValue - SavedValue) ; #DEBUG_LINE_NO:110
  EndIf
EndFunction

Function RefreshStateEnd()
  If RefreshCleanupRunning
    Return
  EndIf
  RefreshCleanupRunning = True
  Self.CancelTimer(0) ; #DEBUG_LINE_NO:187
  Self.UnregisterForPlayerTeleport() ; #DEBUG_LINE_NO:188
  If CriticalUpdate && CallBack
    Player.MoveTo(CallBack, 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:189
    Utility.Wait(0.01) ; #DEBUG_LINE_NO:190
  EndIf
  If CallbackOwned && CallBack
    CallBack.Delete()
  EndIf
  CallbackOwned = False
  CallBack = None ; #DEBUG_LINE_NO:191
  If CrossFadeOwned
    ImageSpaceModifier.RemoveCrossFade(1.5) ; #DEBUG_LINE_NO:192
    CrossFadeOwned = False
  EndIf
  CriticalUpdate = False ; #DEBUG_LINE_NO:194
  MustUpdatePlayerDeferredKillState = False ; #DEBUG_LINE_NO:195
  MustUpdateMonitoringSpells = False ; #DEBUG_LINE_NO:196
  Self.GotoState("") ; #DEBUG_LINE_NO:197
  RefreshCleanupRunning = False
EndFunction

Bool Function CanKnockOut(Actor akActor)
  If akActor.HasKeyword(KFActorCantKnockoutKeyword) ; #DEBUG_LINE_NO:201
    Return False ; #DEBUG_LINE_NO:202
  ElseIf akActor == Player ; #DEBUG_LINE_NO:203
    If KFCanKoPlayer.GetValue() == 0.0 ; #DEBUG_LINE_NO:204
      Return False ; #DEBUG_LINE_NO:205
    EndIf
  ElseIf akActor.HasKeyword(ActorTypeNPC) ; #DEBUG_LINE_NO:207
    If KFCanKoHumans.GetValue() == 0.0 ; #DEBUG_LINE_NO:208
      Return False ; #DEBUG_LINE_NO:209
    EndIf
  ElseIf akActor.HasKeyword(ActorTypeSuperMutant) ; #DEBUG_LINE_NO:211
    If KFCanKoSuperMutants.GetValue() == 0.0 ; #DEBUG_LINE_NO:212
      Return False ; #DEBUG_LINE_NO:213
    EndIf
  ElseIf akActor.HasKeyword(ActorTypeFeralGhoul) ; #DEBUG_LINE_NO:215
    If KFCanKoFeralGhoul.GetValue() == 0.0 ; #DEBUG_LINE_NO:216
      Return False ; #DEBUG_LINE_NO:217
    EndIf
  ElseIf KFCanKoOthers.GetValue() == 0.0 ; #DEBUG_LINE_NO:219
    Return False ; #DEBUG_LINE_NO:220
  EndIf
  Return True ; #DEBUG_LINE_NO:222
EndFunction

Bool Function CanBeKnockedOut(Actor akActor)
  If akActor.HasKeyword(KFActorCantBeKnockedOutKeyword) ; #DEBUG_LINE_NO:226
    Return False ; #DEBUG_LINE_NO:227
  ElseIf akActor == Player ; #DEBUG_LINE_NO:228
    If KFCanBeKoPlayer.GetValue() == 0.0 ; #DEBUG_LINE_NO:229
      Return False ; #DEBUG_LINE_NO:230
    EndIf
  ElseIf akActor.IsPlayerTeammate() ; #DEBUG_LINE_NO:232
    If KFCanBeKoFollowers.GetValue() == 0.0 ; #DEBUG_LINE_NO:233
      Return False ; #DEBUG_LINE_NO:234
    EndIf
  ElseIf akActor.HasKeyword(ActorTypeNPC) ; #DEBUG_LINE_NO:236
    If KFCanBeKoHumans.GetValue() == 0.0 ; #DEBUG_LINE_NO:237
      Return False ; #DEBUG_LINE_NO:238
    EndIf
  ElseIf akActor.HasKeyword(ActorTypeSuperMutant) ; #DEBUG_LINE_NO:240
    If KFCanBeKoSuperMutants.GetValue() == 0.0 ; #DEBUG_LINE_NO:241
      Return False ; #DEBUG_LINE_NO:242
    EndIf
  ElseIf akActor.HasKeyword(ActorTypeFeralGhoul) ; #DEBUG_LINE_NO:244
    If KFCanBeKoFeralGhoul.GetValue() == 0.0 ; #DEBUG_LINE_NO:245
      Return False ; #DEBUG_LINE_NO:246
    EndIf
  ElseIf KFCanBeKoOthers.GetValue() == 0.0 ; #DEBUG_LINE_NO:248
    Return False ; #DEBUG_LINE_NO:249
  EndIf
  Return True ; #DEBUG_LINE_NO:251
EndFunction

;-- State -------------------------------------------
State RefreshState

  Event OnPlayerTeleport()
    Self.RefreshStateEnd()
  EndEvent

  Event OnTimer(Int aiTimerID)
    Self.RefreshStateEnd()
  EndEvent

  Function RefreshActorsSpell(Bool CriticalUpdateFunc)
    ; Empty function
  EndFunction

  Function RefreshPlayerDeferredKillState(Bool CriticalUpdateFunc)
    ; Empty function
  EndFunction

  Event OnBeginState(String asOldState)
    If CriticalUpdate ; #DEBUG_LINE_NO:116
      KFConfigRefreshMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:117
      HoldAtBlackImod.ApplyCrossFade(0.300000012) ; #DEBUG_LINE_NO:118
      CrossFadeOwned = True
      Utility.Wait(0.300000012) ; #DEBUG_LINE_NO:119
      CallBack = Player.PlaceAtMe(XMarkerHeading as Form, 1, False, False, True) ; #DEBUG_LINE_NO:120
      CallbackOwned = CallBack as Bool
      If !CallBack
        Self.RefreshStateEnd()
        Return
      EndIf
    EndIf
    Utility.Wait(0.100000001) ; #DEBUG_LINE_NO:122
    If MustUpdatePlayerDeferredKillState ; #DEBUG_LINE_NO:124
      ActorValue PerceptionCondition = Game.GetCommonProperties().PerceptionCondition ; #DEBUG_LINE_NO:126
      ActorValue LeftAttackCondition = Game.GetCommonProperties().LeftAttackCondition ; #DEBUG_LINE_NO:127
      ActorValue RightAttackCondition = Game.GetCommonProperties().RightAttackCondition ; #DEBUG_LINE_NO:128
      ActorValue LeftMobilityCondition = Game.GetCommonProperties().LeftMobilityCondition ; #DEBUG_LINE_NO:129
      ActorValue RightMobilityCondition = Game.GetCommonProperties().RightMobilityCondition ; #DEBUG_LINE_NO:130
      ActorValue HealthCondition = Game.GetHealthAV() ; #DEBUG_LINE_NO:131
      Float SavedPerceptionCondition = Player.GetValue(PerceptionCondition) ; #DEBUG_LINE_NO:132
      Float SavedLeftAttackCondition = Player.GetValue(LeftAttackCondition) ; #DEBUG_LINE_NO:133
      Float SavedRightAttackCondition = Player.GetValue(RightAttackCondition) ; #DEBUG_LINE_NO:134
      Float SavedLeftMobilityCondition = Player.GetValue(LeftMobilityCondition) ; #DEBUG_LINE_NO:135
      Float SavedRightMobilityCondition = Player.GetValue(RightMobilityCondition) ; #DEBUG_LINE_NO:136
      Float SavedHealthCondition = Player.GetValue(HealthCondition) ; #DEBUG_LINE_NO:137
      Self.UpdatePlayerDeferredKillState() ; #DEBUG_LINE_NO:140
      Self.SetPlayerValue(PerceptionCondition, SavedPerceptionCondition) ; #DEBUG_LINE_NO:143
      Self.SetPlayerValue(LeftAttackCondition, SavedLeftAttackCondition) ; #DEBUG_LINE_NO:144
      Self.SetPlayerValue(RightAttackCondition, SavedRightAttackCondition) ; #DEBUG_LINE_NO:145
      Self.SetPlayerValue(LeftMobilityCondition, SavedLeftMobilityCondition) ; #DEBUG_LINE_NO:146
      Self.SetPlayerValue(RightMobilityCondition, SavedRightMobilityCondition) ; #DEBUG_LINE_NO:147
      Self.SetPlayerValue(HealthCondition, SavedHealthCondition) ; #DEBUG_LINE_NO:148
    EndIf
    If MustUpdateMonitoringSpells ; #DEBUG_LINE_NO:150
      Self.UpdateMonitoringCloakSpell() ; #DEBUG_LINE_NO:152
      Self.UpdatePlayerMonitoringSpell() ; #DEBUG_LINE_NO:155
      Self.UpdateNPCsMonitoringSpells() ; #DEBUG_LINE_NO:158
    EndIf
    If CriticalUpdate ; #DEBUG_LINE_NO:161
      Self.RegisterForPlayerTeleport() ; #DEBUG_LINE_NO:162
      Self.StartTimer(3.0, 0) ; #DEBUG_LINE_NO:163
      Player.MoveTo(KFConfigurationMarker, 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:164
    Else
      Self.RefreshStateEnd()
    EndIf
  EndEvent
EndState
