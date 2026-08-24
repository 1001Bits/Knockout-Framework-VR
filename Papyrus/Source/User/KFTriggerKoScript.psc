ScriptName KFTriggerKoScript Extends ActiveMagicEffect

;-- Variables ---------------------------------------

;-- Properties --------------------------------------
kfmanagerquestmainscript Property MainScript Auto Const
Keyword Property KFKnockoutTriggerKeyword Auto Const
GlobalVariable Property KFKoPushStrength Auto Const

;-- Functions ---------------------------------------

Event OnEffectStart(Actor Victim, Actor Aggressor)
  If !Victim
    Return
  EndIf
  Actor Player = Game.GetPlayer()
  If Victim == Player && !MainScript.IsPlayerKnockoutEnabled()
    ; A queued trigger can arrive after the MCM option is switched off. Reject it
    ; before adding KF's marker keyword or applying any physical impulse.
    Return
  EndIf
  Victim.AddKeyword(KFKnockoutTriggerKeyword) ; #DEBUG_LINE_NO:10
  If Aggressor ; #DEBUG_LINE_NO:11
    ; PushActorAway can strand the VR player in a locomotion-disabled state.
    ; NPC victims keep the original knockback presentation.
    If Victim != Player
      Aggressor.PushActorAway(Victim, KFKoPushStrength.GetValue()) ; #DEBUG_LINE_NO:12
    EndIf
    Bool Result = MainScript.KnockOutActor(Victim, Aggressor, 0, False) ; #DEBUG_LINE_NO:13
  EndIf
  Victim.RemoveKeyword(KFKnockoutTriggerKeyword) ; #DEBUG_LINE_NO:15
EndEvent
