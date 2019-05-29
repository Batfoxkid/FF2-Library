#include <sourcemod>
#include <sdktools>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <tf2_stocks>
#include <sdkhooks>
#include <tf2items>
#include <ff2_ams>
#pragma semicolon 1

#define DAN_REFRESH "dan_remove_statuseffects"
#define DAN_STRENGTH "dan_give_strength"
#define DAN_UBERCHARGE "dan_give_invincibility"

#define MAGICATTACK "special_dan_spells"
new Float:dan_spelldamage;
new Float:dan_spellspeed;

new dan_spellbook = INVALID_ENT_REFERENCE;

#define MODEL_COMBINEBALL				"models/effects/combineball.mdl"
#define PROJECTILE_PARTICLE				"unusual_nether_blue"

new dan_boss;

#define DUM_INSANITY "dum_insanity"
#define INACTIVE 100000000.0
new Float:DumSpeed[MAXPLAYERS+1];
new Float:DumSpeedDuration[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "Freak Fortress 2: Mr. Dan and Dr. Dum",
	author = "M76030",
	description = "Abilities for Mr. Dan and Dr. Dum",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_PostNoCopy);
	
	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy);			// I guess this is for noaml maps?
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy); 
	
	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	
	PrecacheModel(MODEL_COMBINEBALL, true);
	PrecacheModel(PROJECTILE_PARTICLE, true);
}

public void event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	HookAbilities();
}

public void HookAbilities()
{
	for(int clientIdx=1; clientIdx<=MaxClients; clientIdx++)
	{
		if(!IsValidClient(clientIdx))
			continue;
		
		DumSpeed[clientIdx]=0.0;
		DumSpeedDuration[clientIdx]=INACTIVE;
		
		int bossIdx=FF2_GetBossIndex(clientIdx);
		if(bossIdx>=0)
		{
			if(FF2_HasAbility(bossIdx, this_plugin_name, DAN_REFRESH))
			{
				AMS_InitSubability(bossIdx, clientIdx, this_plugin_name, DAN_REFRESH, "DRSE");
			}
			if(FF2_HasAbility(bossIdx, this_plugin_name, DAN_STRENGTH))
			{
				AMS_InitSubability(bossIdx, clientIdx, this_plugin_name, DAN_STRENGTH, "DGS");				
			}
			if(FF2_HasAbility(bossIdx, this_plugin_name, DAN_UBERCHARGE))
			{
				AMS_InitSubability(bossIdx, clientIdx, this_plugin_name, DAN_UBERCHARGE, "DGU");				
			}
			if(FF2_HasAbility(bossIdx, this_plugin_name, DUM_INSANITY))
			{
				AMS_InitSubability(bossIdx, clientIdx, this_plugin_name, DUM_INSANITY, "DUIN");				
			}
		}
	}
}

public Action:FF2_OnAbility2(index,const String:plugin_name[],const String:ability_name[],action)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
}


public bool DRSE_CanInvoke(int clientIdx)
{
	return true;
}

public void DRSE_Invoke(int clientIdx)
{
	int bossIdx=FF2_GetBossIndex(clientIdx);
	float pos[3], pos2[3], dist;
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_dan_refreshments", sound, sizeof(sound), bossIdx))
	{
		EmitSoundToAll(sound, clientIdx);
		EmitSoundToAll(sound, clientIdx);
	}
	
	float dist2=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DAN_REFRESH, 1, FF2_GetRageDist(bossIdx, this_plugin_name, DAN_REFRESH));
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);
	for(int boss=1; boss<=MaxClients; boss++)
	{
		if(IsValidClient(boss) && GetClientTeam(boss) == FF2_GetBossTeam())
		{
			int bossIndex=FF2_GetBossIndex(boss);
			GetEntPropVector(boss, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if(dist<dist2 && bossIndex>=0)
			{
				if(TF2_IsPlayerInCondition(boss, TFCond_Bonked))
				{
					TF2_RemoveCondition(boss, TFCond_Bonked);
				}
				if(TF2_IsPlayerInCondition(boss, TFCond_Dazed))
				{
					TF2_RemoveCondition(boss, TFCond_Dazed);
				}
				if(TF2_IsPlayerInCondition(boss, TFCond_OnFire))
				{
					TF2_RemoveCondition(boss, TFCond_OnFire);
				}
				if(TF2_IsPlayerInCondition(boss, TFCond_Bleeding))
				{
					TF2_RemoveCondition(boss, TFCond_Bleeding);
				}
				if(TF2_IsPlayerInCondition(boss, TFCond_Taunting))
				{
					TF2_RemoveCondition(boss, TFCond_Taunting);
				}
			}
			new health = FF2_GetBossHealth(bossIndex);
			new maxhealth = FF2_GetBossMaxHealth(bossIndex);
			
			health = RoundToCeil(health + (maxhealth * 0.10));
			
			if(health > maxhealth)
			{
				health = maxhealth;
			}
				
			FF2_SetBossHealth(bossIndex, health);
		}
	}
}

