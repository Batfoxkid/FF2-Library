#pragma semicolon 1
	
#include <sourcemod>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <sdkhooks>

public Plugin myinfo = {
	name		= "Freak Fortress 2: Mannpower Passives",
	author		= "Deathreus",
	description = "Adds any Mannpower Powerup as a passive ability",
	version		= "1.0",
};

//new BossTeam = _:TFTeam_Blue;


public OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_Post);
	//HookEvent("teamplay_round_win", event_round_end);
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl Boss;
	for (new Index = 0; (Boss=GetClientOfUserId(FF2_GetBossUserId(Index)))>0; Index++)
	{
		if(FF2_HasAbility(Index, this_plugin_name, "passive_powerups"))
		{
			new CondType = FF2_GetAbilityArgument(Index, this_plugin_name, "passive_powerups", 1, 1);
			new TFCond:Condition;
			switch(CondType)
			{
				case 1: Condition = TFCond:90; // Strength
				case 2: Condition = TFCond:91; // Haste
				case 3: Condition = TFCond:92; // Regen
				case 4: Condition = TFCond:93; // Resistance
				case 5: Condition = TFCond:94; // Vampire
				case 6: Condition = TFCond:95; // Warlock
				case 7: Condition = TFCond:96; // Precision
				case 8: Condition = TFCond:97; // Agility
				case 9: Condition = TFCond:103; // Knockout
			}
			TF2_AddCondition(Boss, Condition, TFCondDuration_Infinite);
		}
	}
	return Plugin_Continue;
}

public Action:FF2_OnAbility2(client, const String:plugin_name[], const String:ability_name[], status){
	return Plugin_Continue;
//Y u no let me compile without this
}