ScriptName KFManagerQuestKOCollectionScript Extends RefCollectionAlias

;-- Variables ---------------------------------------
Int[] KOTimerGenerations
Int TimerSlotSpan = 100000

;-- Properties --------------------------------------
kfmanagerquestmainscript Property MainScript Auto Const
kfmanagerquesttriggervictimscript Property TriggerVictimScript Auto Const
Actor[] Property KOActors Auto hidden

;-- Functions ---------------------------------------

Event OnItemRemoved(ObjectReference akSenderRef, Form akBaseItem, Int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
  Self.GotoState("ItemStolen")
  TriggerVictimScript.ItemStolen(akSenderRef as Actor, akDestContainer as Actor)
EndEvent

Event OnAliasInit()
  KOActors = new Actor[0] ; #DEBUG_LINE_NO:11
  KOTimerGenerations = new Int[0]
  Self.AddInventoryEventFilter(None) ; #DEBUG_LINE_NO:12
EndEvent

Function EnsureTimerGenerationArray()
  If KOActors == None
    KOActors = new Actor[0]
  EndIf
  If TimerSlotSpan < 1
    TimerSlotSpan = 100000
  EndIf
  If KOTimerGenerations == None
    KOTimerGenerations = new Int[0]
  EndIf
  While KOTimerGenerations.Length < KOActors.Length
    KOTimerGenerations.add(0, 1)
  EndWhile
EndFunction

Int Function GetKOActorTimerID(Int Index)
  Self.EnsureTimerGenerationArray()
  If Index < 0 || Index >= KOActors.Length
    Return -1
  EndIf
  Return KOTimerGenerations[Index] * TimerSlotSpan + Index
EndFunction

Function CancelKOActorTimer(Int Index)
  Self.EnsureTimerGenerationArray()
  If Index < 0 || Index >= KOActors.Length
    Return
  EndIf
  Int CurrentTimerID = Self.GetKOActorTimerID(Index)
  If CurrentTimerID >= 0
    Self.CancelTimerGameTime(CurrentTimerID)
  EndIf
  ; Cancel a pre-port timer whose ID was the raw array index.
  Self.CancelTimerGameTime(Index)
  KOTimerGenerations[Index] += 1
  If KOTimerGenerations[Index] > 20000
    KOTimerGenerations[Index] = 1
  EndIf
EndFunction

Function StartKOActorTimer(Int Index, Float Duration)
  Self.EnsureTimerGenerationArray()
  If Index < 0 || Index >= KOActors.Length || !KOActors[Index]
    Return
  EndIf
  Self.CancelKOActorTimer(Index)
  Self.StartTimerGameTime(Duration, Self.GetKOActorTimerID(Index))
EndFunction

Bool Function AddKOActor(Actor Victim)
  If !Victim
    Return False
  EndIf
  Self.EnsureTimerGenerationArray()
  If Self.Find(Victim as ObjectReference) >= 0 || KOActors.find(Victim, 0) >= 0 ; #DEBUG_LINE_NO:16
    Return False ; #DEBUG_LINE_NO:17
  ElseIf Victim.IsDead() ; #DEBUG_LINE_NO:18
    MainScript.SetKOStatusOff(Victim) ; #DEBUG_LINE_NO:19
    Return False ; #DEBUG_LINE_NO:20
  EndIf
  Self.AddRef(Victim as ObjectReference) ; #DEBUG_LINE_NO:23
  Int FreeArrayIndex = KOActors.find(None, 0) ; #DEBUG_LINE_NO:24
  If FreeArrayIndex < 0 ; #DEBUG_LINE_NO:25
    KOActors.add(Victim, 1) ; #DEBUG_LINE_NO:26
    FreeArrayIndex = KOActors.Length - 1 ; #DEBUG_LINE_NO:27
  Else
    KOActors[FreeArrayIndex] = Victim ; #DEBUG_LINE_NO:29
  EndIf
  Self.RegisterForHitEvent(Victim as ScriptObject, None, None, None, 1, -1, -1, -1, True) ; #DEBUG_LINE_NO:32
  Self.RegisterForHitEvent(Victim as ScriptObject, None, None, None, -1, -1, 1, -1, True) ; #DEBUG_LINE_NO:33
  MainScript.StartKoCountdown(FreeArrayIndex) ; #DEBUG_LINE_NO:34
  Return True ; #DEBUG_LINE_NO:35
EndFunction

Bool Function IsKOActor(Actor Victim)
  If !Victim
    Return False
  EndIf
  Self.EnsureTimerGenerationArray()
  Return Self.Find(Victim as ObjectReference) >= 0 || KOActors.find(Victim, 0) >= 0
EndFunction

Bool Function IsKOActorAtIndex(Actor Victim, Int Index)
  If !Victim
    Return False
  EndIf
  Self.EnsureTimerGenerationArray()
  Return Index >= 0 && Index < KOActors.Length && KOActors[Index] == Victim
EndFunction

Bool Function RemoveKOActor(Actor Victim, Int Index)
  If !Victim
    Return False
  EndIf
  Self.EnsureTimerGenerationArray()
  If Index >= 0 && !Self.IsKOActorAtIndex(Victim, Index)
    ; A nonnegative index identifies one exact slot. Never fall back to another
    ; slot after a stale timer or reset stack has supplied the wrong identity.
    Return False
  EndIf
  Bool WasTracked = Self.IsKOActor(Victim)
  Int ActualIndex = -1
  If Index >= 0
    ActualIndex = Index
  Else
    ActualIndex = KOActors.find(Victim, 0) ; #DEBUG_LINE_NO:40
  EndIf
  If ActualIndex > -1 ; #DEBUG_LINE_NO:43
    WasTracked = True
    Self.CancelKOActorTimer(ActualIndex) ; #DEBUG_LINE_NO:44
    KOActors[ActualIndex] = None ; #DEBUG_LINE_NO:45
  EndIf
  If Self.Find(Victim as ObjectReference) >= 0
    Self.RemoveRef(Victim as ObjectReference) ; #DEBUG_LINE_NO:51
  EndIf
  If WasTracked
    Self.UnregisterForAllHitEvents(Victim as ScriptObject) ; #DEBUG_LINE_NO:52
  EndIf
  Return WasTracked ; #DEBUG_LINE_NO:53
EndFunction

Function CleanUpKOActors()
  Self.EnsureTimerGenerationArray()
  Int CurrentArrayIndex = KOActors.Length - 1 ; #DEBUG_LINE_NO:57
  While CurrentArrayIndex > -1 ; #DEBUG_LINE_NO:58
    If KOActors[CurrentArrayIndex] == None ; #DEBUG_LINE_NO:60
      KOActors.removelast() ; #DEBUG_LINE_NO:61
      If KOTimerGenerations.Length > CurrentArrayIndex
        KOTimerGenerations.removelast()
      EndIf
      CurrentArrayIndex -= 1 ; #DEBUG_LINE_NO:62
    Else
      CurrentArrayIndex = -1 ; #DEBUG_LINE_NO:64
    EndIf
  EndWhile
EndFunction

Event OnTimerGameTime(Int aiTimerID)
  If aiTimerID < 0
    Return
  EndIf
  Self.EnsureTimerGenerationArray()
  Int TimerGeneration = aiTimerID / TimerSlotSpan
  Int ActorIndex = aiTimerID - TimerGeneration * TimerSlotSpan
  If ActorIndex < 0 || ActorIndex >= KOActors.Length || !KOActors[ActorIndex]
    Return
  EndIf
  If TimerGeneration != KOTimerGenerations[ActorIndex]
    Return
  EndIf
  Actor Victim = KOActors[ActorIndex]
  Bool Result = MainScript.WakeKnockedOutActor(Victim, ActorIndex, None, False) ; #DEBUG_LINE_NO:70
EndEvent

Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked, String apMaterial)
  (akTarget as Actor).Kill(akAggressor as Actor) ; #DEBUG_LINE_NO:79
