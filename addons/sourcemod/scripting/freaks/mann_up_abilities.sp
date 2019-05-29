//One of the simplest plugin i have done in quite some time

#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
//#include <freak_fortress_2_extras>

#define BOSSDISSOLVES "special_boss_dissolves"
#define BOSS_COMPANIONS_DIES "special_companions_die"

#define MANNUP_LINES "special_mann_up_lines"
new bool:BossWinner = false;

// Level Up Enabled Indicator
static const String:MannUpStart[][] = {
	"vo/mvm_mann_up_mode01.mp3",
	"vo/mvm_mann_up_mode02.mp3",
	"vo/mvm_mann_up_mode03.mp3",
	"vo/mvm_mann_up_mode04.mp3",
	"vo/mvm_mann_up_mode05.mp3",
	"vo/mvm_mann_up_mode06.mp3",
	"vo/mvm_mann_up_mode07.mp3",
	"vo/mvm_mann_up_mode08.mp3",
	"vo/mvm_mann_up_mode09.mp3",
	"vo/mvm_mann_up_mode10.mp3",
	"vo/mvm_mann_up_mode11.mp3",
	"vo/mvm_mann_up_mode12.mp3",
	"vo/mvm_mann_up_mode13.mp3",
	"vo/mvm_mann_up_mode14.mp3",
	"vo/mvm_mann_up_mode15.mp3"
};

// Round Result
static const String:BossIsDefeated[][] = {
	"vo/mvm_manned_up01.mp3",
	"vo/mvm_manned_up02.mp3",
	"vo/mvm_manned_up03.mp3"
};

static const String:BossIsVictorious[][] = {
	"vo/mvm_game_over_loss01.mp3",
	"vo/mvm_game_over_loss02.mp3",
	"vo/mvm_game_over_loss03.mp3",
	"vo/mvm_game_over_loss04.mp3",
	"vo/mvm_game_over_loss05.mp3",
	"vo/mvm_game_over_loss06.mp3",
	"vo/mvm_game_over_loss07.mp3",
	"vo/mvm_game_over_loss08.mp3",
	"vo/mvm_game_over_loss09.mp3",
	"vo/mvm_game_over_loss10.mp3",
	"vo/mvm_game_over_loss11.mp3"
};

public Plugin:myinfo = {
	name	= "Freak Fortress 2: Ready to Mann Up?",
	author	= "M7",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", OnPlayerDeath);
	
	// Manning Up & Round Result Lines
	for (new i = 0; i < sizeof(MannUpStart); i++)
	{
		PrecacheSound(MannUpStart[i], true);
	}
	for (new i = 0; i < sizeof(BossIsDefeated); i++)
	{
		PrecacheSound(BossIsDefeated[i], true);
	}
	for (new i = 0; i < sizeof(BossIsVictorious); i++)
	{
		PrecacheSound(BossIsVictorious[i], true);
	}
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
		
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			new boss=FF2_GetBossIndex(client);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, this_plugin_name, MANNUP_LINES))
				{
					CreateTimer(6.0, AnnouncerIsReady);
				}
			}
		}
	}
}

public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1; client<=MaxClients; client++)
	{
		new boss=FF2_GetBossIndex(client);
		if(FF2_HasAbility(boss, this_plugin_name, MANNUP_LINES))
		{
			if(GetEventInt(event, "winning_team") == FF2_GetBossTeam())
				BossWinner = true;
			else if (GetEventInt(event, "winning_team") == ((FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue)))
				BossWinner = false;
			
			CreateTimer(5.0, WinnerIsAnnounced);
		}
	}
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return Plugin_Continue;
	}
	
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	
	new boss=FF2_GetBossIndex(client);	// Boss is the victim
	if(boss!=-1 && FF2_HasAbility(boss, this_plugin_name, BOSS_COMPANIONS_DIES) && !(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		for(new clone=1; clone<=MaxClients; clone++)
		{
			if (IsClientInGame(clone) && IsPlayerAlive(client) && GetClientTeam(clone) == FF2_GetBossTeam())
            {
                ForcePlayerSuicide(clone);
            }
		}
	}
	if(boss!=-1 && FF2_HasAbility(boss, this_plugin_name, BOSSDISSOLVES))
	{
		CreateTimer(0.1, Timer_DissolveRagdoll, boss);
	}
	return Plugin_Continue;
}

public Action:Timer_DissolveRagdoll(Handle:timer, any:userid)
{
	new client=GetClientOfUserId(userid);
	new ragdoll=-1;
	if(client && IsClientInGame(client))
	{
		ragdoll=GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	}

	if(ragdoll!=-1)
	{
		DissolveRagdoll(ragdoll);
	}
}

DissolveRagdoll(ragdoll)
{
	new dissolver=CreateEntityByName("env_entity_dissolver");
	if(dissolver==-1)
	{
		return;
	}

	DispatchKeyValue(dissolver, "dissolvetype", "0");
	DispatchKeyValue(dissolver, "magnitude", "200");
	DispatchKeyValue(dissolver, "target", "!activator");

	AcceptEntityInput(dissolver, "Dissolve", ragdoll);
	AcceptEntityInput(dissolver, "Kill");
}

public Action:FF2_OnAbility2(client, const String:plugin_name[], const String:ability_name[], status)
{
	return Plugin_Continue;
}

public Action:AnnouncerIsReady(Handle:timer)
{
	WhatWereYouThinking();
	return Plugin_Continue;
}
public WhatWereYouThinking()
{
	new String:Alert[PLATFORM_MAX_PATH];
	strcopy(Alert, PLATFORM_MAX_PATH, MannUpStart[GetRandomInt(0, sizeof(MannUpStart)-1)]);
	EmitSoundToAll(Alert);
}

public Action:WinnerIsAnnounced(Handle:timer)
{
	EndOfTheLine();
	return Plugin_Continue;
}
public EndOfTheLine()
{
	new String:RoundResult[PLATFORM_MAX_PATH];
	if (BossWinner)
		strcopy(RoundResult, PLATFORM_MAX_PATH, BossIsVictorious[GetRandomInt(0, sizeof(BossIsVictorious)-1)]);
	else
		strcopy(RoundResult, PLATFORM_MAX_PATH, BossIsDefeated[GetRandomInt(0, sizeof(BossIsDefeated)-1)]);	
	for(new i = 1; i <= MaxClients; i++ )
	{
		if(IsClientInGame(i) && IsClientConnected(i) && GetClientTeam(i) != FF2_GetBossTeam())
		{
			EmitSoundToClient(i, RoundResult);	
		}
	}
	BossWinner = false;
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}