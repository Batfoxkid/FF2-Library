#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>

public Plugin myinfo = {
	name 		= "Freak Fortress 2: Mana System",
	description = "Uses config changes to give a mana pool from which to use abilities",
	author 		= "Deathreus",
	version 	= "0.1"
};

#define FF2_MAX_SLOTS 9			/** CT_BOSS_MG = (1 << 8) */

#define DEBUG

#define INACTIVE 10000000.0

bool UseManaThisRound[MAXPLAYERS];
float ManaPoolMax[MAXPLAYERS];
float ManaPerSecond[MAXPLAYERS];
float ManaCost[MAXPLAYERS][FF2_MAX_SLOTS];
char ManaAbility[MAXPLAYERS][FF2_MAX_SLOTS][128];
char ManaPlugin[MAXPLAYERS][FF2_MAX_SLOTS][128];

float ManaPoolCurrent[MAXPLAYERS];

float ManaNextTick[MAXPLAYERS];

Handle rageHUD;

Handle OnManaChanged;
Handle OnAbilityCast;

///	
enum struct AbilityInfo 
{
	char plugin_name[FF2_MAX_PLUGIN_NAME];
	char ability_name[FF2_MAX_ABILITY_NAME];
}

methodmap AbilityIterator < ArrayList 
{
	public AbilityIterator()
	{
		return view_as< AbilityIterator >(new ArrayList(sizeof(AbilityInfo)));
	}
	
	public bool FirstAbility(AbilityInfo info)
	{
		if (!this.Length)
			return false;
		return this.GetArray(0, info, sizeof(AbilityInfo)) != 0;
	}
	
	public bool NextAbility(int& pos, AbilityInfo info)
	{
		if (pos >= this.Length) 
			return false;
		this.GetArray(pos++, info, sizeof(AbilityInfo));
		return true;
	}
	
	public void PushAbility(const AbilityInfo info)
	{
		this.PushArray(info, sizeof(AbilityInfo));
	}
}
///

public void OnPluginStart()
{
	HookEvent("arena_round_start", _OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	
	CreateNative("FF2M_SetMana", Native_SetMana); // Set mana pool directly
	CreateNative("FF2M_AddMana", Native_AddMana); // Add to the mana pool, does not trigger OnManaChanged
	CreateNative("FF2M_SetupAbility", Native_SetupAbility); // Add an ability through plugin rather than config, if desired
	
	OnManaChanged = CreateGlobalForward("FF2M_OnManaChanged", ET_Hook, Param_Cell, Param_Float, Param_FloatByRef); // iBoss, oldValue, newValue
	OnAbilityCast = CreateGlobalForward("FF2M_OnAbilityCast", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_String, Param_FloatByRef); // iBoss, iSlot, pluginName, abilityName, cost
	
	rageHUD = CreateHudSynchronizer();
	
#if defined DEBUG
	RegConsoleCmd("_ff2_mana_test", CastAbility);
#endif

}

public void OnClientDisconnect(int iClient)
{
	UseManaThisRound[iClient] = false;
	ManaPoolMax[iClient] = 0.0;
	ManaPerSecond[iClient] = 0.0;
	ManaPoolCurrent[iClient] = 0.0;
	ManaNextTick[iClient] = INACTIVE;
	
	for(int iSlot = 1; iSlot < FF2_MAX_SLOTS; iSlot++)
	{
		ManaCost[iClient][iSlot] = 0.0;
		ManaAbility[iClient][iSlot][0] = '\0';
		ManaPlugin[iClient][iSlot][0] = '\0';
	}
}

public void _OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	for (int iIndex = 1; iIndex < MaxClients; iIndex++)
	{
		if (!IsClientInGame(iIndex))
			continue;
		
		FF2Player player = FF2Player(iIndex);
		if (player.bIsBoss)
		{
			float res;
			if (player.GetFloat("mana_max", res) && res)
			{
				UseManaThisRound[iIndex] = true;
				
				ManaPoolMax[iIndex] = res;
				ManaPerSecond[iIndex] = player.GetFloat("mana_regen", res) ? res:0.0;
				
				if(ManaPoolMax[iIndex] <= 0.0 || ManaPerSecond[iIndex] <= 0.0)
				{	// Break if we got invalid numbers
					UseManaThisRound[iIndex] = false;
					DebugMessage("Got bogus values for the mana pool: %.2f & %.2f", ManaPoolMax[iIndex], ManaPerSecond[iIndex]);
					return;
				}
				
				DebugMessage("Max mana for boss %N is %f, and regenerates at %f per second", iIndex, ManaPoolMax[iIndex], ManaPerSecond[iIndex]);
				
				ManaNextTick[iIndex] = GetEngineTime() + 0.2;
				SDKHook(iIndex, SDKHook_PreThink, ManaThink);
				
				StringMap abilities = player.HookedAbilities;
				AbilityIterator iter = EnumerateAbilities(abilities);
				
				AbilityInfo info;
				
				if (iter.FirstAbility(info))
				{
					for (int pos; iter.NextAbility(pos, info);)
					{
						for (int i; i < FF2_MAX_SLOTS; i++)
						{
							int _mslot = player.GetArgI(info.plugin_name, info.ability_name, "mana_slot", view_as<int>(CT_NONE));
							int slot = _mslot >> i;
							if(!slot)
								break;
							else if((slot & 1) != 1 || !_mslot)
								continue;
							
							ManaPlugin[iIndex][i] = info.plugin_name;
							ManaAbility[iIndex][i] = info.ability_name;
							
							ManaCost[iIndex][i] = player.GetArgF(info.plugin_name, info.ability_name, "mana_cost");
							DebugMessage("ManaUser[%i][%i] \tAbility name = %s, cost = %f", iIndex, i, ManaAbility[iIndex][i], ManaCost[iIndex][i]);
						}
					}
				}
				
				delete iter;
			}
		}
	}
}

