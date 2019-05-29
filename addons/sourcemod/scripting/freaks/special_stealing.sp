#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
//#tryinclude <freak_fortress_2_extras> 

#define STEALING "rage_stealing"
new bool:Stealing_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

public Plugin:myinfo = {
	name = "Freak Fortress 2: Stealing Stuff",
	author = "M7",
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_Pre);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
		
		Stealing_TriggerAMS[client] = false;
		
		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			if(FF2_HasAbility(boss, this_plugin_name, STEALING))
			{
				Stealing_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, STEALING);
				if(Stealing_TriggerAMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, STEALING, "STEA");
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			Stealing_TriggerAMS[client]=false;
		}
	}
}
			

public Action:FF2_OnAbility2(boss,const String:plugin_name[],const String:ability_name[],action)
{
	//Make sure that RAGE is only allowed to be used when a FF2 round is active
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue;
		
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name,STEALING))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Stealing_TriggerAMS[client]=false;
		}
		
		if(!Stealing_TriggerAMS[client])
			STEA_Invoke(client);
	}
	return Plugin_Continue;
}

public bool:STEA_CanInvoke(client)
{
	return true;
}

public STEA_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	new Float:bossPosition[3], Float:targetPosition[3], Float:sentryPosition[3], Float:dispenserPosition[3], Float:teleporterPosition[3];
	
	if(Stealing_TriggerAMS[client])
	{
		new String:snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_stealing", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
	
	new Float:changetostealprimary = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 1);
	new Float:rangetostealprimary = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 2);
	new Float:changetostealsecondary = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 3);
	new Float:rangetostealsecondary = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 4);
	new Float:changetostealmelee = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 5);
	new Float:rangetostealmelee = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 6);
	
	new Float:changetostealsentry = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 7);
	new Float:rangetostealsentry = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 8);
	new Float:changetostealdispenser = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 9);
	new Float:rangetostealdispenser = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 10);
	new Float:changetostealteleporters = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 11);
	new Float:rangetostealteleporters = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STEALING, 12);
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	for(new target=1; target<=MaxClients; target++)
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
	
	new sentry = FindEntityByClassname(sentry, "obj_sentrygun");
	if(IsValidEntity(sentry))
	{
		GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentryPosition);
		if(GetVectorDistance(bossPosition, sentryPosition)<=rangetostealsentry)
		{
			if(GetRandomFloat(0.0, 1.0)<=changetostealsentry)
			{
				AcceptEntityInput(sentry, "Kill");
			}
		}
	}
	
	new dispenser = FindEntityByClassname(dispenser, "obj_dispenser");
	if(IsValidEntity(dispenser))
	{
		GetEntPropVector(dispenser, Prop_Send, "m_vecOrigin", dispenserPosition);
		if(GetVectorDistance(bossPosition, dispenserPosition)<=rangetostealdispenser)
		{
			if(GetRandomFloat(0.0, 1.0)<=changetostealdispenser)
			{
				AcceptEntityInput(dispenser, "Kill");
			}
		}
	}
	
	new teleporters = FindEntityByClassname(teleporters, "obj_teleporter");
	if(IsValidEntity(teleporters))
	{
		GetEntPropVector(teleporters, Prop_Send, "m_vecOrigin", teleporterPosition);
		if(GetVectorDistance(bossPosition, teleporterPosition)<=rangetostealteleporters)
		{
			if(GetRandomFloat(0.0, 1.0)<=changetostealteleporters)
			{
				AcceptEntityInput(teleporters, "Kill");
			}
		}
	}
}

stock SwitchtoSlot(int iClient, int iSlot)
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

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}