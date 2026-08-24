ScriptName KFManagerQuestMaintenanceScript Extends Quest

;-- Variables ---------------------------------------

;-- Properties --------------------------------------
kfmanagerquestconfigscript Property ConfigScript Auto Const
kfmanagerquesteventsscript Property EventsScript Auto Const
kfmanagerquestmainscript Property MainScript Auto Const
kfmanagerquestplayeraliasscript Property PlayerAliasScript Auto Const
kfmanagerquestkocollectionscript Property KOCollectionScript Auto Const
koframeworkevents Property FrameworkEventsScript Auto Const
ReferenceAlias Property PlayerAlias Auto Const
ReferenceAlias Property BodyMarkerAlias Auto Const
ReferenceAlias Property BodyBagAlias Auto Const
ObjectReference Property BodyMarkerRef Auto Const
ObjectReference Property BodyBagRef Auto Const
GlobalVariable Property KFF4SEReady Auto Const
GlobalVariable Property KFModVersionMajor Auto Const
GlobalVariable Property KFModVersionMinor Auto Const
GlobalVariable Property KFModVersionBeta Auto Const
Quest Property KFResetQuest Auto Const
Message Property KFWelcomeMessage Auto Const
Message Property KFUpdateMessage Auto Const
Message Property KFReinstallRequiredMessage Auto Const
Message Property KFF4SERequiredMessage Auto Const
holotape Property KFConfigMenuHolotape Auto Const
Actor Property DogmeatRef Auto Const
Actor Property Player Auto Const

;-- Functions ---------------------------------------

Int Function GetVersionMajor()
  Return 1 ; #DEBUG_LINE_NO:32
EndFunction

Int Function GetVersionMinor()
  Return 4 ; #DEBUG_LINE_NO:35
EndFunction

Int Function GetVersionBeta()
  Return 0 ; #DEBUG_LINE_NO:38
EndFunction

Int Function GetRequiredF4SEVersionMajor()
  Return 0 ; #DEBUG_LINE_NO:42
EndFunction

Int Function GetRequiredF4SEVersionMinor()
  Return 6 ; #DEBUG_LINE_NO:45
EndFunction

Int Function GetRequiredF4SEVersionBeta()
  Return 21 ; #DEBUG_LINE_NO:48
EndFunction

Int[] Function GetVersion()
  Int[] Version = new Int[4] ; #DEBUG_LINE_NO:52
  Version[0] = Self.GetVersionInt() ; #DEBUG_LINE_NO:53
  Version[1] = Self.GetVersionMajor() ; #DEBUG_LINE_NO:54
  Version[2] = Self.GetVersionMinor() ; #DEBUG_LINE_NO:55
  Version[3] = Self.GetVersionBeta() ; #DEBUG_LINE_NO:56
  Return Version ; #DEBUG_LINE_NO:57
EndFunction

Int Function GetVersionInt()
  Return Self.GetVersionMajor() * 10000 + Self.GetVersionMinor() * 100 + Self.GetVersionBeta() ; #DEBUG_LINE_NO:60
EndFunction

Int Function GetOldVersionInt()
  Return (KFModVersionMajor.GetValue() as Int * 10000) + (KFModVersionMinor.GetValue() as Int * 100) + KFModVersionBeta.GetValue() as Int ; #DEBUG_LINE_NO:63
EndFunction

String Function Update()
  Int OldVersionInt = Self.GetOldVersionInt() ; #DEBUG_LINE_NO:67
  If OldVersionInt < 10300 ; #DEBUG_LINE_NO:68
    (Game.GetFormFromFile(27390, "Knockout Framework.esm") as GlobalVariable).SetValue(1.0) ; #DEBUG_LINE_NO:69
    Return "Reset" ; #DEBUG_LINE_NO:70
  Else
    Return "Update" ; #DEBUG_LINE_NO:72
  EndIf
EndFunction