public bool DGS_CanInvoke(int clientIdx)
{
	return true;
}

public void DGS_Invoke(int clientIdx)
{
	int bossIdx=FF2_GetBossIndex(clientIdx);
	float pos[3], pos2[3], dist;
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_dan_give_strength", sound, sizeof(sound), bossIdx))
	{
		EmitSoundToAll(sound, clientIdx);
		EmitSoundToAll(sound, clientIdx);
	}
	
	float dist2=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DAN_STRENGTH, 1, FF2_GetRageDist(bossIdx, this_plugin_name, DAN_STRENGTH));
	float duration=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DAN_STRENGTH, 2, 15.0);
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);
	for(int boss=1; boss<=MaxClients; boss++)
	{
		if(IsValidClient(boss) && GetClientTeam(boss) == FF2_GetBossTeam())
		{
			int bossIndex=FF2_GetBossIndex(boss);
			GetEntPropVector(boss, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if(dist<dist2 && bossIndex>0)
			{
				TF2_AddCondition(bossIndex, view_as<TFCond>(28), duration);
				TF2_AddCondition(bossIndex, TFCond_HalloweenCritCandy, duration);
			}
		}
	}
}

public bool DGU_CanInvoke(int clientIdx)
{
	return true;
}

public void DGU_Invoke(int clientIdx)
{
	int bossIdx=FF2_GetBossIndex(clientIdx);
	float pos[3], pos2[3], dist;
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_dan_give_ubercharge", sound, sizeof(sound), bossIdx))
	{
		EmitSoundToAll(sound, clientIdx);
		EmitSoundToAll(sound, clientIdx);
	}
	
	float dist2=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DAN_UBERCHARGE, 1, FF2_GetRageDist(bossIdx, this_plugin_name, DAN_UBERCHARGE));
	float duration=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, DAN_UBERCHARGE, 2, 15.0);
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);
	for(int boss=1; boss<=MaxClients; boss++)
	{
		if(IsValidClient(boss) && GetClientTeam(boss) == FF2_GetBossTeam())
		{
			int bossIndex=FF2_GetBossIndex(boss);
			GetEntPropVector(boss, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if(dist<dist2 && bossIndex>0)
			{
				TF2_AddCondition(bossIndex, TFCond_Ubercharged, duration);
				SetEntProp(bossIndex, Prop_Data, "m_takedamage", 0);
				CreateTimer(duration, StopUber, boss);
				
				TF2_AddCondition(bossIndex, TFCond_UberBulletResist, duration); // Bullet Resistance
				TF2_AddCondition(bossIndex, TFCond_BulletImmune, duration); // Shield portion
				TF2_AddCondition(bossIndex, TFCond_UberBlastResist, duration); //Blast Resistance
				TF2_AddCondition(bossIndex, TFCond_BlastImmune, duration); //Shield Portion
				TF2_AddCondition(bossIndex, TFCond_UberFireResist, duration); //Fire Resistance
				TF2_AddCondition(bossIndex, TFCond_FireImmune, duration); //Shield Portion
				TF2_AddCondition(bossIndex, TFCond_RuneResist, duration);
			}
		}
	}
}

