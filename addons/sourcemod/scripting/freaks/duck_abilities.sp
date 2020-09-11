#include <sourcemod> 
#include <sdkhooks>  
#include <tf2_stocks> 
#include <freak_fortress_2>  
#include <freak_fortress_2_subplugin> 
#include <tf2_stocks>  

#pragma semicolon 1
#pragma newdecls required

#define BOSS_DUCKPYRO_KEY "special_duckpyro"

#define MODEL_DUCK		"models/workshop/player/items/pyro/eotl_ducky/eotl_bonus_duck.mdl"
#define DUCK_SCALE		1.0
#define SOUND_DUCKED	"misc/halloween/merasmus_spell.wav"

float gf_DiedDuckPyro[MAXPLAYERS + 1];
float gf_DiedDuckStomp[MAXPLAYERS + 1];

float gf_duckpyro_zapangle;
float gf_duckpyro_zapdistance;
float gf_duckpyro_zapdamage;
float gf_duckpyro_ducktime;
int g_duckpyro_duckmax;

int g_duck_entref[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };

int g_boss;
int g_bossteam;

public Action FF2_OnAbility2(int index, const char[] plugin_name, const char[] ability_name, int action)
{
	if (!strcmp(ability_name, BOSS_DUCKPYRO_KEY))
	{
		DoDuckPyroRage(GetClientOfUserId(FF2_GetBossUserId(index)));
	}
}

void OnPluginStart2()
{
	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy); // I guess this is for noaml maps?
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy);
	HookEvent("player_death", event_player_death, EventHookMode_Pre);
	HookEvent("teamplay_round_win", event_end, EventHookMode_PostNoCopy);
}

public Action event_player_death(Handle hEvent, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (client > 0 && client <= MaxClients)
	{
		if (client == g_boss)
		{
			int prop = CreateEntityByName("prop_physics_override");
			if (prop != -1)
			{
				RemoveRagdoll(client);
				
				float pos[3], ang[3];
				
				GetClientAbsOrigin(client, pos);
				GetClientAbsAngles(client, ang);
				
				DispatchKeyValueVector(prop, "origin", pos);
				DispatchKeyValueVector(prop, "angles", ang);
				DispatchKeyValue(prop, "model", MODEL_DUCK);
				DispatchKeyValue(prop, "disableshadows", "1");
				
				DispatchKeyValue(prop, "skin", "21");
				
				SetEntProp(prop, Prop_Send, "m_CollisionGroup", 1);
				SetEntProp(prop, Prop_Send, "m_usSolidFlags", 16);
				
				DispatchSpawn(prop);
				
				ActivateEntity(prop);
				AcceptEntityInput(prop, "EnableMotion");
				
				SetEntPropFloat(prop, Prop_Send, "m_flModelScale", DUCK_SCALE);
			}
			
			g_boss = 0;
		}
		else
		{
			float time = GetEngineTime();
			if (gf_DiedDuckPyro[client] > time)
			{
				SetEventString(hEvent, "weapon_logclassname", "Duck Doom");
				SetEventString(hEvent, "weapon", "merasmus_zap");
			}
			else if (gf_DiedDuckStomp[client] > time)
			{
				SetEventString(hEvent, "weapon_logclassname", "Duck Stomp");
				SetEventString(hEvent, "weapon", "mantreads");
			}
			
			int duck = EntRefToEntIndex(g_duck_entref[client]);
			if (duck != INVALID_ENT_REFERENCE)
			{
				RemoveRagdoll(client);
				AcceptEntityInput(duck, "Kill");
			}
		}
	}
}

public void event_end(Handle event, char[] name, bool dontBroadcast)
{
	g_boss = 0;
}

public void event_round_active(Handle event, char[] name, bool dontBroadcast)
{
	g_boss = 0;
	
	int userid = FF2_GetBossUserId(0);
	if (userid > 0)
	{
		int client = GetClientOfUserId(userid);
		if (client && IsClientInGame(client) && IsPlayerAlive(client))
		{
			if (FF2_HasAbility(0, this_plugin_name, BOSS_DUCKPYRO_KEY))
			{
				PrecacheModel(MODEL_DUCK);
				PrecacheSound(SOUND_DUCKED);
				
				gf_duckpyro_zapangle = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_DUCKPYRO_KEY, 1, 25.0);
				gf_duckpyro_zapdistance = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_DUCKPYRO_KEY, 2, 1000.0);
				gf_duckpyro_zapdistance *= gf_duckpyro_zapdistance;
				gf_duckpyro_zapdamage = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_DUCKPYRO_KEY, 3, 10.0);
				gf_duckpyro_ducktime = FF2_GetAbilityArgumentFloat(0, this_plugin_name, BOSS_DUCKPYRO_KEY, 4, 5.0);
				
				g_duckpyro_duckmax = FF2_GetAbilityArgument(0, this_plugin_name, BOSS_DUCKPYRO_KEY, 5, 32);
				
				g_boss = client;
				g_bossteam = FF2_GetBossTeam();
				
				SDKHook(g_boss, SDKHook_Touch, DuckPyro_HookTouch);
			}
		}
	}
}

