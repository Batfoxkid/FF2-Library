#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

bool isBlockBuildables;
Handle KSpreeTimer[MAXPLAYERS+1];
int KSpreeCount[MAXPLAYERS+1];
Handle SeeTimer;
#define RESTORE_HUD		(1 << 0)
#define RESTORE_DMG		(1 << 1)
#define RESTORE_SPAWN	0
int need_restores[MAXPLAYERS+1];
bool no_damage[MAXPLAYERS+1];

public Plugin myinfo = {
	name = "Freak Fortress 2: Dead Run Boss",
	author = "RainBolt Dash",
};

public void OnPluginStart2()
{
	HookEvent("player_spawn", event_player_spawn);
	HookEvent("player_death", event_player_death);
}

public Action FF2_OnAbility2(int index,const char[] plugin_name,const char[] ability_name, int action)
{
	return Plugin_Continue;
}

public Action Timer_See(Handle timer,any index)
{
	static float pos[3];
	static float pos2[3];
	int Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if (Boss<1 || !IsPlayerAlive(Boss))
	{
		SeeTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	GetEntPropVector(Boss, Prop_Send, "m_vecOrigin", pos2); 
	if (GetVectorDistance(pos,pos2)<100)
	{
		char s[PLATFORM_MAX_PATH];
		if (FF2_RandomSound("sound_move",s,PLATFORM_MAX_PATH,index))
		{
			EmitSoundToAll(s);
			EmitSoundToAll(s);
		}
		else
		{
			SeeTimer = INVALID_HANDLE;
			return Plugin_Stop;
		}
	}
	pos[0]=pos2[0];
	pos[1]=pos2[1];
	pos[2]=pos2[2];
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	need_restores[client] = RESTORE_SPAWN;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action event_player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client < 1 || !IsValidEntity(client)) return Plugin_Continue;
	
	if (need_restores[client] & RESTORE_HUD)
	{
		FF2_SetFF2flags(client,FF2_GetFF2flags(client) & ~FF2FLAG_HUDDISABLED);
		need_restores[client] &= ~RESTORE_HUD;
	}
	if (need_restores[client] & RESTORE_DMG)
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2);
		need_restores[client] &= ~RESTORE_DMG;
	}
	
	int index=FF2_GetBossIndex(client);
	if (index == -1) return Plugin_Continue;
	if (!index && FF2_HasAbility(index,this_plugin_name,"deadrun_lines"))
		SeeTimer = CreateTimer(12.0,Timer_See,0,TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	if (FF2_HasAbility(index,this_plugin_name,"deadrun_no_any_damage"))
	{	
		if (GetEntProp(client, Prop_Data, "m_takedamage") == 2)
			need_restores[client] |= RESTORE_DMG;
		SetEntProp(client, Prop_Data, "m_takedamage", 0);
	}
	else
		no_damage[index]=FF2_HasAbility(index,this_plugin_name,"deadrun_no_damage");
	if (FF2_HasAbility(index,this_plugin_name,"deadrun_no_hud_for_all"))
	{	
		int flags;
		for (int client2 = 1; client2 <= MaxClients ; client2++)
		{
			flags = FF2_GetFF2flags(client2);
			if (!(flags & FF2FLAG_HUDDISABLED))
				need_restores[client2] |= RESTORE_HUD;
			FF2_SetFF2flags(client2,flags | FF2FLAG_HUDDISABLED);
		}
	}
	if (FF2_HasAbility(index,this_plugin_name,"deadrun_block_buildables"))
		isBlockBuildables = true;
	else
		isBlockBuildables = false;
	if (SeeTimer != INVALID_HANDLE)
		KillTimer(SeeTimer);
	
	return Plugin_Continue;
}

public Action OnTakeDamage(int client, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon,
							float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker > 0 && attacker <= MaxClients)
	{
		int index = FF2_GetBossIndex(client);
		if (index != -1 && no_damage[index])
			return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && IsValidEdict(client))
		OnPlayerDeath(client, GetClientOfUserId(event.GetInt("attacker")), !!event.GetInt("feign_death"));
	return Plugin_Continue;
}

void OnPlayerDeath(int client, int attacker, bool fake = false)
{
	if (FF2_GetBossIndex(client)!=-1) return;
	int index=FF2_GetBossIndex(attacker);
	if (index == -1) return;
	if (!FF2_HasAbility(index,this_plugin_name,"deadrun_lines")) return;
	
	char s[PLATFORM_MAX_PATH];
	if (fake && FF2_RandomSound("sound_spy_invis",s,PLATFORM_MAX_PATH,index))
	{
		EmitSoundToAll(s);
		EmitSoundToAll(s);
		return;
	}	
	if (TF2_IsPlayerInCondition(client, TFCond_Cloaked) && FF2_RandomSound("sound_kill_spy",s,PLATFORM_MAX_PATH,index))
	{
		EmitSoundToAll(s);
		EmitSoundToAll(s);
		return;
	}
	
	KSpreeCount[index]++;
	if (!KSpreeTimer[index])
		KSpreeTimer[index] = CreateTimer(3.0,Timer_KSpree,index);
	if (KSpreeCount[index] == 4) 
	{
		if (FF2_RandomSound("sound_kspree",s,PLATFORM_MAX_PATH,index))
		{
			EmitSoundToAll(s);
			EmitSoundToAll(s);
		}
		KSpreeCount[index] = 0;
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, 
							float vel[3], float angles[3], int& weapon, 
							int &subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (isBlockBuildables && TF2_GetPlayerClass(client) == TFClass_Engineer &&
		GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") > GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) &&
		buttons & IN_ATTACK )
	{
		buttons&=~IN_ATTACK;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}


public Action Timer_KSpree(Handle timer, any index)
{
	KSpreeCount[index] = 0;
	KSpreeTimer[index] = INVALID_HANDLE;
	return Plugin_Continue;
}

public Action FF2_OnLoadCharacterSet(int& CharSetNum, char[] CharSetName)
{
	char s[16];
	GetNextMap(s,16);
	if (!StrContains(s,"vsh_dr_") || !StrContains(s,"dr_") || !StrContains(s,"deadrun_"))
	{
		strcopy(CharSetName,32,"Dead Run");
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
