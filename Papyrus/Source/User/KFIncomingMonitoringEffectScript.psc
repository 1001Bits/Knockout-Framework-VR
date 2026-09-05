ScriptName KFIncomingMonitoringEffectScript Extends ActiveMagicEffect

;-- Variables ---------------------------------------
Bool CanRecover
Bool PairedEventPending
Bool BleedoutRecoveryOwned
Bool EarlyPairedEventHandled
Bool EventRegistrationClosing
Bool PairedDeathEventRegistered
Bool PairedKillStartEventRegistered
Bool PairedBashStartEventRegistered
Bool PairedVictimEventRegistered
Bool RegistrationRetryPending
Actor Victim

;-- Properties --------------------------------------
kfmanagerquestmainscript Property MainScript Auto Const
kfmanagerquestconfigscript Property ConfigScript Auto Const

;-- Functions ---------------------------------------

Function RegisterAnimationEvents()
  If EventRegistrationClosing || !Victim || Victim.IsDead()
    Return
  EndIf
  If !Self.IsBoundGameObjectAvailable()
    ; An unbound effect cannot start a timer, so a retry cannot be scheduled from
    ; here. Attempting one only logs "Unbound scripts cannot start timers". The
    ; remaining registration triggers re-run this once the effect is bound again.
    Return
  EndIf
  If !Victim.Is3DLoaded()
    Self.ScheduleAnimationRegistrationRetry()
    Return
  EndIf
  If !PairedVictimEventRegistered
    PairedVictimEventRegistered = Self.RegisterForAnimationEvent(Victim as ObjectReference, "pa_PairedKillMQ302DanseDeathVictim") ; #DEBUG_LINE_NO:12
  EndIf
  If !PairedDeathEventRegistered
    PairedDeathEventRegistered = Self.RegisterForAnimationEvent(Victim as ObjectReference, "pa_PairedKillMQ302DanseDeath") ; #DEBUG_LINE_NO:13
  EndIf
  If !PairedKillStartEventRegistered
    PairedKillStartEventRegistered = Self.RegisterForAnimationEvent(Victim as ObjectReference, "KFVR_PairedKillStart")
  EndIf
  If !PairedBashStartEventRegistered
    PairedBashStartEventRegistered = Self.RegisterForAnimationEvent(Victim as ObjectReference, "KFVR_PairedBashStart")
  EndIf
  If PairedVictimEventRegistered && PairedDeathEventRegistered && PairedKillStartEventRegistered && PairedBashStartEventRegistered
    Self.CancelTimer(97)
    RegistrationRetryPending = False
  Else
    Self.ScheduleAnimationRegistrationRetry()
  EndIf
EndFunction

Function ScheduleAnimationRegistrationRetry()
  If EventRegistrationClosing || !Victim || Victim.IsDead() || !Self.IsBoundGameObjectAvailable()
    Return
  EndIf
  Self.CancelTimer(97)
  RegistrationRetryPending = True
  Self.StartTimer(1.0, 97)
EndFunction

Function FinishAnimationRegistration()
  EventRegistrationClosing = True
  Self.CancelTimer(97)
  Self.CancelTimer(99)
  RegistrationRetryPending = False
  EarlyPairedEventHandled = False
  If Victim
    Self.UnregisterForAnimationEvent(Victim as ObjectReference, "pa_PairedKillMQ302DanseDeathVictim")
    Self.UnregisterForAnimationEvent(Victim as ObjectReference, "pa_PairedKillMQ302DanseDeath")
    Self.UnregisterForAnimationEvent(Victim as ObjectReference, "KFVR_PairedKillStart")
    Self.UnregisterForAnimationEvent(Victim as ObjectReference, "KFVR_PairedBashStart")
  EndIf
  PairedVictimEventRegistered = False
  PairedDeathEventRegistered = False
  PairedKillStartEventRegistered = False
  PairedBashStartEventRegistered = False
  If ConfigScript
    Self.UnregisterForCustomEvent(ConfigScript, "UpdateMonitoringSpellEv")
  EndIf
EndFunction

Bool Function IsPairedKillEvent(String EventName)
  Return EventName == "pa_PairedKillMQ302DanseDeathVictim" || EventName == "pa_PairedKillMQ302DanseDeath" || EventName == "KFVR_PairedKillStart" || EventName == "KFVR_PairedBashStart"
EndFunction

Bool Function IsEarlyPairedKillEvent(String EventName)
  Return EventName == "KFVR_PairedKillStart" || EventName == "KFVR_PairedBashStart"
