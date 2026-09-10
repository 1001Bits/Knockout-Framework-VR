ScriptName KFKoExitRagdollScript Extends ActiveMagicEffect

;-- Variables ---------------------------------------
Actor EffectVictim
Bool GhostOwned
Bool CompletionSignaled
Bool EffectFinished

;-- Properties --------------------------------------
ActorValue Property Paralysis Auto Const
Keyword Property KFKoExitRagdollKeyword Auto Const

;-- Functions ---------------------------------------

Function CompleteRagdollExit()
  ; The effect can become unbound while a queued stack is still finishing. Keep
  ; actor-side cleanup available, but never call ActiveMagicEffect natives after
  ; the binding has gone away.
  Bool EffectIsBound = Self.IsBoundGameObjectAvailable()
  If EffectIsBound
    Self.CancelTimer(1)
  EndIf
  If CompletionSignaled || !EffectVictim
    Return
  EndIf
  CompletionSignaled = True
  If EffectIsBound
    Self.UnregisterForAnimationEvent(EffectVictim as ObjectReference, "GetUpStart")
  EndIf
  EffectVictim.SetLinkedRef(EffectVictim as ObjectReference, KFKoExitRagdollKeyword)
  If GhostOwned
    EffectVictim.SetGhost(False)
    GhostOwned = False
  EndIf
EndFunction

Function DispelOrRetry()
  If EffectFinished
    Return
  ElseIf Self.IsBoundGameObjectAvailable()
    Self.Dispel()
  EndIf
  ; No retry is scheduled when the effect is unbound: an unbound script cannot
  ; start a timer, so the attempt only logs an error and never fires. The effect
  ; still cannot become permanent, because KFManagerQuestMainScript dispels
  ; KFKoExitRagdollSpell directly and the effect's own duration ends it.
EndFunction

Event OnEffectStart(Actor Victim, Actor Aggressor)
  EffectVictim = Victim
  CompletionSignaled = False
  EffectFinished = False
  GhostOwned = False
  If !Victim
    If Self.IsBoundGameObjectAvailable()
      Self.StartTimer(0.1, 1)
    EndIf
    Return
  EndIf
  Victim.SetValue(Paralysis, 0.0) ; #DEBUG_LINE_NO:12
  If Victim == Game.GetPlayer()
    Victim.SetUnconscious(False)
    Self.CompleteRagdollExit()
    If Self.IsBoundGameObjectAvailable()
      Self.StartTimer(0.1, 1)
    EndIf
  ElseIf Self.IsBoundGameObjectAvailable() ; #DEBUG_LINE_NO:13
    Self.RegisterForAnimationEvent(Victim as ObjectReference, "GetUpStart") ; #DEBUG_LINE_NO:10
    Victim.PushActorAway(Victim, 0.100000001) ; #DEBUG_LINE_NO:14
    If !Victim.IsGhost()
      GhostOwned = True
      Victim.SetGhost(True) ; #DEBUG_LINE_NO:15
    EndIf
    Self.StartTimer(3.0, 1)
  Else
    ; CompleteRagdollExit deliberately limits this path to actor-side cleanup.
    ; An unbound ActiveMagicEffect cannot schedule a retry timer.
    Self.CompleteRagdollExit()
  EndIf
EndEvent

Event OnEffectFinish(Actor Victim, Actor Aggressor)
  EffectFinished = True
  If !EffectVictim
    EffectVictim = Victim
  EndIf
  Self.CompleteRagdollExit() ; #DEBUG_LINE_NO:20
EndEvent

Event OnTimer(Int aiTimerID)
  If aiTimerID == 1
    Self.CompleteRagdollExit()
    Self.DispelOrRetry()
  EndIf
EndEvent

Event OnAnimationEvent(ObjectReference akSource, String asEventName)
  Self.CompleteRagdollExit()
  Self.DispelOrRetry()
EndEvent