public Action:StopUber(Handle:timer, any:boss)
{
	SetEntProp(GetClientOfUserId(FF2_GetBossUserId(boss)), Prop_Data, "m_takedamage", 2);
	TF2_AddCondition(GetClientOfUserId(FF2_GetBossUserId(boss)), TFCond_UberchargeFading, 3.0);
	return Plugin_Continue;
}


public bool:DUIN_CanInvoke(client)
{
	return true;
}

public DUIN_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:DumNewSpeed[10], String:DumDuration[10]; // Foolproof way so that args always return floats instead of ints
	FF2_GetAbilityArgumentString(boss, this_plugin_name, DUM_INSANITY, 1, DumNewSpeed, sizeof(DumNewSpeed));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, DUM_INSANITY, 2, DumDuration, sizeof(DumDuration));
	
	new Float:duration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, DUM_INSANITY, 3, 15.0);
	
	new String:snd[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_dum_insanity_start", snd, sizeof(snd), boss))
	{
		EmitSoundToAll(snd, client);
		EmitSoundToAll(snd, client);
	}
	
	if(DumNewSpeed[0]!='\0' || DumDuration[0]!='\0')
	{
		if(DumNewSpeed[0]!='\0')
		{
			DumSpeed[client]=StringToFloat(DumNewSpeed); // Boss Move Speed
		}
		if(DumDuration[0]!='\0')
		{
			DumSpeedDuration[client]=GetEngineTime()+StringToFloat(DumDuration); // Boss Move Speed Duration
		}
		
		SDKHook(client, SDKHook_PreThink, Dum_Prethink);
	}
	
	TF2_AddCondition(client, TFCond_RuneHaste, duration);
	TF2_AddCondition(client, TFCond_RegenBuffed, duration);
}

public Dum_Prethink(client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", DumSpeed[client]);
	DumInsanity(client, GetEngineTime());
}

public DumInsanity(client, Float:gameTime)
{
	// Move Speed
	if(gameTime>=DumSpeedDuration[client])
	{
		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			new String:snd[PLATFORM_MAX_PATH];
			if(FF2_RandomSound("sound_dum_insanity_end", snd, sizeof(snd), boss))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
	
		DumSpeed[client]=0.0;
		DumSpeedDuration[client]=INACTIVE;
		SDKUnhook(client, SDKHook_PreThink, Dum_Prethink);
	}
}

public event_round_active(Handle:event, const String:name[], bool:dontBroadcast)
{
	dan_boss = 0;

	if(FF2_HasAbility( 0, this_plugin_name, MAGICATTACK ))
	{
		new userid = FF2_GetBossUserId(0);
		new client = GetClientOfUserId(userid);
		if(client && IsClientInGame(client) && IsPlayerAlive(client))
		{
			dan_boss = client;
			
			dan_spellspeed = FF2_GetAbilityArgumentFloat(0, this_plugin_name, MAGICATTACK, 1, 600.0);
			dan_spelldamage = FF2_GetAbilityArgumentFloat(0, this_plugin_name, MAGICATTACK, 2, 40.0);
			
			CreateTimer(3.0, Timer_DanSpellsBook, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Timer_DanSpellsBook(Handle:timer, any:userid)					// Updates boss rage stuffs
{
	new boss = GetClientOfUserId(userid);
	if(boss && boss == dan_boss && IsClientInGame(boss) && FF2_GetBossIndex(boss) != -1)
	{
		new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
		if (hWeapon != INVALID_HANDLE)
		{
			TF2Items_SetClassname(hWeapon, "tf_weapon_spellbook");
			TF2Items_SetItemIndex(hWeapon, 1070);
			TF2Items_SetLevel(hWeapon, 1);
			TF2Items_SetQuality(hWeapon, 5);
			TF2Items_SetAttribute(hWeapon, 0, 68, 2.0);
			TF2Items_SetAttribute(hWeapon, 1, 2025, 3.0);
			TF2Items_SetAttribute(hWeapon, 2, 2013, 2003.0);
			TF2Items_SetAttribute(hWeapon, 3, 2014, 7.0);
			TF2Items_SetAttribute(hWeapon, 4, 326, 1.75);
			TF2Items_SetNumAttributes(hWeapon, 5);

			new weapon = TF2Items_GiveNamedItem(boss, hWeapon);
			CloseHandle(hWeapon);
			
			if(IsValidEntity(weapon))
			{
				EquipPlayerWeapon(boss, weapon);
				TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Melee);

				SetEntPropEnt(boss, Prop_Send, "m_hActiveWeapon", weapon);
				SetEntPropEnt(boss, Prop_Send, "m_hLastWeapon", weapon);
				SetEntProp(weapon, Prop_Send, "m_iSelectedSpellIndex", 0);	   // load the spellbook with teleport
				SetEntProp(weapon, Prop_Send, "m_iSpellCharges", 1337);
				
				dan_spellbook = EntIndexToEntRef(weapon);
			}
		}
	}
}

public event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			SDKUnhook(client, SDKHook_PreThink, Dum_Prethink);
			DumSpeed[client]=0.0;
			DumSpeedDuration[client]=INACTIVE;
		}
	}
	
	dan_boss = 0;
	
	new weapon = EntRefToEntIndex(dan_spellbook);
	if(weapon != INVALID_ENT_REFERENCE)
	{
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 30.0);
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, "tf_projectile_spellfireball"))
	{
		SDKHook(entity, SDKHook_Spawn, CheckSpellSpawn);
	}
}