EndEvent

Event OnActivate(ObjectReference akSenderRef, ObjectReference akActionRef)
  If akActionRef as Actor ; #DEBUG_LINE_NO:83
    TriggerVictimScript.TriggerVictim(akSenderRef as Actor, False) ; #DEBUG_LINE_NO:84
  EndIf
EndEvent

Event OnDying(ObjectReference akSenderRef, Actor akKiller)
  Bool Result = MainScript.WakeKnockedOutActor(akSenderRef as Actor, -1, None, True) ; #DEBUG_LINE_NO:89
EndEvent

Event OnUnload(ObjectReference akSenderRef)
  If akSenderRef.IsDisabled() || akSenderRef.IsDeleted() ; #DEBUG_LINE_NO:93
    Bool Result = MainScript.WakeKnockedOutActor(akSenderRef as Actor, -1, None, True) ; #DEBUG_LINE_NO:94
  EndIf
EndEvent

;-- State -------------------------------------------
State ItemStolen

  Event OnItemRemoved(ObjectReference akSenderRef, Form akBaseItem, Int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)
    ; Empty function
  EndEvent

  Event OnBeginState(String asOldState)
    Utility.Wait(0.100000001) ; #DEBUG_LINE_NO:100
    Self.GotoState("") ; #DEBUG_LINE_NO:101
  EndEvent
EndState
