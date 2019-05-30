#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <freak_fortress_2_extras>

#define INACTIVE 100000000.0

// Copycat (Boss disguises as the closest RED player)
#define COPYCAT "rage_copycat"
bool CopyCat_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

// Skill Steal (Depending on the class nearest to him, boss gets a different ability)
#define SKILLSTEAL "rage_skill_steal"
float SpeedSteal[MAXPLAYERS+1];
float SpeedStealDuration[MAXPLAYERS+1];
int Rockets[MAXPLAYERS+1];
int RocketsButton[MAXPLAYERS+1];
int Fire[MAXPLAYERS+1];
int ShieldCharges[MAXPLAYERS+1];
int ShieldChargesButton[MAXPLAYERS+1];
float ShieldChargesSpeed[MAXPLAYERS+1]; // Addition in the 2.0 edition (make sure that he is actually fast, when charging)
float StrengthDuration[MAXPLAYERS+1];
int MetalSteal[MAXPLAYERS+1]; // Addition in the 2.0 edition (Give him metal to build stuff)
float HealthGained[MAXPLAYERS+1];
float JarateDuration[MAXPLAYERS+1];
float InvisibilityDuration[MAXPLAYERS+1];
bool SkillSteal_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

public Plugin myinfo = {
	name	= "Freak Fortress 2: Abilities for Double",
	author	= "M7",
	version = "2.1",
};

public void OnPluginStart2()
{
	HookEvent("teamplay_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", event_player_hurt);
}

public Action event_round_start(Handle event, const char[] name, bool dontBroadcast)
{
	PrepareAbilities();
}

public void PrepareAbilities()
{
	for(int clientIdx=1;clientIdx<=MaxClients;clientIdx++)
	{
		if (IsValidClient(clientIdx))
		{
			SpeedSteal[clientIdx]=ShieldChargesSpeed[clientIdx]=0.0;
			SpeedStealDuration[clientIdx]=StrengthDuration[clientIdx]=JarateDuration[clientIdx]=InvisibilityDuration[clientIdx]=INACTIVE;
			Rockets[clientIdx]=Fire[clientIdx]=ShieldCharges[clientIdx]=RocketsButton[clientIdx]=ShieldChargesButton[clientIdx]=0;
			
			int bossIdx=FF2_GetBossIndex(clientIdx);
			if(bossIdx>=0)
			{
				if(FF2_HasAbility(bossIdx, this_plugin_name, COPYCAT))
				{
					CopyCat_TriggerAMS[clientIdx]=AMS_IsSubabilityReady(bossIdx, this_plugin_name, COPYCAT);
					if(CopyCat_TriggerAMS[clientIdx])
					{
						AMS_InitSubability(bossIdx, clientIdx, this_plugin_name, COPYCAT, "COPY"); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(bossIdx, this_plugin_name, SKILLSTEAL))
				{
					SkillSteal_TriggerAMS[clientIdx]=AMS_IsSubabilityReady(bossIdx, this_plugin_name, SKILLSTEAL);
					if(SkillSteal_TriggerAMS[clientIdx])
					{
						AMS_InitSubability(bossIdx, clientIdx, this_plugin_name, SKILLSTEAL, "SKST"); // Important function to tell AMS that this subplugin supports it
					}
				}
			}
		}
	}
}

public Action event_round_end(Handle event, const char[] name, bool dontBroadcast)
{
	for(int clientIdx=1;clientIdx<=MaxClients;clientIdx++)
	{
		if (IsValidClient(clientIdx))
		{
			SpeedSteal[clientIdx]=ShieldChargesSpeed[clientIdx]=0.0;
			SpeedStealDuration[clientIdx]=StrengthDuration[clientIdx]=JarateDuration[clientIdx]=InvisibilityDuration[clientIdx]=INACTIVE;
			Rockets[clientIdx]=Fire[clientIdx]=ShieldCharges[clientIdx]=RocketsButton[clientIdx]=ShieldChargesButton[clientIdx]=0;
			
			SDKUnhook(clientIdx, SDKHook_PreThink, SkillStealSpeed_Prethink);
			SDKUnhook(clientIdx, SDKHook_Touch, OnShieldTouch);
			SDKUnhook(clientIdx, SDKHook_PreThink, Charging_Prethink);
		}
	}
}

public Action FF2_OnAbility2(int bossIdx, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	int clientIdx=GetClientOfUserId(FF2_GetBossUserId(bossIdx));
	if(!strcmp(ability_name,COPYCAT))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			CopyCat_TriggerAMS[clientIdx]=false;
		}
		
		if(!CopyCat_TriggerAMS[clientIdx])
			COPY_Invoke(clientIdx);
	}
	else if(!strcmp(ability_name,SKILLSTEAL))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			SkillSteal_TriggerAMS[clientIdx]=false;
		}
		
		if(!SkillSteal_TriggerAMS[clientIdx])
			SKST_Invoke(clientIdx);
	}
	return Plugin_Continue;
}


