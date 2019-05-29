#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define PLUGIN_VERSION "1.2"

new Handle:cvarEnable;
new maxClimbs[MAXPLAYERS+1] = {0, ...};
new bool:isClientBoss[MAXPLAYERS+1] = {false, ...};
new bool:hasAbility[MAXPLAYERS+1] = {false, ...};
new bool:justClimbed[MAXPLAYERS+1] = {false, ...};
new bool:blockClimb[MAXPLAYERS+1] = {false, ...};

public Plugin:myinfo = {
	name		= "Freak Fortress 2: Player Climb",
	author		= "Nanochip",
	description = "Climb walls with melee attack AS A ~BOSS~.",
	version		= PLUGIN_VERSION,
	url			= "http://thecubeserver.org/"
};

public OnPluginStart2()
{
	CreateConVar("sm_playerclimb_ff2_version", PLUGIN_VERSION, "Freak Fortress 2: Player Climb", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvarEnable = CreateConVar("sm_playerclimb_ff2_enable", "1", "Enable the plugin? 1 = Yes, 0 = No.", FCVAR_NOTIFY);
	
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("arena_win_panel", Event_RoundEnd);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		new boss = FF2_GetBossIndex(i);
		if (IsValidClient(i) && FF2_IsFF2Enabled() && boss != -1)
		{
			isClientBoss[i] = true;
			if (FF2_HasAbility(boss, this_plugin_name, "playerclimb"))
			{
				hasAbility[i] = true;
			}
		}
	}
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		hasAbility[i] = false;
		isClientBoss[i] = false;
	}
}

public OnClientDisconnect(client)
{
	hasAbility[client] = false;
	isClientBoss[client] = false;
	justClimbed[client] = false;
	blockClimb[client] = false;
	maxClimbs[client] = 0;
}

public Action:TF2_CalcIsAttackCritical(client, weapon, String:weaponname[], &bool:result)
{
	if (!GetConVarBool(cvarEnable) || !IsValidClient(client) || !FF2_IsFF2Enabled() || !isClientBoss[client] || !hasAbility[client]) return Plugin_Continue;
	
	if (IsValidEntity(weapon) && weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee)) SickleClimbWalls(client, weapon);
	
	return Plugin_Continue;
}

public Timer_NoAttacking(any:ref)
{
	new weapon = EntRefToEntIndex(ref);
	new boss;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (FF2_GetBossIndex(i) != -1) boss = FF2_GetBossIndex(i);
	}
	SetNextAttack(weapon, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "playerclimb", 1, 0.0));
}

public OnGameFrame()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && isClientBoss[i] && (GetEntityFlags(i) & FL_ONGROUND))
		{
			maxClimbs[i] = 0;
			new boss = FF2_GetBossIndex(i);
			new Float:cooldownTime = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "playerclimb", 3, 0.0);
			if (justClimbed[i] && cooldownTime != 0.0)
			{
				justClimbed[i] = false;
				blockClimb[i] = true;
				CreateTimer(cooldownTime, Timer_ClimbCooldown, i, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public Action:Timer_ClimbCooldown(Handle:timer, any:client)
{
	blockClimb[client] = false;
}

SickleClimbWalls(client, weapon)	 //Credit to Mecha the Slag
{
	if (!GetConVarBool(cvarEnable) || !IsValidClient(client)) return;
	
	decl String:classname[64];
	decl Float:vecClientEyePos[3];
	decl Float:vecClientEyeAng[3];
	GetClientEyePosition(client, vecClientEyePos);	 // Get the position of the player's eyes
	GetClientEyeAngles(client, vecClientEyeAng);	   // Get the angle the player is looking
	
	//Check for colliding entities
	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
	
	if (!TR_DidHit(INVALID_HANDLE)) return;
	
	new TRIndex = TR_GetEntityIndex(INVALID_HANDLE);
	GetEdictClassname(TRIndex, classname, sizeof(classname));
	if (!((StrStarts(classname, "prop_") && classname[5] != 'p') || StrEqual(classname, "worldspawn"))) return; 
	
	decl Float:fNormal[3];
	TR_GetPlaneNormal(INVALID_HANDLE, fNormal);
	GetVectorAngles(fNormal, fNormal);
	
	if (fNormal[0] >= 30.0 && fNormal[0] <= 330.0) return;
	if (fNormal[0] <= -30.0) return;
	
	decl Float:pos[3];
	TR_GetEndPosition(pos);
	new Float:distance = GetVectorDistance(vecClientEyePos, pos);
	
	if (distance >= 100.0) return;
	
	if (blockClimb[client])
	{
		PrintToChat(client, "[SM] Climbing is currently on cool-down, please wait.");
		return;
	}
	
	new maxNumClimbs = FF2_GetAbilityArgument(FF2_GetBossIndex(client), this_plugin_name, "playerclimb", 2, 0);
	
	if (maxNumClimbs != 0 && maxClimbs[client] >= maxNumClimbs && !(GetEntityFlags(client) & FL_ONGROUND))
	{
		PrintToChat(client, "[SM] You need to touch the ground before you can climb again.");
		return;
	}
	
	new Float:fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	
	fVelocity[2] = 600.0;
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
	
	ClientCommand(client, "playgamesound \"%s\"", "player\\taunt_clip_spin.wav");
	
	RequestFrame(Timer_NoAttacking, EntIndexToEntRef(weapon));
	maxClimbs[client]++;
	justClimbed[client] = true;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	return (entity != data);
}

stock SetNextAttack(weapon, Float:duration = 0.0)
{
	if (weapon <= MaxClients || !IsValidEntity(weapon)) return;
	new Float:next = GetGameTime() + duration;
	SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", next);
	SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", next);
}

stock bool:IsValidClient(iClient)
{
	return (0 < iClient && iClient <= MaxClients && IsClientInGame(iClient));
}

stock bool:StrStarts(const String:szStr[], const String:szSubStr[], bool:bCaseSensitive = true) 
{ 
	return !StrContains(szStr, szSubStr, bCaseSensitive); 
} 