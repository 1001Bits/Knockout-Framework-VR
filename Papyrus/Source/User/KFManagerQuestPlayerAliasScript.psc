ScriptName KFManagerQuestPlayerAliasScript Extends ReferenceAlias

;-- Variables ---------------------------------------
Actor Killer

;-- Properties --------------------------------------
kfmanagerquestmaintenancescript Property MaintenanceScript Auto Const
kfmanagerquestmainscript Property MainScript Auto Const
Potion Property KFConvalescenceDispel1Potion Auto Const
Potion Property KFConvalescenceDispel2Potion Auto Const
Potion Property KFConvalescenceDispel3Potion Auto Const
Keyword Property KFConvalescenceDispel1Keyword Auto Const
Keyword Property KFConvalescenceDispel2Keyword Auto Const
Keyword Property KFConvalescenceDispel3Keyword Auto Const
GlobalVariable Property KFConvalescenceEffectDuration Auto Const
GlobalVariable Property KFLethalConvalescenceChances Auto Const
GlobalVariable Property KFLethalNoConvalescenceChances Auto Const
GlobalVariable Property KFIgnorePlayerDeathEvent Auto Const
ActorValue Property Rads Auto Const
Actor Property Player Auto Const

;-- Functions ---------------------------------------

Event OnDeferredKill(Actor akKiller)
  If KFIgnorePlayerDeathEvent.GetValue() == 1.0
    Return
  EndIf
  If !MainScript.IsPlayerDeferredDeathEnabled()
    ; Resolve a stale deferred-kill registration as an ordinary death after
    ; player KO or Death Alternative has been disabled.
    Player.EndDeferredKill()
    Player.Kill(akKiller)
    Return
  EndIf
  Killer = akKiller
  Self.GotoState("DeferredKillState")
EndEvent

Event OnPlayerLoadGame()
  MaintenanceScript.Verification() ; #DEBUG_LINE_NO:34
  Self.RecoverDefaultKnockoutScenario()
  Self.RecoverInteractionScene()
  ; Ownership-aware cleanup is a no-op for vanilla and foreign states. Always run
  ; it to repair a serialized legacy KF player stack.
  MainScript.RestorePlayerVRState(Player)
EndEvent

Function RecoverDefaultKnockoutScenario()
  ; Resolve dynamically so this recovery path does not add a VMAD property to
  ; existing saves. 0x897D is KFPlayerDefaultKnockoutQuest in the framework ESM.
  KFPlayerDefaultKnockoutQuestScript DefaultScenario = Game.GetFormFromFile(0x0000897D, "Knockout Framework.esm") as KFPlayerDefaultKnockoutQuestScript
  If DefaultScenario
    DefaultScenario.RecoverInterruptedScenario(True)
  EndIf
EndFunction

Function RecoverInteractionScene()
  ; The trigger/interact script shares the manager quest (0xF99). A dynamic cast
  ; avoids adding a property while preserving access to its serialized layer.
  KFManagerQuestTriggerVictimScript InteractionScript = Game.GetFormFromFile(0x00000F99, "Knockout Framework.esm") as KFManagerQuestTriggerVictimScript
  If InteractionScript
    InteractionScript.RecoverVRInteractionState()
  EndIf
EndFunction

Event OnPlayerFallLongDistance(Float afDamage)
  MainScript.FallDamages(Player, afDamage) ; #DEBUG_LINE_NO:38
EndEvent

Event OnTimerGameTime(Int aiTimerID)
  If aiTimerID == 1 ; #DEBUG_LINE_NO:42
    Bool UpdateTimer = False ; #DEBUG_LINE_NO:43
    If Player.HasMagicEffectWithKeyword(KFConvalescenceDispel1Keyword) ; #DEBUG_LINE_NO:44
      Player.EquipItem(KFConvalescenceDispel1Potion as Form, False, True) ; #DEBUG_LINE_NO:45
      UpdateTimer = True ; #DEBUG_LINE_NO:46
    ElseIf Player.HasMagicEffectWithKeyword(KFConvalescenceDispel2Keyword) ; #DEBUG_LINE_NO:47
      Player.EquipItem(KFConvalescenceDispel2Potion as Form, False, True) ; #DEBUG_LINE_NO:48
      UpdateTimer = True ; #DEBUG_LINE_NO:49
    ElseIf Player.HasMagicEffectWithKeyword(KFConvalescenceDispel3Keyword) ; #DEBUG_LINE_NO:50
      Player.EquipItem(KFConvalescenceDispel3Potion as Form, False, True) ; #DEBUG_LINE_NO:51
    EndIf
    If UpdateTimer ; #DEBUG_LINE_NO:53
      Self.UpdateConvalescenceTimer() ; #DEBUG_LINE_NO:54
    EndIf
  EndIf
EndEvent

Function UpdateConvalescenceTimer()
  Self.StartTimerGameTime(KFConvalescenceEffectDuration.GetValue() / 3.0, 1) ; #DEBUG_LINE_NO:60
EndFunction

;-- State -------------------------------------------
State DeferredKillState

  Event OnDeferredKill(Actor akKiller)
    ; Empty function
  EndEvent

  Event OnBeginState(String asOldState)
    Utility.Wait(0.01) ; #DEBUG_LINE_NO:73
    If !MainScript.IsPlayerDeferredDeathEnabled()
      Player.EndDeferredKill()
      Player.Kill(Killer)
      Utility.Wait(1.0)
      Self.GotoState("")
      Return
    EndIf
    Bool PlayerIsConvalescent = Player.HasMagicEffectWithKeyword(KFConvalescenceDispel3Keyword) ; #DEBUG_LINE_NO:74
    If Player.GetValue(Rads) >= 1000.0 || PlayerIsConvalescent && Utility.RandomFloat(0.100000001, 100.0) <= KFLethalConvalescenceChances.GetValue() || !PlayerIsConvalescent && Utility.RandomFloat(0.100000001, 100.0) <= KFLethalNoConvalescenceChances.GetValue() ; #DEBUG_LINE_NO:75
      Player.EndDeferredKill() ; #DEBUG_LINE_NO:76
      Player.Kill(Killer) ; #DEBUG_LINE_NO:77
    Else
      Bool Started = MainScript.KnockOutActor(Player, Killer, 0, False) ; #DEBUG_LINE_NO:79
      If !Started && !MainScript.IsPlayerInFrameworkKO()
        ; Never leave a rejected KO with its deferred death unresolved.
        Player.EndDeferredKill()
        Player.Kill(Killer)
      EndIf
    EndIf
    Utility.Wait(1.0) ; #DEBUG_LINE_NO:81
    Self.GotoState("") ; #DEBUG_LINE_NO:82
  EndEvent
EndState

;-- State -------------------------------------------
Auto State Uninitialized

  Event OnDeferredKill(Actor akKiller)
    ; Empty function
  EndEvent

  Event OnPlayerLoadGame()
    Self.RecoverDefaultKnockoutScenario()
    Self.RecoverInteractionScene()
  EndEvent
EndState
