ScriptName KFPlayerConvalescenceEffectScript Extends ActiveMagicEffect Const

;-- Properties --------------------------------------
kfmanagerquestplayeraliasscript Property PlayerAliasScript Auto Const

;-- Functions ---------------------------------------

Event OnEffectStart(Actor Victim, Actor Aggressor)
  ActorValue Health = Game.GetHealthAV() ; #DEBUG_LINE_NO:9
  Float RestoredHealth = Victim.GetBaseValue(Health) * 0.150000006 ; #DEBUG_LINE_NO:10
  Float CurrentHealth = Victim.GetValue(Health) ; #DEBUG_LINE_NO:11
  If RestoredHealth > CurrentHealth ; #DEBUG_LINE_NO:12
    Victim.RestoreValue(Health, RestoredHealth - CurrentHealth) ; #DEBUG_LINE_NO:13
  Else
    Victim.DamageValue(Health, CurrentHealth - RestoredHealth) ; #DEBUG_LINE_NO:15
  EndIf
  ActorValue PerceptionCondition = Game.GetCommonProperties().PerceptionCondition ; #DEBUG_LINE_NO:18
  Victim.DamageValue(PerceptionCondition, Victim.GetValue(PerceptionCondition)) ; #DEBUG_LINE_NO:19
  If Utility.RandomInt(0, 1) ; #DEBUG_LINE_NO:20
    ActorValue LeftAttackCondition = Game.GetCommonProperties().LeftAttackCondition ; #DEBUG_LINE_NO:21
    Victim.DamageValue(LeftAttackCondition, Victim.GetValue(LeftAttackCondition)) ; #DEBUG_LINE_NO:22
  Else
    ActorValue RightAttackCondition = Game.GetCommonProperties().RightAttackCondition ; #DEBUG_LINE_NO:24
    Victim.DamageValue(RightAttackCondition, Victim.GetValue(RightAttackCondition)) ; #DEBUG_LINE_NO:25
  EndIf
  ActorValue MobilityCondition = None
  If Utility.RandomInt(0, 1) ; #DEBUG_LINE_NO:27
    MobilityCondition = Game.GetCommonProperties().LeftMobilityCondition ; #DEBUG_LINE_NO:28
  Else
    MobilityCondition = Game.GetCommonProperties().RightMobilityCondition ; #DEBUG_LINE_NO:31
  EndIf
  ; Preserve the lasting one-limb convalescence injury, but keep the condition
  ; above zero because a zero mobility condition can lock VR locomotion.
  If MobilityCondition
    Float MobilityValue = Victim.GetValue(MobilityCondition)
    If MobilityValue > 15.0
      Victim.DamageValue(MobilityCondition, MobilityValue - 15.0) ; #DEBUG_LINE_NO:32
    EndIf
  EndIf
  PlayerAliasScript.UpdateConvalescenceTimer() ; #DEBUG_LINE_NO:35
EndEvent