public bool COPY_CanInvoke(int clientIdx)
{
	return true;
}

public void COPY_Invoke(int clientIdx)
{
	int bossIdx=FF2_GetBossIndex(clientIdx);
	
	if(CopyCat_TriggerAMS[clientIdx])
	{
		char snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_copycat", snd, sizeof(snd), bossIdx))
		{
			EmitSoundToAll(snd, clientIdx);
			EmitSoundToAll(snd, clientIdx);
		}		
	}
	
	int iClosest = GetClosestPlayer(clientIdx);
				
	if(IsValidClient(clientIdx))
	{
		TF2_DisguisePlayer(clientIdx, (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? (TFTeam_Red) : (TFTeam_Blue), TF2_GetPlayerClass(iClosest), iClosest);
	}
}

public bool SKST_CanInvoke(int clientIdx)
{
	return true;
}

public void SKST_Invoke(int clientIdx)
{
	int bossIdx=FF2_GetBossIndex(clientIdx);
	
	char scoutnotification[256], soldiernotification[256], pyronotification[256], demonotification[256], heavynotification[256], engineernotification[256], medicnotification[256], snipernotification[256], spynotification[256];
	char SkillStealSpeed[10], SkillStealDuration[10]; // Foolproof way so that args always return floats instead of ints
	
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 1, SkillStealSpeed, sizeof(SkillStealSpeed));
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 2, SkillStealDuration, sizeof(SkillStealDuration));
	
	int RocketsSkills=FF2_GetAbilityArgument(bossIdx, this_plugin_name, SKILLSTEAL, 3);	//No of times skill can be used per rage
	int FireSkills=FF2_GetAbilityArgument(bossIdx, this_plugin_name, SKILLSTEAL, 9);	//No of times skill can be used per rage
	int ShieldChargedSkills=FF2_GetAbilityArgument(bossIdx, this_plugin_name, SKILLSTEAL, 10);	//No of times skill can be used per rage
	StrengthDuration[clientIdx]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SKILLSTEAL, 14, 5.0);
	
	// 2.0 Additions
	MetalSteal[clientIdx]=FF2_GetAbilityArgument(bossIdx,this_plugin_name,SKILLSTEAL, 15);	// Extra Metal?
	
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 20, scoutnotification, sizeof(scoutnotification));				// Text to show to summoner
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 21, soldiernotification, sizeof(soldiernotification));				// Text to show to summoner
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 22, pyronotification, sizeof(pyronotification));				// Text to show to summoner
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 23, demonotification, sizeof(demonotification));				// Text to show to summoner
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 24, heavynotification, sizeof(heavynotification));				// Text to show to summoner
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 25, engineernotification, sizeof(engineernotification));				// Text to show to summoner
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 26, medicnotification, sizeof(medicnotification));				// Text to show to summoner
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 27, snipernotification, sizeof(snipernotification));				// Text to show to summoner
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, SKILLSTEAL, 28, spynotification, sizeof(spynotification));				// Text to show to summoner
	
	if(SkillSteal_TriggerAMS[clientIdx])
	{
		char snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_skill_steal", snd, sizeof(snd), bossIdx))
		{
			EmitSoundToAll(snd, clientIdx);
			EmitSoundToAll(snd, clientIdx);
		}
	}
	
	int iClosest = GetClosestPlayer(clientIdx);
	switch(TF2_GetPlayerClass(iClosest))
	{
		case TFClass_Scout:
		{
			SpeedSteal[clientIdx]=StringToFloat(SkillStealSpeed); // Boss Move Speed
			SpeedStealDuration[clientIdx]=GetEngineTime()+StringToFloat(SkillStealDuration); // Boss Move Speed Duration
			SDKHook(clientIdx, SDKHook_PreThink, SkillStealSpeed_Prethink);
			PrintCenterText(clientIdx, scoutnotification);
		}
		case TFClass_Soldier:
		{
			Rockets[clientIdx]+=RocketsSkills;
			PrintCenterText(clientIdx, soldiernotification);
		}
		case TFClass_Pyro:
		{
			Fire[clientIdx]+=FireSkills;
			PrintCenterText(clientIdx, pyronotification);
		}
		case TFClass_DemoMan:
		{
			ShieldCharges[clientIdx]+=ShieldChargedSkills;
			PrintCenterText(clientIdx, demonotification);
		}
		case TFClass_Heavy:
		{
			TF2_AddCondition(clientIdx, TFCond_RuneStrength, StrengthDuration[clientIdx]);  // Strength
			PrintCenterText(clientIdx, heavynotification);
		}
		case TFClass_Engineer:
		{
			SpawnWeapon(clientIdx, "tf_weapon_pda_engineer_build", 25, 101, 5, "292 ; 3 ; 293 ; 59 ; 391 ; 2 ; 495 ; 60", 0); // Build PDA
			SpawnWeapon(clientIdx, "tf_weapon_pda_engineer_destroy", 26, 101, 5, "391 ; 2", 0); // Destroy PDA
			int entity = SpawnWeapon(clientIdx, "tf_weapon_builder", 28, 101, 5, "391 ; 2", 0); // Builder
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
			SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
			if(MetalSteal[clientIdx])
				SetEntData(clientIdx, FindDataMapInfo(clientIdx, "m_iAmmo") + (3 * 4), MetalSteal[clientIdx], 4);
			PrintCenterText(clientIdx, engineernotification);
		}
		case TFClass_Medic:
		{
			HealthGained[clientIdx]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SKILLSTEAL, 16);	// How much Health regained?
			int health = FF2_GetBossHealth(bossIdx);
			int maxhealth = FF2_GetBossMaxHealth(bossIdx);
				
			health = RoundToCeil(health + (maxhealth * HealthGained[clientIdx]));
			if(health > maxhealth)
			{
				health = maxhealth;
			}
				
			FF2_SetBossHealth(bossIdx, health);
			PrintCenterText(clientIdx, medicnotification);
		}
		case TFClass_Sniper:
		{
			JarateDuration[clientIdx]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SKILLSTEAL, 17); // Duration of the Jarate
			float dist2=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SKILLSTEAL, 18); // Range
			if(dist2)
			{
				if(dist2==-1)
				{
					dist2=FF2_GetRageDist(bossIdx, this_plugin_name, SKILLSTEAL);
				}
		
				float pos[3], pos2[3], dist;
				GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", pos);
				for(int target=1;target<=MaxClients;target++)
				{
					if(!IsValidClient(target))
						continue;
		
					GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
					dist=GetVectorDistance( pos, pos2 );
					if (dist<dist2 && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam() && !TF2_IsPlayerInCondition(target, TFCond_Ubercharged))
					{
						TF2_AddCondition(target, TFCond_Jarated, JarateDuration[clientIdx]);
					}
				}
			}
			PrintCenterText(clientIdx, snipernotification);
		}
		case TFClass_Spy:
		{
			TF2_AddCondition(clientIdx, TFCond_StealthedUserBuffFade, FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SKILLSTEAL, 19));
			PrintCenterText(clientIdx, spynotification);
		}
	}
}

