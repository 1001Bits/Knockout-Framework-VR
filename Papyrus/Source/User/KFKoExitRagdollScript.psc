ScriptName KFKoExitRagdollScript Extends ActiveMagicEffect

;-- Variables ---------------------------------------
Actor EffectVictim
Bool GhostOwned
Bool CompletionSignaled
Bool EffectFinished
Int DispelAttempts

;-- Properties --------------------------------------
ActorValue Property Paralysis Auto Const
Keyword Property KFKoExitRagdollKeyword Auto Const

;-- Functions ---------------------------------------

Function CompleteRagdollExit()
  Self.CancelTimer(1)
  If CompletionSignaled || !EffectVictim
    Return
  EndIf
  CompletionSignaled = True
  Self.UnregisterForAnimationEvent(EffectVictim as ObjectReference, "GetUpStart")
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
  ElseIf DispelAttempts < 20
    DispelAttempts += 1
    Self.StartTimer(0.5, 1)
  Else
    ; A temporarily missing bound actor must not make this effect permanent.
    ; Keep a low-frequency retry alive until the effect can dispel or finishes.
    Self.StartTimer(5.0, 1)
  EndIf
EndFunction

Event OnEffectStart(Actor Victim, Actor Aggressor)
  EffectVictim = Victim
  CompletionSignaled = False
  EffectFinished = False
  GhostOwned = False
  DispelAttempts = 0
  If !Victim
    Self.StartTimer(0.1, 1)
    Return
  EndIf
  Victim.SetValue(Paralysis, 0.0) ; #DEBUG_LINE_NO:12
  If Victim == Game.GetPlayer()
    Victim.SetUnconscious(False)
    Self.CompleteRagdollExit()
    Self.StartTimer(0.1, 1)
  ElseIf Self.IsBoundGameObjectAvailable() ; #DEBUG_LINE_NO:13
    Self.RegisterForAnimationEvent(Victim as ObjectReference, "GetUpStart") ; #DEBUG_LINE_NO:10
    Victim.PushActorAway(Victim, 0.100000001) ; #DEBUG_LINE_NO:14
    If !Victim.IsGhost()
      GhostOwned = True
      Victim.SetGhost(True) ; #DEBUG_LINE_NO:15
    EndIf
    Self.StartTimer(3.0, 1)
  Else
    Self.CompleteRagdollExit()
    Self.StartTimer(0.1, 1)
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
