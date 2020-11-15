#define FF2_USING_AUTO_PLUGIN__OLD
	
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name		= "Freak Fortress 2: Mannpower Passives",
	author		= "Deathreus",
	description = "Adds any Mannpower Powerup as a passive ability",
	version		= "1.0",
};

//new BossTeam = _:TFTeam_Blue;


public void OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_Post);
	//HookEvent("teamplay_round_win", event_round_end);
}

public Action event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	int Boss;
	for (int Index = 0; (Boss=GetClientOfUserId(FF2_GetBossUserId(Index)))>0; Index++)
	{
		if(FF2_HasAbility(Index, this_plugin_name, "passive_powerups"))
		{
			int CondType = FF2_GetAbilityArgument(Index, this_plugin_name, "passive_powerups", 1, 1);
			TFCond Condition;
			switch(CondType)
			{
				case 1: Condition = view_as<TFCond>(90); // Strength
				case 2: Condition = view_as<TFCond>(91); // Haste
				case 3: Condition = view_as<TFCond>(92); // Regen
				case 4: Condition = view_as<TFCond>(93); // Resistance
				case 5: Condition = view_as<TFCond>(94); // Vampire
				case 6: Condition = view_as<TFCond>(95); // Warlock
				case 7: Condition = view_as<TFCond>(96); // Precision
				case 8: Condition = view_as<TFCond>(97); // Agility
				case 9: Condition = view_as<TFCond>(103); // Knockout
			}
			TF2_AddCondition(Boss, Condition, TFCondDuration_Infinite);
		}
	}
	return Plugin_Continue;
}

public Action FF2_OnAbility2(int client, const char[] plugin_name, const char[] ability_name, int status){
	return Plugin_Continue;
//Y u no let me compile without this
}
