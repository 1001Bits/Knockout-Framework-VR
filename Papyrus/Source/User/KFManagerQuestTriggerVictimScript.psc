ScriptName KFManagerQuestTriggerVictimScript Extends Quest conditional

;-- Variables ---------------------------------------
Actor CurrentVictim
Int KillVictimAnimType
inputenablelayer ScriptLayer
Bool WasFirstPerson
Bool WasWeaponDrawn
Bool ExecutionFadeOwned

;-- Properties --------------------------------------
kfmanagerquestmainscript Property MainScript Auto Const
koframeworkevents Property EventsScript Auto Const
kfmanagerquestkocollectionscript Property KOCollectionScript Auto Const
kfmanagerquestf4sescript Property F4SEScript Auto Const
ReferenceAlias Property VictimBodyAlias Auto Const
ReferenceAlias Property BodyMarkerAlias Auto Const
ReferenceAlias Property BodyBagAlias Auto Const
GlobalVariable Property KFF4SEReady Auto Const
GlobalVariable Property KFStimpakRequired Auto Const
GlobalVariable Property KFKillMoveCutThroat Auto Const
GlobalVariable Property KFKillMoveChop Auto Const
GlobalVariable Property KFKillMoveStomp Auto Const
GlobalVariable Property KFUnequipAllItemsEnabled Auto Const
GlobalVariable Property KFInteractMenuEnabled Auto Const
Keyword Property KFKillMarkerKeyword Auto Const
Keyword Property ActorTypeHuman Auto Const
Keyword Property ActorTypeGhoul Auto Const
Keyword Property ActorTypeChild Auto Const
Message Property KFInteractBodyMessage Auto Const
Message Property KFKidnapFullMessage Auto Const
Message Property KFStimpakNeeded Auto Const
idlemarker Property KFKillMoveCutThroatIdle Auto Const
idlemarker Property KFKillMoveChopIdle Auto Const
idlemarker Property KFKillMoveStompIdle Auto Const
Race Property HumanRace Auto Const
Race Property GhoulRace Auto Const
Scene Property KFFinishKOActorScene Auto Const
Spell Property KFTriggerAggressionSpell Auto Const
Sound Property NPCHumanPowerArmorExitCombat Auto Const
Furniture Property PowerArmorFrameFurnitureNoCore Auto Const
FormList Property PowerArmorFramesList Auto Const
ActorValue Property Paralysis Auto Const
Potion Property Stimpak Auto Const
Actor Property Player Auto Const
Bool Property VictimIsEssential Auto conditional hidden
Bool Property VictimIsInPowerArmor Auto conditional hidden

;-- Functions ---------------------------------------

Function WaitFor3DLoadBounded(ObjectReference Target, Int MaxChecks = 20)
  Int Check = 0
  While Target && !Target.Is3DLoaded() && Check < MaxChecks
    Utility.Wait(0.25)
    Check += 1
  EndWhile
EndFunction

Function FinishOwnedInteractionFade()
  Self.CancelTimer(93)
  If ExecutionFadeOwned
    Game.FadeOutGame(False, True, 0.0, 0.35, False)
    ExecutionFadeOwned = False
  EndIf
EndFunction

Function RecoverVRInteractionState()
  Bool OwnsInteraction = ScriptLayer != None || ExecutionFadeOwned || Self.GetState() == "FinishKOActor"
  If Player.GetLinkedRef(KFKillMarkerKeyword) != None || KFFinishKOActorScene.IsPlaying()
    OwnsInteraction = True
  EndIf
  If !OwnsInteraction
    Return
  EndIf
  ; ScriptLayer is a persistent variable in v1.4, so this also releases a layer
  ; serialized by the old flat-screen execution, kidnap, or power-armor stack.
  If ScriptLayer
    ScriptLayer.Reset()
    ScriptLayer.Delete()
    ScriptLayer = None
  EndIf
  If KFFinishKOActorScene.IsPlaying()
    KFFinishKOActorScene.Stop()
  EndIf
  Game.SetPlayerAIDriven(False)
  Player.SetLinkedRef(None, KFKillMarkerKeyword)
  Player.StopTranslation()
  Self.FinishOwnedInteractionFade()
  Self.GotoState("")
EndFunction