public void DuckPyro_HookTouch(int boss, int entity)
{
	if (boss != g_boss)
	{
		SDKUnhook(boss, SDKHook_Touch, DuckPyro_HookTouch);
		return;
	}
	if (entity > 0 && entity <= MaxClients && IsPlayerAlive(entity))
	{
		if (EntRefToEntIndex(g_duck_entref[entity]) != INVALID_ENT_REFERENCE)
		{
			gf_DiedDuckStomp[entity] = GetEngineTime() + 0.1;
			SDKHooks_TakeDamage(entity, boss, boss, 9999.0);
		}
	}
}

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////  active
void DoDuckPyroRage(int boss)
{
	float time = GetEngineTime() + 0.1;
	
	float bosspos[3], targetpos[3], ang[3], rt[3], up[3], targetvector[3];
	
	int playerarray[MAXPLAYERS + 1];
	int players;
	
	GetClientEyePosition(boss, bosspos);
	GetClientAbsAngles(boss, ang);
	GetAngleVectors(ang, ang, rt, up);
	
	bosspos[0] += rt[0] * 30.0 - up[0] * 35.0;
	bosspos[1] += rt[1] * 30.0 - up[1] * 35.0;
	bosspos[2] += rt[2] * 30.0 - up[2] * 35.0;
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (IsClientInGame(player) && IsPlayerAlive(player) && GetClientTeam(player) != g_bossteam)
		{
			GetClientAbsOrigin(player, targetpos);
			targetpos[2] += 40.0;
			if (GetVectorDistance(bosspos, targetpos, true) < gf_duckpyro_zapdistance && DuckPyro_CanSeeTarget(bosspos, targetpos, player))
			{
				MakeVectorFromPoints(bosspos, targetpos, targetvector);
				NormalizeVector(targetvector, targetvector);
				
				if (RadToDeg(ArcCosine(GetVectorDotProduct(targetvector, ang))) < gf_duckpyro_zapangle)
				{
					playerarray[players] = player;
					players++;
				}
			}
		}
	}
	
	array_shuffle(playerarray, players);
	
	for (int i; i < players; i++)
	{
		if (i >= g_duckpyro_duckmax)
		{
			break;
		}
		gf_DiedDuckPyro[playerarray[i]] = time;
		SDKHooks_TakeDamage(playerarray[i], boss, boss, gf_duckpyro_zapdamage, DMG_SHOCK);
		
		targetpos[2] -= 20.0;
		TE_Particle("merasmus_zap", bosspos, targetpos, NULL_VECTOR, 
			_,  // entity to attach to
			_,  // start_at_origin(1), start_at_attachment(2), follow_origin(3), follow_attachment(4)
			_,  // attachment point index on entity
			true, 
			0,  // probably 0/1/2
			NULL_VECTOR,  // rgb colors?
			NULL_VECTOR,  // rgb colors?
			0,  // second entity to attach to
			1,  // attach type
			NULL_VECTOR,  // offset to maintain
			GetRandomFloat(0.0, 0.25));
		
		int duck = EntRefToEntIndex(g_duck_entref[playerarray[i]]);
		if (duck == INVALID_ENT_REFERENCE)
		{
			CreateTimer(0.1, Timer_Duckify, GetClientUserId(playerarray[i]), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action Timer_Duckify(Handle timer, any userid)
{
	if (g_boss && IsClientInGame(g_boss))
	{
		int client = GetClientOfUserId(userid);
		if (client && IsClientInGame(client) && IsPlayerAlive(client))
		{
			if (GetEntityFlags(client) & FL_ONGROUND)
			{
				CreateTimer(gf_duckpyro_ducktime, Timer_UnDuckify, userid, TIMER_FLAG_NO_MAPCHANGE);
				
				TF2_StunPlayer(client, gf_duckpyro_ducktime, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT | TF_STUNFLAG_THIRDPERSON);
				TF2_AddCondition(client, TFCond_StealthedUserBuffFade, gf_duckpyro_ducktime);
				SetItemVisibility(client, RENDER_NONE);
				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				SetEntityRenderColor(client, 255, 255, 255, 0);
				SetEntityMoveType(client, MOVETYPE_NONE);
				
				int prop = EntRefToEntIndex(g_duck_entref[client]);
				if (prop != INVALID_ENT_REFERENCE)
				{
					AcceptEntityInput(prop, "Kill");
				}
				
				float pos[3], ang[3];
				GetClientAbsOrigin(client, pos);
				GetClientAbsAngles(client, ang);
				
				EmitAmbientSound(SOUND_DUCKED, pos);
				
				pos[2] -= 5.0;
				
				prop = CreateEntityByName("prop_physics_override");
				if (prop != -1)
				{
					DispatchKeyValueVector(prop, "origin", pos);
					DispatchKeyValueVector(prop, "angles", ang);
					DispatchKeyValue(prop, "model", MODEL_DUCK);
					DispatchKeyValue(prop, "disableshadows", "1");
					
					char skin[3];
					IntToString(2 + view_as<int>(TF2_GetPlayerClass(client)), skin, sizeof(skin));
					DispatchKeyValue(prop, "skin", skin);
					
					SetEntProp(prop, Prop_Send, "m_CollisionGroup", 1);
					SetEntProp(prop, Prop_Send, "m_usSolidFlags", 16);
					
					DispatchSpawn(prop);
					
					ActivateEntity(prop);
					AcceptEntityInput(prop, "DisableMotion");
					
					SetEntPropFloat(prop, Prop_Send, "m_flModelScale", DUCK_SCALE);
					
					g_duck_entref[client] = EntIndexToEntRef(prop);
				}
				
				int ent = CreateEntityByName("info_particle_system");
				if (ent != -1)
				{
					DispatchKeyValueVector(ent, "origin", pos);
					DispatchKeyValue(ent, "effect_name", "ghost_appearation");
					DispatchSpawn(ent);
					
					ActivateEntity(ent);
					AcceptEntityInput(ent, "Start");
					
					CreateTimer(2.0, Timer_RemoveEntity, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
				}
				ent = CreateEntityByName("info_particle_system");
				if (ent != -1)
				{
					pos[2] += 5.0;
					
					DispatchKeyValueVector(ent, "origin", pos);
					DispatchKeyValue(ent, "effect_name", "unusual_spellbook_circle_purple");
					DispatchSpawn(ent);
					
					ActivateEntity(ent);
					AcceptEntityInput(ent, "Start");
					
					SetVariantString("!activator");
					AcceptEntityInput(ent, "SetParent", prop);
					
					AcceptEntityInput(ent, "SetParentAttachment");
					
					CreateTimer(gf_duckpyro_ducktime * 2.0, Timer_RemoveEntity, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
				}
				
				return Plugin_Stop;
			}
			return Plugin_Continue;
		}
	}
	
	return Plugin_Stop;
}

public Action Timer_UnDuckify(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client))
	{
		SetEntityRenderColor(client, 255, 255, 255, 255);
		SetItemVisibility(client, RENDER_NORMAL);
		
		if (IsPlayerAlive(client))
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
			
			int prop = EntRefToEntIndex(g_duck_entref[client]);
			if (prop != INVALID_ENT_REFERENCE)
			{
				AcceptEntityInput(prop, "Kill");
			}
			
			int ent = CreateEntityByName("info_particle_system");
			if (ent != -1)
			{
				float pos[3];
				GetClientAbsOrigin(client, pos);
				pos[2] += 40.0;
				EmitAmbientSound(SOUND_DUCKED, pos);
				
				DispatchKeyValueVector(ent, "origin", pos);
				DispatchKeyValue(ent, "effect_name", "ghost_appearation");
				DispatchSpawn(ent);
				
				ActivateEntity(ent);
				AcceptEntityInput(ent, "Start");
				
				CreateTimer(2.0, Timer_RemoveEntity, EntIndexToEntRef(ent), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

bool DuckPyro_CanSeeTarget(float startpos[3], float targetpos[3], int target)
{
	TR_TraceRayFilter(startpos, targetpos, MASK_SHOT, RayType_EndPoint, DuckPyro__TraceRayFilterClients, target);
	return (TR_GetEntityIndex() == target);
}

public bool DuckPyro__TraceRayFilterClients(int entity, int mask, any target)
{
	return (entity == target);
}

/////////////// stock stuff copypasted to make this one file

void array_shuffle(int[] array, int count)
{
	if (count > 1)
	{
		int temp;
		for (int i; i < count; i++)
		{
			int target = GetRandomInt(0, count - 1);
			temp = array[i];
			array[i] = array[target];
			array[target] = temp;
		}
	}
}

stock void RemoveRagdoll(int client)
{
	RequestFrame(Frame_RemoveRagdoll, GetClientUserId(client));
}

public void Frame_RemoveRagdoll(any userid)
{
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client))
	{
		int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		if (ragdoll > MaxClients)
		{
			AcceptEntityInput(ragdoll, "Kill");
		}
	}
}

stock void TE_Particle(char[] Name, float origin[3] = NULL_VECTOR, float start[3] = NULL_VECTOR, float angles[3] = NULL_VECTOR, 
	int entindex = -1,  // entity to attach to
	int attachtype = -1,  // start_at_origin(1), start_at_attachment(2), follow_origin(3), follow_attachment(4)
	int attachpoint = -1,  // attachment point index on entity
	bool resetParticles = true, 
	int customcolors = 0,  // probably 0/1/2
	float color1[3] = NULL_VECTOR,  // rgb colors?
	float color2[3] = NULL_VECTOR,  // rgb colors?
	int controlpoint = -1,  // second entity to attach to
	int controlpointattachment = -1,  // attach type
	float controlpointoffset[3] = NULL_VECTOR,  // offset to maintain
	float delay = 0.0)
{
	// find string table
	int tblidx = FindStringTable("ParticleEffectNames");
	if (tblidx == INVALID_STRING_TABLE)
	{
		LogError("Could not find string table: ParticleEffectNames");
		return;
	}
	
	// find particle index
	char tmp[256];
	int count = GetStringTableNumStrings(tblidx);
	int stridx = INVALID_STRING_INDEX;
	for (int i; i < count; i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if (StrEqual(tmp, Name, false))
		{
			stridx = i;
			break;
		}
	}
	if (stridx == INVALID_STRING_INDEX)
	{
		LogError("Could not find particle: %s", Name);
		return;
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteFloat("m_vecStart[0]", start[0]);
	TE_WriteFloat("m_vecStart[1]", start[1]);
	TE_WriteFloat("m_vecStart[2]", start[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	if (entindex != -1)
	{
		TE_WriteNum("entindex", entindex);
	}
	if (attachtype != -1)
	{
		TE_WriteNum("m_iAttachType", attachtype);
	}
	if (attachpoint != -1)
	{
		TE_WriteNum("m_iAttachmentPointIndex", attachpoint);
	}
	TE_WriteNum("m_bResetParticles", resetParticles ? 1:0);
	
	if (customcolors)
	{
		TE_WriteNum("m_bCustomColors", customcolors);
		TE_WriteVector("m_CustomColors.m_vecColor1", color1);
		if (customcolors == 2)
		{
			TE_WriteVector("m_CustomColors.m_vecColor2", color2);
		}
	}
	if (controlpoint != -1)
	{
		TE_WriteNum("m_bControlPoint1", controlpoint);
		if (controlpointattachment != -1)
		{
			TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", controlpointattachment);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", controlpointoffset[0]);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", controlpointoffset[1]);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", controlpointoffset[2]);
		}
	}
	
	TE_SendToAll(delay);
}

stock void SetItemVisibility(int client, RenderMode rmode)
{
	int ent = MaxClients + 1;
	while ((ent = FindEntityByClassname2(ent, "tf_wearable")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
		{
			SetEntityRenderMode(ent, rmode);
		}
	}
	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname2(ent, "tf_powerup_bottle")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
		{
			SetEntityRenderMode(ent, rmode);
		}
	}
	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname2(ent, "tf_weapon_spellbook")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(ent, Prop_Send, "m_bDisguiseWeapon"))
		{
			int ew = GetEntPropEnt(ent, Prop_Send, "m_hExtraWearable");
			if (IsValidEntity(ew))
			{
				SetEntityRenderMode(ew, rmode);
			}
		}
	}
	ent = MaxClients + 1;
	while ((ent = FindEntityByClassname2(ent, "tf_wearable_demoshield")) != -1)
	{
		if (GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client && !GetEntProp(ent, Prop_Send, "m_bDisguiseWearable"))
		{
			SetEntityRenderMode(ent, rmode);
		}
	}
}

public Action Timer_RemoveEntity(Handle timer, any ref)
{
	int ent = EntRefToEntIndex(ref);
	if (ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Kill");
	}
}

stock int FindEntityByClassname2(int iStart, char[] strClassname)
{
	while (iStart > -1 && !IsValidEntity(iStart))iStart--;
	return FindEntityByClassname(iStart, strClassname);
} 