public void OnRoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	for (int iClient = MaxClients; iClient > 0; iClient--)
	{
		if (UseManaThisRound[iClient])
		{
			UseManaThisRound[iClient] = false;
			ManaPoolCurrent[iClient] = 0.0;
			SDKUnhook(iClient, SDKHook_PreThink, ManaThink);
		}
	}
}

public FF2_PreAbility(FF2Player iIndex, const char[] pluginName, const char[] abilityName, FF2CallType_t reason_for_call, bool& bEnabled)
{
	int iBoss = iIndex.index;
	if (UseManaThisRound[iBoss] && (reason_for_call & CT_RAGE))
	{
		bEnabled = false;
		return;
	}
}

public void ManaThink(int iClient)
{
	if (FF2_GetRoundState() != 1 || !UseManaThisRound[iClient])
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

public Action CastAbility(int iClient, int nArgs)
{
	FF2Player iBoss = FF2Player(iClient);
	if (!iBoss.bIsBoss || !UseManaThisRound[iClient])
		return Plugin_Continue;
	
	char sCmd[48];
	GetCmdArg(1, sCmd, sizeof(sCmd));
	DebugMessage("Command recieved: %s", sCmd);
	
	char sSlot[16];
	for (int iSlot = 1; iSlot < FF2_MAX_SLOTS; iSlot++)
	{
		Format(sSlot, 16, "slot%b", 1 << iSlot);
		if (!strcmp(sCmd, sSlot))
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
			
			if (iResult > Plugin_Changed)
				return Plugin_Continue;
			
			iBoss.DoAbility(ManaPlugin[iClient][iSlot], ManaAbility[iClient][iSlot], CT_RAGE);
			ManaPoolCurrent[iClient] -= (iResult == Plugin_Changed) ? flNewValue : ManaCost[iClient][iSlot];
			
			DebugMessage("Using ability '%s' from '%s', taking %.2f mana away", ManaAbility[iClient][iSlot], ManaPlugin[iClient][iSlot], (iResult == Plugin_Changed) ? flNewValue : ManaCost[iClient][iSlot]);
		}
	}
	
	return Plugin_Handled;
}

public int Native_AddMana(Handle hPlugin, int nParams)
{
	int iBoss = GetNativeCell(1);
	if (iBoss > MaxClients || iBoss < 1)
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client (%d).", iBoss);
	
	float fMana = GetNativeCell(2);
	ManaPoolCurrent[iBoss] += fMana;
	
	return 1;
}

public int Native_SetMana(Handle hPlugin, int nParams)
{
	int iBoss = GetNativeCell(1);
	if (iBoss > MaxClients || iBoss < 1)
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


static AbilityIterator EnumerateAbilities(StringMap abilities)
{
	StringMapSnapshot snap = abilities.Snapshot();
	int count = snap.Length;
	AbilityIterator iter = new AbilityIterator();
	
	char[] ability_key = new char[FF2_MAX_LIST_KEY];
	char info[2][FF2_MAX_ABILITY_NAME];
	
	AbilityInfo res;
	
	for (int i = 1; i < count; i++) 
	{
		int size = snap.KeyBufferSize(i);
		char[] ability = new char[size];
		abilities.GetString(ability, ability_key, FF2_MAX_LIST_KEY);
		
		ExplodeString(ability_key, "##", info, sizeof(info), sizeof(info[]));
		
		res.plugin_name = info[0];
		res.ability_name = info[1];
		iter.PushAbility(res);
	}
	
	delete snap;
	return iter;
}
