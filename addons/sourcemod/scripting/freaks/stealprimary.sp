#include <tf2_stocks>
#include <ff2_ams2>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define STEALING "rage_stealing"
bool Stealing_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

public Plugin myinfo = {
	name = "Freak Fortress 2: Stealing Stuff",
	author = "M7",
};

public void OnPluginStart2()
{
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
}

public void FF2AMS_PreRoundStart(int client)
{
	if(FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, STEALING))
	{
		Stealing_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, STEALING, "STEA");
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			Stealing_TriggerAMS[client]=false;
		}
	}
}
			
public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	//Make sure that RAGE is only allowed to be used when a FF2 round is active
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;
		
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name,STEALING))	// Defenses
	{
		if(!LibraryExists("FF2AMS"))
		{
			Stealing_TriggerAMS[client]=false;
		}
		
		if(!Stealing_TriggerAMS[client])
			STEA_Invoke(client, -1);
	}
	return Plugin_Continue;
}

public AMSResult STEA_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void STEA_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	float bossPosition[3], targetPosition[3], sentryPosition[3], dispenserPosition[3], teleporterPosition[3];
	
	if(Stealing_TriggerAMS[client])
	{
		char snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_stealing", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
	
	float changetostealprimary = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 1);
	float rangetostealprimary = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 2);
	float changetostealsecondary = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 3);
	float rangetostealsecondary = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 4);
	float changetostealmelee = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 5);
	float rangetostealmelee = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 6);
	
	float changetostealsentry = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 7);
	float rangetostealsentry = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 8);
	float changetostealdispenser = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 9);
	float rangetostealdispenser = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 10);
	float changetostealteleporters = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 11);
	float rangetostealteleporters = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 12);
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			if((GetRandomFloat(0.0, 1.0)<=changetostealprimary) && (GetVectorDistance(bossPosition, targetPosition)<=rangetostealprimary))
			{
				TF2_RemoveWeaponSlot(target, TFWeaponSlot_Primary);
			}
			if((GetRandomFloat(0.0, 1.0)<=changetostealsecondary) && (GetVectorDistance(bossPosition, targetPosition)<=rangetostealsecondary))
			{
				TF2_RemoveWeaponSlot(target, TFWeaponSlot_Secondary);
			}
			if((GetRandomFloat(0.0, 1.0)<=changetostealmelee) && (GetVectorDistance(bossPosition, targetPosition)<=rangetostealmelee))
			{
				TF2_RemoveWeaponSlot(target, TFWeaponSlot_Melee);
			}
			
			// Set's the players active weapon if the weapon they were using was removed
			if (GetPlayerWeaponSlot(target, 0) == -1 && GetPlayerWeaponSlot(target, 1) == -1)
				SwitchtoSlot(target, TFWeaponSlot_Melee);
			else if (GetPlayerWeaponSlot(target, 1) == -1)
				SwitchtoSlot(target, TFWeaponSlot_Primary);
			else if (GetPlayerWeaponSlot(target, 0) == -1)
				SwitchtoSlot(target, TFWeaponSlot_Secondary);
		}
	}
	
	int sentry = FindEntityByClassname(sentry, "obj_sentrygun");
	if(IsValidEntity(sentry))
	{
		GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentryPosition);
		if(GetVectorDistance(bossPosition, sentryPosition)<=rangetostealsentry)
		{
			if(GetRandomFloat(0.0, 1.0)<=changetostealsentry)
			{
				RemoveEntity(sentry);
			}
		}
	}
	
	int dispenser = FindEntityByClassname(dispenser, "obj_dispenser");
	if(IsValidEntity(dispenser))
	{
		GetEntPropVector(dispenser, Prop_Send, "m_vecOrigin", dispenserPosition);
		if(GetVectorDistance(bossPosition, dispenserPosition)<=rangetostealdispenser)
		{
			if(GetRandomFloat(0.0, 1.0)<=changetostealdispenser)
			{
				RemoveEntity(dispenser);
			}
		}
	}
	
	int teleporters = FindEntityByClassname(teleporters, "obj_teleporter");
	if(IsValidEntity(teleporters))
	{
		GetEntPropVector(teleporters, Prop_Send, "m_vecOrigin", teleporterPosition);
		if(GetVectorDistance(bossPosition, teleporterPosition)<=rangetostealteleporters)
		{
			if(GetRandomFloat(0.0, 1.0)<=changetostealteleporters)
			{
				RemoveEntity(teleporters);
			}
		}
	}
}

stock void SwitchtoSlot(int iClient, int iSlot)
{
	if (iSlot >= 0 && iSlot <= 5 && IsClientInGame(iClient) && IsPlayerAlive(iClient))
	{
		char strClassname[64];
		int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
		if (iWeapon > MaxClients && IsValidEdict(iWeapon) && GetEdictClassname(iWeapon, strClassname, sizeof(strClassname)))
		{
			FakeClientCommandEx(iClient, "use %s", strClassname);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
		}
	}
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}