Event OnTimer(Int aiTimerID)
  If aiTimerID == 93
    Self.FinishOwnedInteractionFade()
  EndIf
EndEvent

Function TriggerVictim(Actor Victim, Bool ForceMenu)
  If !KFInteractMenuEnabled.GetValue() ; #DEBUG_LINE_NO:52
    Return  ; #DEBUG_LINE_NO:53
  EndIf
  CurrentVictim = Victim ; #DEBUG_LINE_NO:55
  If !Player.IsSneaking() || ForceMenu ; #DEBUG_LINE_NO:56
    VictimIsEssential = Victim.IsEssential() ; #DEBUG_LINE_NO:57
    VictimIsInPowerArmor = Victim.IsInPowerArmor() ; #DEBUG_LINE_NO:58
    Int Choix = KFInteractBodyMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:59
    If Choix == 0 ; #DEBUG_LINE_NO:60
      Bool NeedStimpak = KFStimpakRequired.GetValue() as Int == 1 ; #DEBUG_LINE_NO:61
      If !NeedStimpak || Player.GetItemCount(Stimpak as Form) > 0 ; #DEBUG_LINE_NO:62
        If NeedStimpak ; #DEBUG_LINE_NO:63
          Player.RemoveItem(Stimpak as Form, 1, False, None) ; #DEBUG_LINE_NO:64
        EndIf
        Bool Result = MainScript.WakeKnockedOutActor(Victim, -1, Player, False) ; #DEBUG_LINE_NO:66
      Else
        KFStimpakNeeded.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:68
      EndIf
    ElseIf Choix == 1 ; #DEBUG_LINE_NO:70
      Self.LootVictim(Victim) ; #DEBUG_LINE_NO:71
    ElseIf Choix == 2 ; #DEBUG_LINE_NO:72
      If VictimIsEssential || !VictimIsInPowerArmor ; #DEBUG_LINE_NO:73
        Return  ; #DEBUG_LINE_NO:74
      EndIf
      Self.UnequipPowerArmor(Victim) ; #DEBUG_LINE_NO:76
    ElseIf Choix == 3 ; #DEBUG_LINE_NO:77
      If !Self.KidnapVictim(Victim) ; #DEBUG_LINE_NO:78
        Self.TriggerVictim(Victim, True) ; #DEBUG_LINE_NO:79
      EndIf
    ElseIf Choix == 4 ; #DEBUG_LINE_NO:81
      If VictimIsEssential || VictimIsInPowerArmor ; #DEBUG_LINE_NO:82
        Return  ; #DEBUG_LINE_NO:83
      EndIf
      Self.GotoState("FinishKOActor") ; #DEBUG_LINE_NO:85
    EndIf
  Else
    Player.PushActorAway(Victim, 2.0) ; #DEBUG_LINE_NO:88
    EventsScript.OnKoPushedEvent(Victim) ; #DEBUG_LINE_NO:89
  EndIf
EndFunction

Function LootVictim(Actor Victim)
  If VictimIsInPowerArmor ; #DEBUG_LINE_NO:94
    Victim.OpenInventory(True) ; #DEBUG_LINE_NO:95
  ElseIf !KFUnequipAllItemsEnabled.GetValue() || !KFF4SEReady.GetValue() || !Victim.IsAIEnabled() || !F4SEScript.LootVictim(Victim) ; #DEBUG_LINE_NO:97
    Victim.OpenInventory(True) ; #DEBUG_LINE_NO:98
  EndIf
EndFunction

