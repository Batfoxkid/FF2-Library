#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>

public Plugin myinfo = {
	name 		= "Freak Fortress 2: Mana System",
	description = "Uses config changes to give a mana pool from which to use abilities",
	author 		= "Deathreus",
	version 	= "0.1"
};

#define DEBUG

#define INACTIVE 10000000.0

bool UseManaThisRound[MAXPLAYERS];
float ManaPoolMax[MAXPLAYERS];
float ManaPerSecond[MAXPLAYERS];
float ManaCost[MAXPLAYERS][10];
char ManaAbility[MAXPLAYERS][10][128];
char ManaPlugin[MAXPLAYERS][10][128];

float ManaPoolCurrent[MAXPLAYERS];

float ManaNextTick[MAXPLAYERS];

Handle rageHUD;

Handle OnManaChanged;
Handle OnAbilityCast;

public void OnPluginStart()
{
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	
	CreateNative("FF2M_SetMana", Native_SetMana); // Set mana pool directly
	CreateNative("FF2M_AddMana", Native_AddMana); // Add to the mana pool, does not trigger OnManaChanged
	CreateNative("FF2M_SetupAbility", Native_SetupAbility); // Add an ability through plugin rather than config, if desired
	
	OnManaChanged = CreateGlobalForward("FF2M_OnManaChanged", ET_Hook, Param_Cell, Param_Float, Param_FloatByRef); // iBoss, oldValue, newValue
	OnAbilityCast = CreateGlobalForward("FF2M_OnAbilityCast", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_String, Param_FloatByRef); // iBoss, iSlot, pluginName, abilityName, cost
	
	rageHUD = CreateHudSynchronizer();
}

public void OnClientDisconnect(int iClient)
{
	UseManaThisRound[iClient] = false;
	ManaPoolMax[iClient] = 0.0;
	ManaPerSecond[iClient] = 0.0;
	ManaPoolCurrent[iClient] = 0.0;
	ManaNextTick[iClient] = INACTIVE;
	
	for(int iSlot = 1; iSlot <= 9; iSlot++)
	{
		ManaCost[iClient][iSlot] = 0.0;
		ManaAbility[iClient][iSlot][0] = '\0';
		ManaPlugin[iClient][iSlot][0] = '\0';
	}
}

public void OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	for(int iIndex; iIndex < MAXPLAYERS; iIndex++)
	{
		int iBoss = GetClientOfUserId(FF2_GetBossUserId(iIndex));
		KeyValues kv = view_as<KeyValues>(FF2_GetSpecialKV(iIndex));
		if(kv)
		{
			if(kv.GetFloat("mana_max") != 0.0)
			{
				UseManaThisRound[iBoss] = true;
				
				ManaPoolMax[iBoss] = kv.GetFloat("mana_max");
				ManaPerSecond[iBoss] = kv.GetFloat("mana_regen");
				
				if(ManaPoolMax[iBoss] <= 0.0 || ManaPerSecond[iBoss] <= 0.0)
				{	// Break if we got invalid numbers
					UseManaThisRound[iBoss] = false;
					DebugMessage("Got bogus values for the mana pool: %.2f & %.2f", ManaPoolMax[iBoss], ManaPerSecond[iBoss]);
					return;
				}
				
				DebugMessage("Max mana for boss %N is %f, and regenerates at %f per second", iBoss, ManaPoolMax[iBoss], ManaPerSecond[iBoss]);
				
				ManaNextTick[iBoss] = GetEngineTime() + 0.2;
				SDKHook(iBoss, SDKHook_PreThink, ManaThink);
				
				char sAbility[12];
				for(int iSlot = 1; iSlot <= 9; iSlot++)
				{
					for(int i = 1; i <= 16; i++)
					{
						Format(sAbility, sizeof(sAbility), "ability%i", i);
						if(kv.JumpToKey(sAbility))
						{
							if(!kv.GetNum("mana_slot") || kv.GetNum("mana_slot") != iSlot)
								continue;
							
							kv.GetString("name", ManaAbility[iBoss][iSlot], sizeof(ManaAbility[][]));
							kv.GetString("plugin_name", ManaPlugin[iBoss][iSlot], sizeof(ManaPlugin[][]));
							ManaCost[iBoss][iSlot] = kv.GetFloat("mana_cost");
							
							DebugMessage("Ability name = %s, cost = %f, for slot %i", ManaAbility[iBoss][iSlot], ManaCost[iBoss][iSlot], iSlot);
							
							kv.GoBack();
						}
					}
				}
			}
		}
	}
}

public void OnRoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	for(int iClient = MaxClients; iClient > 0; iClient--)
	{
		if(UseManaThisRound[iClient])
		{
			UseManaThisRound[iClient] = false;
			ManaPoolCurrent[iClient] = 0.0;
			SDKUnhook(iClient, SDKHook_PreThink, ManaThink);
		}
	}
}

public FF2_PreAbility(int iIndex, const char[] pluginName, const char[] abilityName, int iSlot, bool &bEnabled)
{
	int iBoss = GetClientOfUserId(FF2_GetBossUserId(iIndex));
	if(UseManaThisRound[iBoss] && (iSlot == 0 || !strncmp(abilityName, "rage_", 5)))
	{
		bEnabled = false;
		return;
	}
}

