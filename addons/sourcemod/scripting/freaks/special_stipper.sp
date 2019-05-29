#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define INACTIVE 100000000.0
#define SEXINESS "rage_staring_at_sexiness"
#define SEXINESSALIAS "SEXI"
new bool:Sexiness_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Rage_Outline)
new Float:SexiRageTime;
new Float:SexinessSpeed[MAXPLAYERS+1];

public Plugin:myinfo = {
	name	= "Freak Fortress 2: Ability for Sexy Hoovy",
	author	= "M7",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
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
			Sexiness_TriggerAMS[client] = false;
			SexinessSpeed[client]=0.0;
			
			new boss=FF2_GetBossIndex(client);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, this_plugin_name, SEXINESS))
				{
					Sexiness_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, SEXINESS);
					if(Sexiness_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, SEXINESS, SEXINESSALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
			}
		}
	}
}

public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			Sexiness_TriggerAMS[client] = false;
			SDKUnhook(client, SDKHook_PreThinkPost, SexiThink);
		}
	}
}

public Action:FF2_OnAbility2(boss, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name,SEXINESS))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Sexiness_TriggerAMS[client]=false;
		}
		
		if(!Sexiness_TriggerAMS[client])
			SEXI_Invoke(client);
	}
	return Plugin_Continue;
}

public bool:SEXI_CanInvoke(client)
{
	return true;
}

public SEXI_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	new Float:dist2 = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, SEXINESS, 1);
	decl String:SexiSpeed[10]; // Foolproof way so that args always return floats instead of ints
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SEXINESS, 3, SexiSpeed, sizeof(SexiSpeed));
	
	if(Sexiness_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_time_to_stare", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);	
		}
	}
	
	new Float:pos[3], Float:pos2[3], Float:dist;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsValidLivingPlayer(i) && GetClientTeam(i)!=FF2_GetBossTeam())
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
			dist = GetVectorDistance(pos, pos2);
			if (!TF2_IsPlayerInCondition(i, TFCond_Ubercharged) && dist <= dist2 && GetClientTeam(i)!=FF2_GetBossTeam())
			{
				TF2_RemoveAllWeapons(i);
				SpawnWeapon(i, "tf_weapon_shovel", 5, 100, 5, "1 ; 0.0 ; 259 ; 1.0 ; 5 ; 9999");
			
				CreateTimer(0.1, Timer_NoAttacking, i);
				
				CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, SEXINESS, 2), RefreshPlayer, i);
				
				SexiRageTime = GetEngineTime() + FF2_GetAbilityArgumentFloat(boss, this_plugin_name, SEXINESS, 2);
				SDKHook(i, SDKHook_PreThinkPost, SexiThink);
				
				SexinessSpeed[i]=StringToFloat(SexiSpeed); // Victim Move Speed
			}
		}
	}
}

public void SexiThink(iClient)
{
	int iClosest = GetClosestBoss(iClient);
	if(!IsValidClient(iClosest))
		return;
		
	SetEntPropFloat(iClient, Prop_Send, "m_flMaxspeed", SexinessSpeed[iClient]);

	float flClosestLocation[3], flClientEyePosition[3], flVector[3], flCamAngle[3];
	GetClientEyePosition(iClient, flClientEyePosition);
	
	GetClientEyePosition(iClosest, flClosestLocation);
	flClosestLocation[2] -= 2.0;

	MakeVectorFromPoints(flClosestLocation, flClientEyePosition, flVector);
	GetVectorAngles(flVector, flCamAngle);
	flCamAngle[0] *= -1.0;
	flCamAngle[1] += 180.0;

	ClampAngle(flCamAngle);
	TeleportEntity(iClient, NULL_VECTOR, flCamAngle, NULL_VECTOR);
	
	if(GetEngineTime() >= SexiRageTime || FF2_GetRoundState() != 1)
	{
		SexinessSpeed[iClient]=0.0;
		SDKUnhook(iClient, SDKHook_PreThinkPost, SexiThink);
	}
}

public Action:Timer_NoAttacking(Handle:timer, any:i)
{
	new weapon=GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
	if(weapon && IsValidEdict(weapon))
	{
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+FF2_GetAbilityArgumentFloat(0, this_plugin_name, "rage_staring_at_sexiness", 2));
	}
	SetEntPropFloat(i, Prop_Send, "m_flNextAttack", GetGameTime()+FF2_GetAbilityArgumentFloat(0, this_plugin_name, "rage_staring_at_sexiness", 2));
	SetEntPropFloat(i, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+FF2_GetAbilityArgumentFloat(0, this_plugin_name, "rage_staring_at_sexiness", 2));
	return Plugin_Continue;
}

public Action:RefreshPlayer(Handle:timer, any:i)
{
	if(!IsValidLivingPlayer(i))
		return Plugin_Stop;
	TF2_RegeneratePlayer(i);
	return Plugin_Continue;
}

stock bool:IsValidLivingPlayer(client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client) && IsPlayerAlive(client);
}

stock SpawnWeapon(client,String:name[],index,level,qual,String:att[])
{
	new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	new String:atts[32][32];
	new count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		new i2 = 0;
		for (new i = 0; i < count; i+=2)
		{
		 TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
		 i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==INVALID_HANDLE)
		return -1;
	new entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

stock int GetClosestBoss(int iClient)
{
	float fClientLocation[3], fEntityOrigin[3];
	GetClientAbsOrigin(iClient, fClientLocation);

	int iClosestEntity = -1;
	float fClosestDistance = -1.0;
	for(int i = 1; i < MaxClients; i++) if(IsValidClient(i))
	{
		if(GetClientTeam(i) != GetClientTeam(iClient) && IsPlayerAlive(i) && i != iClient)
		{
			GetClientAbsOrigin(i, fEntityOrigin);
			float fEntityDistance = GetVectorDistance(fClientLocation, fEntityOrigin);
			if((fEntityDistance < fClosestDistance) || fClosestDistance == -1.0)
			{
				fClosestDistance = fEntityDistance;
				iClosestEntity = i;
			}
		}
	}
	return iClosestEntity;
}

stock void ClampAngle(float flAngles[3])
{
	while(flAngles[0] > 89.0)  flAngles[0]-=360.0;
	while(flAngles[0] < -89.0) flAngles[0]+=360.0;
	while(flAngles[1] > 180.0) flAngles[1]-=360.0;
	while(flAngles[1] <-180.0) flAngles[1]+=360.0;
}