EndFunction

Int Function GetPairedKillMoveType(String EventName)
  If EventName == "pa_PairedKillMQ302DanseDeathVictim" || EventName == "KFVR_PairedKillStart"
    Return 1
  ElseIf EventName == "pa_PairedKillMQ302DanseDeath" || EventName == "KFVR_PairedBashStart"
    Return 2
  EndIf
  Return 0
EndFunction

Function ReleaseOwnedBleedoutRecovery()
  If Victim && BleedoutRecoveryOwned
    Victim.SetNoBleedoutRecovery(False)
  EndIf
  BleedoutRecoveryOwned = False
EndFunction

Function FinishBleedoutRecovery()
  Self.CancelTimer(0)
  Self.CancelTimer(1)
  Self.ReleaseOwnedBleedoutRecovery()
  CanRecover = False
EndFunction

Actor Function ResolveResponsibleActor()
  If !Victim
    Return None
  EndIf
  Actor ResponsibleActor = Victim.GetCombatTarget()
  If ResponsibleActor == Victim
    ResponsibleActor = None
  EndIf
  Actor Player = Game.GetPlayer()
  If !ResponsibleActor && Victim != Player && Player && Player.GetDistance(Victim as ObjectReference) < 150.0
    ResponsibleActor = Player
  EndIf
  Return ResponsibleActor
EndFunction

Function ResolvePairedKillNormally(Actor ResponsibleActor)
  If !Victim || Victim.IsDead() || koframeworkfunctions.IsKnockedOut(Victim)
    Return
  EndIf
  Victim.Kill(ResponsibleActor)
EndFunction

Function ResolvePairedKnockout(Int KillMoveType, Actor ResponsibleActor)
  Bool Result = False
  If ConfigScript.CanBeKnockedOut(Victim) && ResponsibleActor
    Result = MainScript.KnockOutActor(Victim, ResponsibleActor, KillMoveType, False)
  EndIf
  If !Result && !Victim.IsDead() && !koframeworkfunctions.IsKnockedOut(Victim)
    Self.ResolvePairedKillNormally(ResponsibleActor)
  EndIf
EndFunction

Function FinishPairedEventWatchdog()
  If PairedEventPending && Victim && !Victim.IsDead() && !koframeworkfunctions.IsKnockedOut(Victim)
    Self.ReleaseOwnedBleedoutRecovery()
    Victim.SetUnconscious(False)
    Victim.SetRestrained(False)
    If Victim == Game.GetPlayer()
      Game.SetPlayerAIDriven(False)
    ElseIf Victim.Is3DLoaded()
      Victim.PushActorAway(Victim, 0.01)
    EndIf
  EndIf
  PairedEventPending = False
EndFunction

Function TriggerTimer(Int aiTimerID)
  If aiTimerID == 97
    RegistrationRetryPending = False
    Self.RegisterAnimationEvents()
  ElseIf aiTimerID == 98
    Self.FinishPairedEventWatchdog()
  ElseIf aiTimerID == 99
    EarlyPairedEventHandled = False
  ElseIf aiTimerID == 1 && Self.GetState() == "BleedingOut"
    Self.FinishBleedoutRecovery()
    Self.GotoState("")
  ElseIf aiTimerID == 0 && Self.GetState() == "BleedingOut" ; #DEBUG_LINE_NO:17
    If Victim.GetCombatState() != 1 ; #DEBUG_LINE_NO:18
      Self.FinishBleedoutRecovery() ; #DEBUG_LINE_NO:19
      Self.GotoState("") ; #DEBUG_LINE_NO:20
    Else
      CanRecover = True ; #DEBUG_LINE_NO:22
    EndIf
  EndIf
EndFunction

Event OnEffectStart(Actor Target, Actor Caster)
  Victim = Target ; #DEBUG_LINE_NO:28
  EventRegistrationClosing = False
  If ConfigScript
    Self.RegisterForCustomEvent(ConfigScript, "UpdateMonitoringSpellEv") ; #DEBUG_LINE_NO:31
  EndIf
  Self.RegisterAnimationEvents() ; #DEBUG_LINE_NO:30
EndEvent

Event KFManagerQuestConfigScript.UpdateMonitoringSpellEv(kfmanagerquestconfigscript akSender, Var[] akArgs)
  Spell MonitoringSpell = akArgs[0] as Spell ; #DEBUG_LINE_NO:36
  Victim.RemoveSpell(MonitoringSpell) ; #DEBUG_LINE_NO:37
  Utility.Wait(1.0) ; #DEBUG_LINE_NO:38
  Victim.AddSpell(MonitoringSpell, True) ; #DEBUG_LINE_NO:39