public void ManaThink(int iClient)
{
	if(FF2_GetRoundState() != 1 || !UseManaThisRound[iClient])
	{
		ManaNextTick[iClient] = INACTIVE;
		return;
	}
	
	if(ManaNextTick[iClient] <= GetEngineTime())
	{
		Call_StartForward(OnManaChanged);
		Call_PushCell(iClient);
		Call_PushFloat(ManaPoolCurrent[iClient]);
		float flNewValue = ManaPoolCurrent[iClient] + (ManaPerSecond[iClient] / 5.0);	// 5 updates per second
		Call_PushFloatRef(flNewValue);
		Action iResult = Plugin_Continue;
		Call_Finish(iResult);
		
		if(iResult == Plugin_Changed)
			ManaPoolCurrent[iClient] = flNewValue;
		else if(iResult == Plugin_Continue)
			ManaPoolCurrent[iClient] += (ManaPerSecond[iClient] / 5.0);
		
		if(ManaPoolCurrent[iClient] > ManaPoolMax[iClient]) // clamp
			ManaPoolCurrent[iClient] = ManaPoolMax[iClient];
		
		SetHudTextParams(-1.0, 0.83, 0.15, 255, 255, 255, 255);
		ShowSyncHudText(iClient, rageHUD, "Mana: %.0f / %.0f", ManaPoolCurrent[iClient], ManaPoolMax[iClient]);
		
		FF2_SetBossCharge(FF2_GetBossIndex(iClient), 0, 100.0);
		
		ManaNextTick[iClient] = GetEngineTime() + 0.2;
	}
}

public Action CastAbility(int iClient, const char[] sCmd, int nArgs)
{
	int iBoss = FF2_GetBossIndex(iClient)
	if(iBoss < 0 || !UseManaThisRound[iClient])
		return Plugin_Continue;
	
	DebugMessage("Command recieved: %s", sCmd);
	
	char sSlot[6];
	for(int iSlot = 1; iSlot <= 9; iSlot++)
	{
		Format(sSlot, 6, "slot%i", iSlot);
		if(!strcmp(sCmd, sSlot))
		{
			Call_StartForward(OnAbilityCast);
			Call_PushCell(iClient);
			Call_PushCell(iSlot);
			Call_PushString(ManaPlugin[iClient][iSlot]);
			Call_PushString(ManaAbility[iClient][iSlot]);
			float flNewValue = ManaCost[iClient][iSlot];
			Call_PushFloatRef(flNewValue);
			Action iResult = Plugin_Continue;
			Call_Finish(iResult);
			
			if(iResult > Plugin_Changed)
				return Plugin_Continue;
			
			FF2_DoAbility(iBoss, ManaPlugin[iClient][iSlot], ManaAbility[iClient][iSlot], 0, 0);
			ManaPoolCurrent[iClient] -= (iResult == Plugin_Changed) ? flNewValue : ManaCost[iClient][iSlot];
			
			DebugMessage("Using ability '%s' from '%s', taking %.2f mana away", ManaAbility[iClient][iSlot], ManaPlugin[iClient][iSlot], (iResult == Plugin_Changed) ? flNewValue : ManaCost[iClient][iSlot]);
		}
	}
	
	return Plugin_Handled;
}

public int Native_AddMana(Handle hPlugin, int nParams)
{
	int iBoss = GetNativeCell(1);
	if(iBoss > MaxClients || iBoss < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client (%d).", iBoss);
	
	float fMana = GetNativeCell(2);
	ManaPoolCurrent[iBoss] += fMana;
	
	return 1;
}

public int Native_SetMana(Handle hPlugin, int nParams)
{
	int iBoss = GetNativeCell(1);
	if(iBoss > MaxClients || iBoss < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client (%d).", iBoss);
	
	float fMana = GetNativeCell(2);
	ManaPoolCurrent[iBoss] = fMana;
	
	return 1;
}

public int Native_SetupAbility(Handle hPlugin, int nParams)
{
	int iBoss = GetNativeCell(1);
	if(iBoss > MaxClients || iBoss < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client (%d).", iBoss);
	
	int iSlot = GetNativeCell(2);
	if(iSlot <= 0 || iSlot >= 10)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid slot for ability (%d).", iSlot);

	if(ManaAbility[iBoss][iSlot][0] != '\0')
		return ThrowNativeError(SP_ERROR_NATIVE, "Slot %d already has an ability.", iSlot);
	
	int i3;
	GetNativeStringLength(3, i3);
	char[] pluginName = new char[i3+1];
	GetNativeString(3, pluginName, i3);
	if(!pluginName[0])
		return ThrowNativeError(SP_ERROR_NATIVE, "Empty string found for plugin name, you must supply it!");
	
	int i4;
	GetNativeStringLength(4, i4);
	char[] abilityName = new char[i4+1];
	GetNativeString(4, abilityName, i4);
	if(!abilityName[0])
		return ThrowNativeError(SP_ERROR_NATIVE, "Empty string found for ability name, you must supply it!");
	
	float fManaCost = GetNativeCell(5);
	
	strcopy(ManaPlugin[iBoss][iSlot], sizeof(ManaPlugin[][]), pluginName);
	strcopy(ManaAbility[iBoss][iSlot], sizeof(ManaAbility[][]), abilityName);
	ManaCost[iBoss][iSlot] = fManaCost;
	
	DebugMessage("Successfully set up a new ability into slot %i; Plugin: '%s' Ability: '%s' Cost: %.2f", iSlot, ManaPlugin[iBoss][iSlot], ManaAbility[iBoss][iSlot], ManaCost[iBoss][iSlot]);
	
	return 1;
}

stock void DebugMessage(const char[] sFormat, any ...)
{
#if defined DEBUG
	char sMessage[256];
	VFormat(sMessage, 255, sFormat, 2);
	LogMessage("%s", sMessage);
#endif
}