public Action OnPlayerRunCmd(int clientIdx, int &buttons, int &impulse, float velocity[3], float angles[3], int &weapon)
{
	int bossIdx=FF2_GetBossIndex(clientIdx);
	if(bossIdx==-1)
	{
		return Plugin_Continue;
	}

	if(bossIdx>=0 && FF2_HasAbility(bossIdx, this_plugin_name, SKILLSTEAL))
	{
		RocketsButton[clientIdx]=FF2_GetAbilityArgument(bossIdx, this_plugin_name, SKILLSTEAL, 4); // Use RELOAD, or SPECIAL to activate ability
		if(Rockets[clientIdx]>0) // Make sure its only used when a skill is available
		{
			if(RocketsButton[clientIdx]==2 &&(buttons & IN_ATTACK3) || RocketsButton[clientIdx]==1 && (buttons & IN_RELOAD))
			{
				UseRocket(clientIdx);
				Rockets[clientIdx]=(Rockets[clientIdx]>0 ? Rockets[clientIdx]-1 : 0);
				return Plugin_Changed;
			}
			return Plugin_Continue;
		}
		
		char ChargingSpeed[10];
		ShieldChargesButton[clientIdx]=FF2_GetAbilityArgument(bossIdx, this_plugin_name, SKILLSTEAL, 11); // Use RELOAD, or SPECIAL to activate ability
		float ShieldChargedDuration=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SKILLSTEAL, 12);
		ShieldChargesSpeed[clientIdx]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SKILLSTEAL, 13);
		if(ShieldCharges[clientIdx]>0) // Make sure its only used when a skill is available
		{
			if(ShieldChargesButton[clientIdx]==2 &&(buttons & IN_ATTACK3) || ShieldChargesButton[clientIdx]==1 && (buttons & IN_RELOAD))
			{
				ShieldChargesSpeed[clientIdx]=StringToFloat(ChargingSpeed); // Boss Move Speed
				SDKHook(clientIdx, SDKHook_PreThink, Charging_Prethink);
				
				SetEntPropFloat(clientIdx, Prop_Send, "m_flChargeMeter", 100.0);
				TF2_AddCondition(clientIdx, TFCond_Charging, ShieldChargedDuration);
				
				SDKHook(clientIdx, SDKHook_StartTouch, OnShieldTouch);
				TF2_AddCondition(clientIdx, TFCond_MegaHeal, ShieldChargedDuration);
				TF2_AddCondition(clientIdx, TFCond_SpeedBuffAlly, ShieldChargedDuration);
				SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", 2);
				
				CreateTimer(ShieldChargedDuration, ShieldChargedEnd, clientIdx);
				
				ShieldCharges[clientIdx]=(ShieldCharges[clientIdx]>0 ? ShieldCharges[clientIdx]-1 : 0);
				return Plugin_Changed;
			}
			return Plugin_Continue;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public void SkillStealSpeed_Prethink(int clientIdx)
{
	SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", SpeedSteal[clientIdx]);
	Speedskill(clientIdx, GetEngineTime());
}
public void Speedskill(int clientIdx, float gameTime)
{
	if(gameTime>=SpeedStealDuration[clientIdx])
	{
		SpeedSteal[clientIdx]=0.0;
		SpeedStealDuration[clientIdx]=INACTIVE;
		SDKUnhook(clientIdx, SDKHook_PreThink, SkillStealSpeed_Prethink);
	}
}

void UseRocket(int clientIdx)
{
	int bossIdx=GetClientOfUserId(FF2_GetBossUserId(clientIdx));
	float position[3];
	float rot[3];
	float velocity[3];
	GetEntPropVector(clientIdx, Prop_Send, "m_vecOrigin", position);
	GetClientEyeAngles(clientIdx,rot);
	position[2]+=63;
				
	int proj=CreateEntityByName("tf_projectile_rocket");
	SetVariantInt(FF2_GetBossTeam());
	AcceptEntityInput(proj, "TeamNum", -1, -1, 0);
	SetVariantInt(FF2_GetBossTeam());
	AcceptEntityInput(proj, "SetTeam", -1, -1, 0); 
	SetEntPropEnt(proj, Prop_Send, "m_hOwnerEntity",clientIdx);		
	float speed=FF2_GetAbilityArgumentFloat(bossIdx,this_plugin_name,SKILLSTEAL,5,1000.0);
	velocity[0]=Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*speed;
	velocity[1]=Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*speed;
	velocity[2]=Sine(DegToRad(rot[0]))*speed;
	velocity[2]*=-1;
	SetEntDataFloat(proj, FindSendPropOffs("CTFProjectile_Rocket", "m_iDeflected") + 4, FF2_GetAbilityArgumentFloat(bossIdx,this_plugin_name,SKILLSTEAL,8,40.0), true);
	DispatchSpawn(proj);
	TeleportEntity(proj, position, rot,velocity);
	SetEntProp(proj, Prop_Send, "m_bCritical", 1);
	char s[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(bossIdx,this_plugin_name,SKILLSTEAL,6,s,PLATFORM_MAX_PATH);
	if(strlen(s)>5)
		SetEntityModel(proj,s);
	FF2_GetAbilityArgumentString(bossIdx,this_plugin_name,SKILLSTEAL,7,s,PLATFORM_MAX_PATH);
	if(strlen(s)>2)
		CreateTimer(15.0, RemoveEntity, EntIndexToEntRef(AttachParticle(proj, s,_,true)));
}

public void event_player_hurt(Handle hEvent, const char[] strEventName, bool bDontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int index = FF2_GetBossIndex(attacker);
	
	if(victim != attacker && IsValidClient(attacker) && FF2_HasAbility(index, this_plugin_name, SKILLSTEAL))
	{
		if(IsValidClient(victim) && Fire[attacker])
		{
			TF2_IgnitePlayer(victim, attacker);
			Fire[attacker]=(Fire[attacker]>0 ? Fire[attacker]-1 : 0);
		}
	}
}

public Charging_Prethink(int clientIdx)
{
	SetEntPropFloat(clientIdx, Prop_Send, "m_flMaxspeed", ShieldChargesSpeed[clientIdx]);
}
public Action OnShieldTouch(int bossIdx, int iEntity)
{
	if(GetClientTeam(bossIdx) != FF2_GetBossTeam())
	{
		SDKUnhook(bossIdx, SDKHook_Touch, OnShieldTouch);
		return;
	}
	
	static float origin[3], angles[3], targetpos[3];
	if(IsValidClient(iEntity) && GetClientTeam(iEntity)!=FF2_GetBossTeam())
	{
		GetClientEyeAngles(bossIdx, angles);
		GetClientEyePosition(bossIdx, origin);
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", targetpos);
		GetAngleVectors(angles, angles, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(angles, angles);
		SubtractVectors(targetpos, origin, origin);

		if(GetVectorDotProduct(origin, angles) > 0.0 && !IsPlayerInvincible(iEntity))
		{
			SDKHooks_TakeDamage(iEntity, bossIdx, bossIdx, 15.0, DMG_CRUSH|DMG_PREVENT_PHYSICS_FORCE|DMG_ALWAYSGIB);	// Make boss get credit for the kill
			FakeClientCommandEx(iEntity, "explode");
		}		
	}
}
public Action ShieldChargedEnd(Handle hTimer, any clientIdx)
{
	if(IsValidClient(clientIdx))
	{
		SDKUnhook(clientIdx, SDKHook_StartTouch, OnShieldTouch);
		SDKUnhook(clientIdx, SDKHook_PreThink, Charging_Prethink);
		SetEntProp(clientIdx, Prop_Send, "m_CollisionGroup", 5);
		ShieldChargesSpeed[clientIdx]=0.0;
	}
}

stock int GetClosestPlayer(int iClient)
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

stock bool IsPlayerInvincible(int iClient)
{
	return TF2_IsPlayerInCondition(iClient, TFCond_Ubercharged) || TF2_IsPlayerInCondition(iClient, TFCond_UberchargedCanteen) || TF2_IsPlayerInCondition(iClient, TFCond_Bonked);
}

stock AttachParticle(entity, char[] particleType, float offset[]={0.0,0.0,0.0}, bool attach=true)
{
	int particle=CreateEntityByName("info_particle_system");

	char targetName[128];
	float position[3];
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

public Action RemoveEntity(Handle timer, any entid)
{
	int entity=EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

#file "FF2 Subplugin: Abilities for Double"