Function Initialization()
  If KFResetQuest.IsStopped() ; #DEBUG_LINE_NO:79
    Utility.Wait(0.5) ; #DEBUG_LINE_NO:80
  EndIf
  If !Self.IsEligibleToSovngarde() ; #DEBUG_LINE_NO:82
    Game.QuitToMainMenu() ; #DEBUG_LINE_NO:83
    Return  ; #DEBUG_LINE_NO:84
  EndIf
  If Player.GetItemCount(KFConfigMenuHolotape as Form) < 1 ; #DEBUG_LINE_NO:86
    Player.AddItem(KFConfigMenuHolotape as Form, 1, False) ; #DEBUG_LINE_NO:87
  EndIf
  PlayerAlias.ForceRefTo(Player as ObjectReference) ; #DEBUG_LINE_NO:91
  BodyMarkerAlias.ForceRefTo(BodyMarkerRef) ; #DEBUG_LINE_NO:92
  BodyBagAlias.ForceRefTo(BodyBagRef) ; #DEBUG_LINE_NO:93
  ConfigScript.UpdateMonitoringCloakSpell() ; #DEBUG_LINE_NO:94
  ConfigScript.UpdatePlayerMonitoringSpell() ; #DEBUG_LINE_NO:95
  ConfigScript.UpdateNPCsMonitoringSpells() ; #DEBUG_LINE_NO:96
  Int VersionInt = Self.GetVersionInt() ; #DEBUG_LINE_NO:98
  Int OldVersionInt = Self.GetOldVersionInt() ; #DEBUG_LINE_NO:99
  If OldVersionInt > 0 && OldVersionInt != VersionInt ; #DEBUG_LINE_NO:100
    Self.StartTimer(0.100000001, 0) ; #DEBUG_LINE_NO:101
    Debug.Trace(((("Knockout Framework has been updated to version " + Self.GetVersionMajor() as String) + "." + Self.GetVersionMinor() as String) + "." + Self.GetVersionBeta() as String) + ".", 0) ; #DEBUG_LINE_NO:102
    KFUpdateMessage.Show(KFModVersionMajor.GetValue(), KFModVersionMinor.GetValue(), KFModVersionBeta.GetValue(), Self.GetVersionMajor() as Float, Self.GetVersionMinor() as Float, Self.GetVersionBeta() as Float, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:103
  ElseIf KFResetQuest.IsStopped() ; #DEBUG_LINE_NO:104
    Debug.Trace(((("\n\nKnockout Framework version " + Self.GetVersionMajor() as String) + "." + Self.GetVersionMinor() as String) + "." + Self.GetVersionBeta() as String) + " has been successfully installed.\nCopyright © 2017-2018, Seb263 - All rights reserved.\n\n", 0) ; #DEBUG_LINE_NO:105
    KFWelcomeMessage.Show(Self.GetVersionMajor() as Float, Self.GetVersionMinor() as Float, Self.GetVersionBeta() as Float, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:106
  Else
    Self.StartTimer(0.100000001, 0) ; #DEBUG_LINE_NO:108
    Debug.Trace(((("\n\nKnockout Framework version " + Self.GetVersionMajor() as String) + "." + Self.GetVersionMinor() as String) + "." + Self.GetVersionBeta() as String) + " has been successfully restarted.\nCopyright © 2017-2018, Seb263 - All rights reserved.\n\n", 0) ; #DEBUG_LINE_NO:109
  EndIf
  KFModVersionMajor.SetValue(Self.GetVersionMajor() as Float) ; #DEBUG_LINE_NO:111
  KFModVersionMinor.SetValue(Self.GetVersionMinor() as Float) ; #DEBUG_LINE_NO:112
  KFModVersionBeta.SetValue(Self.GetVersionBeta() as Float) ; #DEBUG_LINE_NO:113
  PlayerAliasScript.GoToState("") ; #DEBUG_LINE_NO:114
  MainScript.GoToState("") ; #DEBUG_LINE_NO:115
  FrameworkEventsScript.OnKoFrameworkInitializedEvent() ; #DEBUG_LINE_NO:116
  Self.Verification() ; #DEBUG_LINE_NO:117
EndFunction

Function Verification()
  Int VersionInt = Self.GetVersionInt() ; #DEBUG_LINE_NO:121
  Int OldVersionInt = Self.GetOldVersionInt() ; #DEBUG_LINE_NO:122
  If !Self.VerifyF4SE() ; #DEBUG_LINE_NO:124
    Return  ; #DEBUG_LINE_NO:125
  EndIf
  If OldVersionInt == 0 ; #DEBUG_LINE_NO:129
    KFModVersionMajor.SetValue(1.0) ; #DEBUG_LINE_NO:130
    OldVersionInt = Self.GetOldVersionInt() ; #DEBUG_LINE_NO:131
  EndIf
  If OldVersionInt > 0 && OldVersionInt != VersionInt ; #DEBUG_LINE_NO:134
    String Update = Self.Update() ; #DEBUG_LINE_NO:135
    If Update == "Update" ; #DEBUG_LINE_NO:136
      Debug.Trace(((("Knockout Framework has been updated to version " + Self.GetVersionMajor() as String) + "." + Self.GetVersionMinor() as String) + "." + Self.GetVersionBeta() as String) + ".", 0) ; #DEBUG_LINE_NO:137
      KFUpdateMessage.Show(KFModVersionMajor.GetValue(), KFModVersionMinor.GetValue(), KFModVersionBeta.GetValue(), Self.GetVersionMajor() as Float, Self.GetVersionMinor() as Float, Self.GetVersionBeta() as Float, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:138
      KFModVersionMajor.SetValue(Self.GetVersionMajor() as Float) ; #DEBUG_LINE_NO:139
      KFModVersionMinor.SetValue(Self.GetVersionMinor() as Float) ; #DEBUG_LINE_NO:140
      KFModVersionBeta.SetValue(Self.GetVersionBeta() as Float) ; #DEBUG_LINE_NO:141
    ElseIf Update == "Reset" ; #DEBUG_LINE_NO:142
      koframeworkfunctions.RestartMod(3) ; #DEBUG_LINE_NO:143
      Return  ; #DEBUG_LINE_NO:144
    EndIf
  ElseIf OldVersionInt == 0 ; #DEBUG_LINE_NO:146
    Self.Initialization() ; #DEBUG_LINE_NO:147
    Return  ; #DEBUG_LINE_NO:148
  EndIf
  ConfigScript.OnLoadGame() ; #DEBUG_LINE_NO:151
  KOCollectionScript.CleanUpKOActors() ; #DEBUG_LINE_NO:152
  EventsScript.CleanUpEvents() ; #DEBUG_LINE_NO:153
EndFunction

Event OnTimer(Int aiTimerID)
  ConfigScript.GoToState("RefreshState") ; #DEBUG_LINE_NO:157
EndEvent

Bool Function VerifyF4SE()
  If f4se.GetPluginVersion("KnockoutFramework") >= Self.GetVersionInt() ; #DEBUG_LINE_NO:161
    KFF4SEReady.SetValue(1.0) ; #DEBUG_LINE_NO:162
    Return True ; #DEBUG_LINE_NO:163
  Else
    KFF4SERequiredMessage.Show(Self.GetRequiredF4SEVersionMajor() as Float, Self.GetRequiredF4SEVersionMinor() as Float, Self.GetRequiredF4SEVersionBeta() as Float, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0) ; #DEBUG_LINE_NO:165
    KFF4SEReady.SetValue(0.0) ; #DEBUG_LINE_NO:166
    Return False ; #DEBUG_LINE_NO:167
  EndIf
EndFunction

Bool Function IsEligibleToSovngarde()
  Return Debug.GetPlatformName() as Bool ; #DEBUG_LINE_NO:172
EndFunction
