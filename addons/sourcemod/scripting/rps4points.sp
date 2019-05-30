/*
    ____  ____  _____    __ __     ____        _       __      
   / __ \/ __ \/ ___/   / // /    / __ \____  (_)___  / /______
  / /_/ / /_/ /\__ \   / // /_   / /_/ / __ \/ / __ \/ __/ ___/
 / _, _/ ____/___/ /  /__  __/  / ____/ /_/ / / / / / /_(__  ) 
/_/ |_/_/    /____/     /_/    /_/    \____/_/_/ /_/\__/____/  
	A new way to earn queue points in Freak Fortress 2
					by SHADoW NiNE TR3S
					
					HOW IT WORKS:
				RPS a teammate or a minion.
	Whoever wins earns a certain amount of queue points
	while the loser loses these specified queue points
	
				ADJUSTING PRIZE QUEUE POINTS:
	Set "rps4points_points" to a value higher than 0 to enable.
	This amount gets added to the winner and subtracted from
	the loser, as long as the winner/loser is not a current boss.
	
					   OPTIONAL:
	If you want to slay a boss that loses on RPS, set cvar
	"rps4points_slay_boss" to 1. Kill will be credited to
	the RPS winner.
	
	If you want updater support to receive the latest updates
	and have updater installed, set "rps4points_updater" to 1
*/

#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>

#pragma newdecls required

// Version Number
#define MAJOR_REVISION "1"
#define MINOR_REVISION "1"
#define PATCH_REVISION "1"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

public Plugin myinfo = {
	name = "Freak Fortress 2: RPS4Points*",
	author = "SHADoW NiNE TR3S",
	description="Gamble for FF2 queue points using Rock, Paper, Scissors taunt",
	version=PLUGIN_VERSION,
};

int RPSWinner;
bool RPSLoser[MAXPLAYERS+1]=false;
Handle cvarRPSQueuePoints;
Handle cvarKillBoss;

public void OnPluginStart()
{	
	CreateConVar("rps4points_version", PLUGIN_VERSION, "RPS4Points Version", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	cvarKillBoss=CreateConVar("rps4points_slay_boss", "0", "0-Don't slay boss if boss loses on RPS, 1-Slay boss if boss loses on RPS", _, true, 0.0, true, 1.0);
	cvarRPSQueuePoints=CreateConVar("rps4points_points", "10", "Points awarded / removed on RPS result");

	HookEvent("rps_taunt_event", Event_RPSTaunt);

	LoadTranslations("rps4points.phrases");
}

stock bool IsValidClient(int client)
{
	if (client<=0 || client>MaxClients)
		return false;
		
	return IsClientInGame(client);
}

stock bool IsBoss(int client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	return true;
}

public void Event_RPSTaunt(Event event, const char[] name, bool dontBroadcast)
{
	int winner = GetEventInt(event, "winner");
	int loser = GetEventInt(event, "loser");
	
	// Make sure winner or loser are valid
	if(!IsValidClient(winner) || !IsValidClient(loser)) 
	{
		return;
	}

	// If boss slay cvar is enabled, slay boss if they lose on RPS.
	if(!IsBoss(winner) && IsBoss(loser) && GetConVarBool(cvarKillBoss))
	{
		RPSWinner=winner;
		RPSLoser[loser]=true;
		CreateTimer(3.1, DelayRPSDeath, loser);
		return;
	}
	
	// If both parties are non-bosses, they can RPS for queue points
	if(!IsBoss(winner) && !IsBoss(loser) && FF2_GetQueuePoints(loser)>=GetConVarInt(cvarRPSQueuePoints) && GetConVarInt(cvarRPSQueuePoints)>0)
	{		
		CPrintToChat(winner, "{olive}[FF2]{default} %t", "rps_won", GetConVarInt(cvarRPSQueuePoints), loser);
		FF2_SetQueuePoints(winner, FF2_GetQueuePoints(winner)+GetConVarInt(cvarRPSQueuePoints));
	
		CPrintToChat(loser, "{olive}[FF2]{default} %t", "rps_lost", GetConVarInt(cvarRPSQueuePoints), winner);
		FF2_SetQueuePoints(loser, FF2_GetQueuePoints(loser)-GetConVarInt(cvarRPSQueuePoints));
	}
}

public Action DelayRPSDeath(Handle timer, any client)
{
	if(IsValidClient(client))
	{
		int boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			SDKHooks_TakeDamage(client, RPSWinner, RPSWinner, float(FF2_GetBossHealth(boss)), DMG_GENERIC, -1);
		}
	}
}

#file "FF2 Plugin: RPS 4 Points"
