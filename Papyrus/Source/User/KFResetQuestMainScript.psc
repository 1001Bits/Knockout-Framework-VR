ScriptName KFResetQuestMainScript Extends Quest Const

;-- Variables ---------------------------------------

;-- Properties --------------------------------------
kfmanagerquestmainscript Property MainScript Auto Const
kfmanagerquestmaintenancescript Property MaintenanceScript Auto Const
kfmanagerquestkocollectionscript Property KOCollectionScript Auto Const
kfmanagerquesttriggervictimscript Property TriggerVictimScript Auto Const
Quest Property KFManagerQuest Auto Const
Quest Property KFPlayerDefaultKnockoutQuest Auto Const
ReferenceAlias Property VictimBodyAlias Auto Const
GlobalVariable Property KFModResetStatus Auto Const
GlobalVariable Property KFModInstalled Auto Const
GlobalVariable Property KFInteractMenuEnabled Auto Const
GlobalVariable Property KFIgnorePlayerDeathEvent Auto Const
Potion Property KFConvalescenceDispel3Potion Auto Const
Message Property KFModRestartConfirmMessage Auto Const
Message Property KFModRestartingMessage Auto Const
Message Property KFModRestartedMessage Auto Const
Message Property KFModUninstallConfirmMessage Auto Const
Message Property KFModUninstalledMessage Auto Const

;-- Functions ---------------------------------------

Function Initialization()
  Utility.Wait(0.5) ; #DEBUG_LINE_NO:26
  Int ModResetStatus = KFModResetStatus.GetValue() as Int ; #DEBUG_LINE_NO:27
  If ModResetStatus == -1 || ModResetStatus == 1 || ModResetStatus == 3 ; #DEBUG_LINE_NO:28
    Self.RestartMod(ModResetStatus == 3) ; #DEBUG_LINE_NO:29
  ElseIf ModResetStatus == 2 ; #DEBUG_LINE_NO:30
    Self.UninstallMod() ; #DEBUG_LINE_NO:31
  EndIf
  KFModResetStatus.SetValue(-1.0) ; #DEBUG_LINE_NO:33
  Self.Reset() ; #DEBUG_LINE_NO:34
EndFunction

Function RestartMod(Bool Silent)
  If !Silent && !KFModRestartConfirmMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:38
    Return  ; #DEBUG_LINE_NO:39
  EndIf
  MainScript.GotoState("Uninitialized") ; #DEBUG_LINE_NO:45
  Utility.WaitMenuMode(0.300000012) ; #DEBUG_LINE_NO:46
  KFModRestartingMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:47
  Self.ResetKOActors() ; #DEBUG_LINE_NO:49
  KFManagerQuest.Reset() ; #DEBUG_LINE_NO:50
  KFPlayerDefaultKnockoutQuest.Reset() ; #DEBUG_LINE_NO:51
  Utility.WaitMenuMode(1.0) ; #DEBUG_LINE_NO:52
  KFManagerQuest.Stop() ; #DEBUG_LINE_NO:53
  KFPlayerDefaultKnockoutQuest.Stop() ; #DEBUG_LINE_NO:54
  Utility.WaitMenuMode(1.0) ; #DEBUG_LINE_NO:55
  KFManagerQuest.Start() ; #DEBUG_LINE_NO:56
  KFPlayerDefaultKnockoutQuest.Start() ; #DEBUG_LINE_NO:57
  Game.GetPlayer().EquipItem(KFConvalescenceDispel3Potion as Form, False, True) ; #DEBUG_LINE_NO:58
  KFInteractMenuEnabled.SetValue(1.0) ; #DEBUG_LINE_NO:59
  KFIgnorePlayerDeathEvent.SetValue(0.0) ; #DEBUG_LINE_NO:60
  Utility.Wait(0.01) ; #DEBUG_LINE_NO:62
  If !Silent ; #DEBUG_LINE_NO:66
    KFModRestartedMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:67
  EndIf
EndFunction

Function UninstallMod()
  If !KFModUninstallConfirmMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:72
    Return  ; #DEBUG_LINE_NO:73
  EndIf
  MainScript.GotoState("Uninitialized") ; #DEBUG_LINE_NO:79
  Utility.WaitMenuMode(0.300000012) ; #DEBUG_LINE_NO:80
  Self.ResetKOActors() ; #DEBUG_LINE_NO:82
  koframeworkfunctions.SetPlayerCanBeKnockedOut(0.0) ; #DEBUG_LINE_NO:83
  KFManagerQuest.Reset() ; #DEBUG_LINE_NO:84
  KFPlayerDefaultKnockoutQuest.Reset() ; #DEBUG_LINE_NO:85
  Utility.WaitMenuMode(1.0) ; #DEBUG_LINE_NO:86
  KFManagerQuest.Stop() ; #DEBUG_LINE_NO:87
  KFPlayerDefaultKnockoutQuest.Stop() ; #DEBUG_LINE_NO:88
  Game.GetPlayer().EquipItem(KFConvalescenceDispel3Potion as Form, False, True) ; #DEBUG_LINE_NO:89
  KFInteractMenuEnabled.SetValue(0.0) ; #DEBUG_LINE_NO:90
  KFIgnorePlayerDeathEvent.SetValue(0.0) ; #DEBUG_LINE_NO:91
  Utility.Wait(0.01) ; #DEBUG_LINE_NO:93
  KFModInstalled.SetValue(0.0) ; #DEBUG_LINE_NO:97
  KFModUninstalledMessage.Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:98
  Game.RequestSave() ; #DEBUG_LINE_NO:99
EndFunction

Function ResetKOActors()
  Actor[] KOActors = KOCollectionScript.KOActors ; #DEBUG_LINE_NO:103
  Int CurrentArrayIndex = KOActors.Length - 1 ; #DEBUG_LINE_NO:104
  While CurrentArrayIndex > -1 ; #DEBUG_LINE_NO:105
    If KOActors[CurrentArrayIndex] != None ; #DEBUG_LINE_NO:106
      If KOActors[CurrentArrayIndex] == VictimBodyAlias.GetReference() as Actor ; #DEBUG_LINE_NO:107
        Actor ReleasedActor = TriggerVictimScript.ReleaseVictim(None) ; #DEBUG_LINE_NO:108
      EndIf
      Bool Result = MainScript.WakeKnockedOutActor(KOActors[CurrentArrayIndex], CurrentArrayIndex, None, True) ; #DEBUG_LINE_NO:110
    EndIf
    CurrentArrayIndex -= 1 ; #DEBUG_LINE_NO:112
  EndWhile
EndFunction