public Action:CheckSpellSpawn(entity)
{
	if(dan_boss == GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") && dan_boss > 0 && IsClientInGame(dan_boss))
	{
		CreateFireball(dan_boss);
		
		AcceptEntityInput(entity, "Kill");
	}

	SDKUnhook(entity, SDKHook_Spawn, CheckSpellSpawn);
}

/////////////////////////////////////////////////////

CreateFireball(client)
{
	decl Float:position[3];
	decl Float:rot[3];
	decl Float:velocity[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);
	GetClientEyeAngles(client,rot);
	position[2]+=63;
				
	new proj=CreateEntityByName("tf_projectile_rocket");
	SetVariantInt(FF2_GetBossTeam());
	AcceptEntityInput(proj, "TeamNum", -1, -1, 0);
	SetVariantInt(FF2_GetBossTeam());
	AcceptEntityInput(proj, "SetTeam", -1, -1, 0); 
	SetEntPropEnt(proj, Prop_Send, "m_hOwnerEntity",client);		
	velocity[0]=Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*dan_spellspeed;
	velocity[1]=Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*dan_spellspeed;
	velocity[2]=Sine(DegToRad(rot[0]))*dan_spellspeed;
	velocity[2]*=-1;
	TeleportEntity(proj, position, rot,velocity);
	SetEntDataFloat(proj, FindSendPropOffs("CTFProjectile_Rocket", "m_iDeflected") + 4, dan_spelldamage, true);
	DispatchSpawn(proj);
	SetEntityModel(proj,MODEL_COMBINEBALL);
	CreateTimer(15.0, RemoveEntity, EntIndexToEntRef(AttachParticle(proj, PROJECTILE_PARTICLE,_,true)));
}

stock AttachParticle(entity, String:particleType[], Float:offset[]={0.0,0.0,0.0}, bool:attach=true)
{
	new particle=CreateEntityByName("info_particle_system");

	decl String:targetName[128];
	decl Float:position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[0]+=offset[0];
	position[1]+=offset[1];
	position[2]+=offset[2];
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if(attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	return particle;
}

public Action:RemoveEntity(Handle:timer, any:entid)
{
	new entity=EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

/////////////////////////////////////////////////////

stock bool IsValidClient(int iClient, bool bAlive = false, bool bTeam = false)
{
	if(iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;

	if(IsClientSourceTV(iClient) || IsClientReplay(iClient))
		return false;
	
	if(bAlive && !IsPlayerAlive(iClient))
		return false;
	
	if(bTeam && GetClientTeam(iClient) != FF2_GetBossTeam())
		return false;

	return true;
}