EndEvent

Event OnTimer(Int aiTimerID)
  Self.TriggerTimer(aiTimerID) ; #DEBUG_LINE_NO:43
EndEvent

Event OnAnimationEvent(ObjectReference akSource, String asEventName)
  If akSource != Victim || !Self.IsPairedKillEvent(asEventName) || !Victim || Victim.IsDead() || PairedEventPending || EarlyPairedEventHandled
    Return
  EndIf
  Bool EarlyPairedEvent = Self.IsEarlyPairedKillEvent(asEventName)
  PairedEventPending = True
  Actor ResponsibleActor = Self.ResolveResponsibleActor()
  If EarlyPairedEvent
    If !KFVRAnimationBridge.SkipPlayerPairedAnimation(Game.GetPlayer(), Victim)
      PairedEventPending = False
      Return
    EndIf
    If Victim != Game.GetPlayer()
      ResponsibleActor = Game.GetPlayer()
    EndIf
    EarlyPairedEventHandled = True
    Self.CancelTimer(99)
    Self.StartTimer(10.0, 99)
  EndIf
  Self.StartTimer(2.0, 98)
  Self.ResolvePairedKnockout(Self.GetPairedKillMoveType(asEventName), ResponsibleActor)
EndEvent

Event OnAnimationEventUnregistered(ObjectReference akSource, String asEventName)
  If akSource != Victim || !Self.IsPairedKillEvent(asEventName) || EventRegistrationClosing
    Return
  EndIf
  If asEventName == "pa_PairedKillMQ302DanseDeathVictim"
    PairedVictimEventRegistered = False
  ElseIf asEventName == "pa_PairedKillMQ302DanseDeath"
    PairedDeathEventRegistered = False
  ElseIf asEventName == "KFVR_PairedKillStart"
    PairedKillStartEventRegistered = False
  ElseIf asEventName == "KFVR_PairedBashStart"
    PairedBashStartEventRegistered = False
  EndIf
  Self.RegisterAnimationEvents() ; #DEBUG_LINE_NO:58
EndEvent

Function BeginBleedingOut()
  ; Empty function
EndFunction

Event OnEnterBleedout()
  If Victim == Game.GetPlayer() && !ConfigScript.CanBeKnockedOut(Victim)
    Self.FinishBleedoutRecovery()
    Return
  EndIf
  Actor Aggressor = Self.ResolveResponsibleActor()
  If !Aggressor || !MainScript.BleedingOut(Victim, Aggressor) ; #DEBUG_LINE_NO:91
    Self.GotoState("BleedingOut")
  EndIf
EndEvent

;-- State -------------------------------------------
State BleedingOut

  Function BeginBleedingOut()
    If Victim == Game.GetPlayer() && !ConfigScript.CanBeKnockedOut(Victim)
      Self.FinishBleedoutRecovery()
      Self.GotoState("")
      Return
    EndIf
    Float RecoveryTimer = 15.0
    If Victim.IsPlayerTeammate()
      RecoveryTimer = 180.0
    EndIf
    CanRecover = False
    If !Victim.GetNoBleedoutRecovery()
      Victim.SetNoBleedoutRecovery(True)
      BleedoutRecoveryOwned = True
    EndIf
    Self.StartTimer(RecoveryTimer, 0)
    Self.StartTimer(RecoveryTimer + 60.0, 1)
  EndFunction

  Event OnCombatStateChanged(Actor akTarget, Int aeCombatState)
    If CanRecover && aeCombatState != 1
      Self.FinishBleedoutRecovery()
      Self.GotoState("")
    EndIf
  EndEvent

  Event OnEffectFinish(Actor akTarget, Actor akCaster)
    Self.FinishBleedoutRecovery()
    Self.CancelTimer(98)
    PairedEventPending = False
    Self.FinishAnimationRegistration()
  EndEvent

  Event OnEnterBleedout()
    Self.BeginBleedingOut()
  EndEvent

  Event OnBeginState(String asOldState)
    Self.BeginBleedingOut() ; #DEBUG_LINE_NO:70
  EndEvent
EndState

Event OnEffectFinish(Actor akTarget, Actor akCaster)
  Self.FinishBleedoutRecovery()
  Self.CancelTimer(98)
  PairedEventPending = False
  Self.FinishAnimationRegistration()
EndEvent