Bool Function KidnapVictim(Actor Victim)
  Int Index = Self.GetVictimIndex(Victim) ; #DEBUG_LINE_NO:104
  If Index < 0 ; #DEBUG_LINE_NO:105
    Return False ; #DEBUG_LINE_NO:106
  ElseIf VictimBodyAlias.GetReference() as Actor != None ; #DEBUG_LINE_NO:107
    KFKidnapFullMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:108
    Return False ; #DEBUG_LINE_NO:109
  EndIf
  Player.DoCombatSpellApply(KFTriggerAggressionSpell, Victim as ObjectReference) ; #DEBUG_LINE_NO:115
  KOCollectionScript.CancelKOActorTimer(Index) ; #DEBUG_LINE_NO:116
  VictimBodyAlias.ForceRefTo(Victim as ObjectReference) ; #DEBUG_LINE_NO:117
  Victim.SetAlpha(0.0, True) ; #DEBUG_LINE_NO:119
  MainScript.WaitForRagdollExit(Victim) ; #DEBUG_LINE_NO:120
  Player.AddItem(BodyBagAlias.GetReference() as Form, 1, False) ; #DEBUG_LINE_NO:122
  Player.EquipItem((BodyBagAlias.GetReference().GetBaseObject() as Armor) as Form, False, True) ; #DEBUG_LINE_NO:123
  Victim.MoveTo(BodyMarkerAlias.GetReference(), 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:124
  Victim.EvaluatePackage(False) ; #DEBUG_LINE_NO:125
  Victim.SetAlpha(1.0, False) ; #DEBUG_LINE_NO:126
  EventsScript.OnKoKidnappedEvent(Victim) ; #DEBUG_LINE_NO:129
  Return True ; #DEBUG_LINE_NO:130
EndFunction

Actor Function ReleaseVictim(ObjectReference Target)
  Actor Victim = VictimBodyAlias.GetReference() as Actor ; #DEBUG_LINE_NO:134
  If !Victim ; #DEBUG_LINE_NO:135
    Return None ; #DEBUG_LINE_NO:136
  EndIf
  Int Index = Self.GetVictimIndex(Victim) ; #DEBUG_LINE_NO:138
  If Index < 0 ; #DEBUG_LINE_NO:139
    Return None ; #DEBUG_LINE_NO:140
  EndIf
  MainScript.StartKoCountdown(Index) ; #DEBUG_LINE_NO:142
  If Target as Bool && (Target != Player as ObjectReference) ; #DEBUG_LINE_NO:143
    Victim.MoveTo(Target, 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:144
  Else
    Target = Player as ObjectReference ; #DEBUG_LINE_NO:146
    Victim.MoveTo(Player as ObjectReference, 100.0 * Math.Sin(Player.GetAngleZ()), 100.0 * Math.Cos(Player.GetAngleZ()), 5.0, True) ; #DEBUG_LINE_NO:147
  EndIf
  BodyBagAlias.GetReference().MoveTo(BodyMarkerAlias.GetReference(), 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:149
  If Player.GetParentCell() == Victim.GetParentCell() ; #DEBUG_LINE_NO:150
    Self.WaitFor3DLoadBounded(Victim, 20) ; #DEBUG_LINE_NO:151
    Player.PushActorAway(Victim, 3.0) ; #DEBUG_LINE_NO:152
  EndIf
  Victim.SetValue(Paralysis, 1.0) ; #DEBUG_LINE_NO:155
  VictimBodyAlias.Clear() ; #DEBUG_LINE_NO:156
  Victim.EvaluatePackage(False) ; #DEBUG_LINE_NO:157
  Weapon EquippedWeapon = Victim.GetEquippedWeapon(0) ; #DEBUG_LINE_NO:158
  If EquippedWeapon ; #DEBUG_LINE_NO:159
    Victim.UnequipItem(EquippedWeapon as Form, False, False) ; #DEBUG_LINE_NO:160
  EndIf
  EventsScript.OnKoReleasedEvent(Victim, Target) ; #DEBUG_LINE_NO:162
  Return Victim ; #DEBUG_LINE_NO:163
EndFunction

Function UnequipPowerArmor(Actor Victim)
  Bool NextStep = False ; #DEBUG_LINE_NO:167
  Form FrameArmorForm = None ; #DEBUG_LINE_NO:168
  Int Index = PowerArmorFramesList.GetSize() ; #DEBUG_LINE_NO:169
  While Index
    Index -= 1 ; #DEBUG_LINE_NO:171
    FrameArmorForm = PowerArmorFramesList.GetAt(Index) ; #DEBUG_LINE_NO:172
    If Victim.IsEquipped(FrameArmorForm) ; #DEBUG_LINE_NO:173
      NextStep = True ; #DEBUG_LINE_NO:174
      Index = 0 ; #DEBUG_LINE_NO:175
    EndIf
  EndWhile
  Race BaseVictimRace = None ; #DEBUG_LINE_NO:179
  If Victim.HasKeyword(ActorTypeHuman) && !Victim.HasKeyword(ActorTypeChild) ; #DEBUG_LINE_NO:180
    BaseVictimRace = HumanRace ; #DEBUG_LINE_NO:181
  ElseIf Victim.HasKeyword(ActorTypeGhoul) && !Victim.HasKeyword(ActorTypeChild) ; #DEBUG_LINE_NO:182
    BaseVictimRace = GhoulRace ; #DEBUG_LINE_NO:183
  Else
    BaseVictimRace = (Victim.GetBaseObject() as ActorBase).GetRace() ; #DEBUG_LINE_NO:185
  EndIf
  If !NextStep || !BaseVictimRace ; #DEBUG_LINE_NO:188
    Return  ; #DEBUG_LINE_NO:189
  EndIf
  WasWeaponDrawn = Player.IsWeaponDrawn() ; #DEBUG_LINE_NO:192
  ExecutionFadeOwned = True
  Game.FadeOutGame(True, True, 0.0, 0.5, True) ; #DEBUG_LINE_NO:196
  Self.StartTimer(20.0, 93)
  Utility.Wait(0.5) ; #DEBUG_LINE_NO:197
  NPCHumanPowerArmorExitCombat.Play(Player as ObjectReference) ; #DEBUG_LINE_NO:198
  Victim.SetAlpha(0.0, True) ; #DEBUG_LINE_NO:199
  ObjectReference PowerArmorFrame = Player.PlaceAtMe(PowerArmorFrameFurnitureNoCore as Form, 1, True, True, True) ; #DEBUG_LINE_NO:201
  PowerArmorFrame.MoveTo(Player as ObjectReference, 75.0 * Math.Sin(Player.GetAngleZ()), 75.0 * Math.Cos(Player.GetAngleZ()), 0.0, True) ; #DEBUG_LINE_NO:202
  PowerArmorFrame.MoveToNearestNavmeshLocation() ; #DEBUG_LINE_NO:203
  PowerArmorFrame.SetAngle(0.0, 0.0, Player.GetAngleZ()) ; #DEBUG_LINE_NO:204
  If KFF4SEReady.GetValue() ; #DEBUG_LINE_NO:206
    F4SEScript.UnequipPowerArmor(Victim, FrameArmorForm, PowerArmorFrame) ; #DEBUG_LINE_NO:207
  EndIf
  Victim.RemoveItem(FrameArmorForm, 1, True, None) ; #DEBUG_LINE_NO:210
  PowerArmorFrame.Enable(False) ; #DEBUG_LINE_NO:211
  MainScript.WaitForRagdollExit(Victim) ; #DEBUG_LINE_NO:212
  Victim.MoveTo(BodyMarkerAlias.GetReference(), 0.0, 0.0, 0.0, True) ; #DEBUG_LINE_NO:213
  Utility.Wait(0.300000012) ; #DEBUG_LINE_NO:214
  Victim.SetAlpha(1.0, False) ; #DEBUG_LINE_NO:215
  Victim.SetRace(BaseVictimRace) ; #DEBUG_LINE_NO:216
  Victim.AttemptAnimationSetSwitch() ; #DEBUG_LINE_NO:217
  Utility.Wait(0.300000012) ; #DEBUG_LINE_NO:218
  Victim.MoveTo(Player as ObjectReference, 100.0 * Math.Sin(Player.GetAngleZ()), 100.0 * Math.Cos(Player.GetAngleZ()), 5.0, True) ; #DEBUG_LINE_NO:219
  If Player.GetParentCell() == Victim.GetParentCell() ; #DEBUG_LINE_NO:220
    Self.WaitFor3DLoadBounded(Victim, 20) ; #DEBUG_LINE_NO:221
    Player.PushActorAway(Victim, 2.0) ; #DEBUG_LINE_NO:222
  EndIf
  Weapon EquippedWeapon = Victim.GetEquippedWeapon(0) ; #DEBUG_LINE_NO:224
  If EquippedWeapon ; #DEBUG_LINE_NO:225
    Victim.UnequipItem(EquippedWeapon as Form, False, False) ; #DEBUG_LINE_NO:226
  EndIf
  Victim.SetValue(Paralysis, 1.0) ; #DEBUG_LINE_NO:228
  If WasWeaponDrawn ; #DEBUG_LINE_NO:229
    Player.DrawWeapon() ; #DEBUG_LINE_NO:230
  EndIf
  Utility.Wait(1.0) ; #DEBUG_LINE_NO:233
  Self.FinishOwnedInteractionFade() ; #DEBUG_LINE_NO:234
EndFunction

Function SelectExecutionType()
  Bool PlayerIsInPowerArmor = Player.IsInPowerArmor() ; #DEBUG_LINE_NO:245
  Int[] KillMoveType = new Int[3] ; #DEBUG_LINE_NO:247
  KillMoveType[0] = KFKillMoveCutThroat.GetValue() as Int ; #DEBUG_LINE_NO:248
  KillMoveType[1] = KFKillMoveChop.GetValue() as Int ; #DEBUG_LINE_NO:249
  KillMoveType[2] = KFKillMoveStomp.GetValue() as Int ; #DEBUG_LINE_NO:250
  If PlayerIsInPowerArmor ; #DEBUG_LINE_NO:251
    KillMoveType[0] = 0 ; #DEBUG_LINE_NO:252
    KillMoveType[1] = 0 ; #DEBUG_LINE_NO:253
  EndIf
  Int TotalPriority = KillMoveType[0] + KillMoveType[1] + KillMoveType[2]
  If TotalPriority < 1
    TotalPriority = 1
  EndIf
  Int RandomPriority = Utility.RandomInt(1, TotalPriority) ; #DEBUG_LINE_NO:269
  Int Index = 0
  Int CurrentPriority = 0
  KillVictimAnimType = -1
  While Index < KillMoveType.Length
    CurrentPriority += KillMoveType[Index]
    If RandomPriority <= CurrentPriority
      KillVictimAnimType = Index
      Index = KillMoveType.Length
    Else
      Index += 1
    EndIf
  EndWhile
  If KillVictimAnimType < 0
    If PlayerIsInPowerArmor
      KillVictimAnimType = 2
    Else
      KillVictimAnimType = Utility.RandomInt(0, 2)
    EndIf
  EndIf
EndFunction

Function ItemStolen(Actor Victim, Actor Aggressor)
  If !Victim || !Aggressor ; #DEBUG_LINE_NO:403
    Return  ; #DEBUG_LINE_NO:404
  EndIf
  Aggressor.DoCombatSpellApply(KFTriggerAggressionSpell, Victim as ObjectReference) ; #DEBUG_LINE_NO:406
  EventsScript.OnKoRobbedEvent(Victim, Aggressor) ; #DEBUG_LINE_NO:407
EndFunction

Int Function GetVictimIndex(Actor Victim)
  Return KOCollectionScript.KOActors.find(Victim, 0) ; #DEBUG_LINE_NO:411
EndFunction

;-- State -------------------------------------------
State FinishKOActor

  Event OnAnimationEvent(ObjectReference akSource, String asEventName)
    Self.GotoState("")
  EndEvent

  Event OnEndState(String asNewState)
    Self.CancelTimer(0)
    Self.CancelTimer(1)
    If CurrentVictim && !CurrentVictim.IsDead()
      CurrentVictim.Kill(Player)
      If KillVictimAnimType == 1
        CurrentVictim.Dismember("Head1", False, True, False)
      ElseIf KillVictimAnimType == 2
        CurrentVictim.Dismember("Head1", True, False, False)
      EndIf
    EndIf
    Player.SetLinkedRef(None, KFKillMarkerKeyword)
    Player.StopTranslation()
    Self.FinishOwnedInteractionFade()
    If WasWeaponDrawn
      Player.DrawWeapon()
    EndIf
  EndEvent

  Event OnTimer(Int aiTimerID)
    If aiTimerID == 93
      Self.FinishOwnedInteractionFade()
    ElseIf aiTimerID == 1
      Self.GotoState("")
    EndIf
  EndEvent

  Event OnBeginState(String asOldState)
    WasWeaponDrawn = Player.IsWeaponDrawn() ; #DEBUG_LINE_NO:242
    Self.SelectExecutionType()
    ExecutionFadeOwned = True
    Game.FadeOutGame(True, True, 0.0, 0.25, True)
    Self.StartTimer(2.0, 1)
    Utility.Wait(0.25)
    Self.GotoState("")
  EndEvent
EndState
