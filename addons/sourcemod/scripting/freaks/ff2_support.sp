#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <entity>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <POTRY>

#define SOLID_NONE 0 // no solid model
#define SOLID_BSP 1 // a BSP tree
#define SOLID_BBOX 2 // an AABB
#define SOLID_OBB 3 // an OBB (not implemented yet)
#define SOLID_OBB_YAW 4 // an OBB, constrained so that it can only yaw
#define SOLID_CUSTOM 5 // Always call into the entity for tests
#define SOLID_VPHYSICS 6 // solid vphysics object, get vcollide from the model and collide with that

#define FSOLID_CUSTOMRAYTEST 0x0001 // Ignore solid type + always call into the entity for ray tests
#define FSOLID_CUSTOMBOXTEST 0x0002 // Ignore solid type + always call into the entity for swept box tests
#define FSOLID_NOT_SOLID 0x0004 // Are we currently not solid?
#define FSOLID_TRIGGER 0x0008 // This is something may be collideable but fires touch functions
#define FSOLID_NOT_STANDABLE 0x0010 // You can't stand on this
#define FSOLID_VOLUME_CONTENTS 0x0020 // Contains volumetric contents (like water)
#define FSOLID_FORCE_WORLD_ALIGNED 0x0040 // Forces the collision rep to be world-aligned even if it's SOLID_BSP or SOLID_VPHYSICS
#define FSOLID_USE_TRIGGER_BOUNDS 0x0080 // Uses a special trigger bounds separate from the normal OBB
#define FSOLID_ROOT_PARENT_ALIGNED 0x0100 // Collisions are defined in root parent's local coordinate space
#define FSOLID_TRIGGER_TOUCH_DEBRIS 0x0200 // This trigger will touch debris objects

#define	MAX_EDICT_BITS	12
#define	MAX_EDICTS		(1 << MAX_EDICT_BITS)

#define SPRITE 	"materials/sprites/dot.vmt"

public Plugin myinfo=
{
	name="Freak Fortress 2: Support",
	author="Nopied",
	description="",
	version="NEEDED!",
};

bool Sub_SaxtonReflect[MAXPLAYERS+1];
bool CBS_Abilities[MAXPLAYERS+1];
bool CBS_UpgradeRage[MAXPLAYERS+1];
bool IsTank[MAXPLAYERS+1];

bool CanWallWalking[MAXPLAYERS+1];
bool DoingWallWalking[MAXPLAYERS+1];
bool CoolingWallWalking[MAXPLAYERS+1];

float RocketCooldown[MAXPLAYERS+1];

float WalkingSoundCooldown[MAXPLAYERS+1];

bool IsTravis[MAXPLAYERS];
float TravisBeamCharge[MAXPLAYERS+1];
// float TravisBeamCoolTick[MAXPLAYERS+1];

int entSpriteRef[MAXPLAYERS+1] = {-1, ...};

bool IsEntityCanReflect[MAX_EDICTS];
bool AllLastmanStanding;
bool AttackAndDef;
bool enableVagineer = false;
// bool enableIceGround = false;
int g_nEntityBounce[MAX_EDICTS];

#define MODEL_ICEBLOCK  "models/custom/freezetag/iceshard.mdl"        // Ice Model

#define SOUND_FREEZE	"physics/glass/glass_impact_bullet4.wav"      // freeze sound

#define SOUND_FREEZE1	"physics/glass/glass_impact_bullet1.wav"      // unfreeze sounds
#define SOUND_FREEZE2	"physics/glass/glass_impact_bullet2.wav"
#define SOUND_FREEZE3	"physics/glass/glass_impact_bullet3.wav"

int g_entIceBlock[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
float g_flIceDuration[MAXPLAYERS+1] = {-1.0, ...};
float g_vecIceVelocity[MAXPLAYERS+1][3];

public void OnPluginStart2()
{
	HookEvent("teamplay_round_start", OnRoundStart_Pre);
	HookEvent("teamplay_round_win", OnRoundEnd);

	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath);

	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);

	PrecacheGeneric(SPRITE, true);
}
/*
void PrecacheThing()
{
	PrecacheGeneric(SPRITE, true);
}
*/
public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	for(int client=1; client<=MaxClients; client++)
	{
		if(g_flIceDuration[client] <= GetGameTime())
		{
			if(IsClientInGame(client) && IsPlayerAlive(client))
				TF2_RemoveCondition(client, TFCond_HalloweenKartNoTurn);
		}

		g_flIceDuration[client] = -1.0;
	}
}

public Action OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	if(FF2_GetRoundState() != 1)	return Plugin_Continue;

	int mainboss = FF2_GetBossIndex(0);
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int damage = GetEventInt(event, "damageamount");
	int custom = GetEventInt(event, "custom");

	int clientHp = GetEntProp(client, Prop_Send, "m_iHealth");
	int boss = FF2_GetBossIndex(attacker);

	bool bChanged = false;

	if(FF2_GetBossIndex(client) != -1)
	{
		return Plugin_Continue;
	}

	if(FF2_HasAbility(boss, this_plugin_name, "ff2_mlg_aimbot") && FF2_GetAbilityDuration(boss) > 0.0)
	{
		bChanged = true;

		SetEventInt(event, "custom", TF_CUSTOM_HEADSHOT);
	}
	/*
	if(FF2_HasAbility(mainboss, this_plugin_name, "ff2_snow_storm_passive"))
	{
		if(clientHp - damage < 1)
		{
			FrezzeClient(client, FF2_GetAbilityArgumentFloat(mainboss, this_plugin_name, "ff2_snow_storm_passive", 1, 300.0));
			SetEventInt(event, "damageamount", 0);
			return Plugin_Changed;
		}
	}
	*/


	return bChanged ? Plugin_Changed : Plugin_Continue;
}

public void OnGameFrame() //
{
	/*
	if(FF2_GetRoundState() != 1)
		return;

	int mainboss = FF2_GetBossIndex(0);
	int mainbossClient = GetClientOfUserId(FF2_GetBossUserId(mainboss));
	bool snowPassive = FF2_HasAbility(mainboss, this_plugin_name, "ff2_snow_storm_passive");
	// bool iceGround = FF2_HasAbility(mainboss, this_plugin_name, "ff2_ice_ground_passive");

	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsClientInGame(client) || !IsPlayerAlive(client)) continue;

		if(!IsBoss(client) && snowPassive && (GetGameTime() / 1.0) <= 0.0)
		{
			SDKHooks_TakeDamage(client, mainbossClient, mainbossClient, 1.0, DMG_SLASH, -1);
		}

		if(g_flIceDuration[client] > GetGameTime())
		{
			int fireEnt = -1;
			float clientPos[3];
			float fireOrigin[3];

			GetClientAbsOrigin(client, clientPos);

			while((fireEnt = FindEntityByClassname(fireEnt, "tf_flame")) != -1)
			{
				int Owner = GetEntPropEnt(fireEnt, Prop_Data, "m_hOwnerEntity");
				if(IsValidEdict(Owner))
				{
					GetEntPropVector(fireEnt, Prop_Send, "m_vecOrigin", fireOrigin);

					if(GetVectorDistance(clientPos, fireOrigin) <= 70.0)
					{
						g_flIceDuration[client] -= 0.1;
					}
				}
			}

			for(int target=1; target<=MaxClients; target++)
			{
				float targetPos[3];
				GetClientAbsOrigin(target, targetPos);
				if(IsClientInGame(target) && IsPlayerAlive(target))
				{
					if(GetVectorDistance(clientPos, fireOrigin) <= 70.0)
					{
						g_flIceDuration[client] -= 0.01;
					}
				}
			}

			PrintCenterText(client, "얼어붙었습니다! 녹을 때까지: %.1f초", GetGameTime() - g_flIceDuration[client]);
		}

		if(g_flIceDuration[client] <= GetGameTime())
		{
			int ice1 = EntRefToEntIndex(g_entIceBlock[client]);
			if (ice1 != INVALID_ENT_REFERENCE)                                   // Kill the old one if it somehow exists (admin slay frozen player or somesuch nonsense)
			{
				AcceptEntityInput(ice1, "Kill");
				g_entIceBlock[client] = INVALID_ENT_REFERENCE;                  // Just incase prop creation somehow fails, it will still take 1 frame for the old one to die
			}

			TF2_RemoveCondition(client, TFCond_HalloweenKartNoTurn);
		}

		// if(FF2_HasAbility(mainboss, this_plugin_name, "ff2_ice_ground_passive") && GetEntityFlags(client) & FL_ONGROUND)
		if(GetEntityFlags(client) & FL_ONGROUND)
		{
			// Debug("IceGround %N", client);

			int buttons = GetClientButtons(client);
			float maxIceSpeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");

			float clientEyeAngles[3];
			float clientVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", clientVelocity);

			float moveFwdVelocity[3];
			float moveRightVelocity[3];

			float moveBackVelocity[3];
			float moveLeftVelocity[3];

			GetClientEyeAngles(client, clientEyeAngles);

			clientEyeAngles[2] = 0.0;

			GetAngleVectors(clientEyeAngles, moveFwdVelocity, moveRightVelocity, NULL_VECTOR);

			for(int count=0; count<3; count++)
			{
				moveBackVelocity[count] = moveFwdVelocity[count] * -1.0;
				moveLeftVelocity[count] = moveRightVelocity[count] * -1.0;
			}

			ScaleVector(moveFwdVelocity, maxIceSpeed*0.3);
			ScaleVector(moveRightVelocity, maxIceSpeed*0.3);
			ScaleVector(moveBackVelocity, maxIceSpeed*0.3);
			ScaleVector(moveLeftVelocity, maxIceSpeed*0.3);

			if((buttons & IN_FORWARD|IN_RIGHT|IN_LEFT|IN_BACK)) 	// TODO: 자연스럽게 방향제어가 막히는지 실험해야함.
			{
				if(buttons & IN_FORWARD)
				{
					AddVectors(g_vecIceVelocity[client], moveFwdVelocity, g_vecIceVelocity[client]);
				}
				if(buttons & IN_RIGHT)
				{
					AddVectors(g_vecIceVelocity[client], moveRightVelocity, g_vecIceVelocity[client]);
				}
				if(buttons & IN_LEFT)
				{
					AddVectors(g_vecIceVelocity[client], moveLeftVelocity, g_vecIceVelocity[client]);
				}
				if(buttons & IN_BACK)
				{
					AddVectors(g_vecIceVelocity[client], moveBackVelocity, g_vecIceVelocity[client]);
				}

				// ScaleVector()
			}
			else
			{
				if(GetVectorLength(g_vecIceVelocity[client]) > 1)
					ScaleVector(g_vecIceVelocity[client], 0.94);
			}

			if(GetVectorLength(g_vecIceVelocity[client]) > 1)
			{
				g_vecIceVelocity[client][2] = clientVelocity[2];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, g_vecIceVelocity[client]);
			}
		}
	}
	*/
}

stock int FrezzeClient(int client, float time)
{
    new ice1 = EntRefToEntIndex(g_entIceBlock[client]);
    if (ice1 != INVALID_ENT_REFERENCE)                                   // Kill the old one if it somehow exists (admin slay frozen player or somesuch nonsense)
	{
		AcceptEntityInput(ice1, "Kill");
		g_entIceBlock[client] = INVALID_ENT_REFERENCE;                  // Just incase prop creation somehow fails, it will still take 1 frame for the old one to die
	}

	ice1 = CreateEntityByName("prop_dynamic");
	if ( ice1 != -1 )
	{
		decl Float:pos[3];
		decl Float:angle[3];

		GetClientAbsOrigin(client, pos);
		GetClientAbsAngles(client, angle);
		                            // Spawn the ice block with the player's angle, so they won't all look the same
        angle[0] = GetRandomFloat(-5.0,5.0);                          // Purge eye position data, generate random variance
    	angle[2] = GetRandomFloat(-5.0,5.0);

    	DispatchKeyValueVector(ice1, "origin", pos);
        DispatchKeyValueVector(ice1, "angles", angle);

        decl String:Buffer[32];
		Format(Buffer, 32, "%i%i", client, time);
        DispatchKeyValue(ice1, "targetname", Buffer);                 // name the prop ent-time, so we can parent.

        DispatchKeyValue(ice1, "model", MODEL_ICEBLOCK);
		DispatchKeyValue(ice1, "solid", "0");
		DispatchKeyValue(ice1, "disableshadows", "1");
		if(view_as<TFTeam>(GetClientTeam(client)) == TFTeam_Blue)
		{
			DispatchKeyValue(ice1, "skin", "1");

		}
		DispatchSpawn(ice1);
		ActivateEntity(ice1);
		SetVariantString("idle");
		AcceptEntityInput(ice1, "SetAnimation", -1, -1, 0);
		AcceptEntityInput(ice1, "TurnOn");

		TF2_AddCondition(client, TFCond_HalloweenKartNoTurn, TFCondDuration_Infinite);

        g_entIceBlock[client] = EntIndexToEntRef(ice1);                  // Preserve, for later
		g_flIceDuration[client] = GetGameTime() + time;
	}

	return ice1;
}



public Action OnRoundStart_Pre(Handle event, const char[] name, bool dont)
{
    CreateTimer(10.4, OnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);

/*

	for(int client = 1; client<=MaxClients; client++)
	{
		int viewentity = EntRefToEntIndex(entSpriteRef[client]);
		if(IsValidEntity(viewentity))
		{
			if(IsClientInGame(client))
				SetClientViewEntity(client, client);

			AcceptEntityInput(viewentity, "kill");
		}
	}

*/

}

public Action OnPlayerSpawn(Handle event, const char[] name, bool dont)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int mainboss = FF2_GetBossIndex(0);

	if(FF2_GetRoundState() != 1 || !IsValidClient(client))	return Plugin_Continue;

	g_flIceDuration[client] = -1.0;

	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	if(FF2_HasAbility(mainboss, this_plugin_name, "ff2_spawn_mlg_bot") && GetClientTeam(client) == FF2_GetBossTeam())
	{
		Aimbot_SetState(client, AimbotType_Aimbot, true);
		Aimbot_SetState(client, AimbotType_SlientAim, true);
		Aimbot_SetState(client, AimbotType_AutoShoot, true);
	}

	/*
	if(enableVagineer && entSpriteRef[client] == -1)
	{
		float clientPos[3];
		GetClientEyePosition(client, clientPos);

		int ent = CreateViewEntity(client, clientPos);
		if(IsValidEntity(ent))
		{
			entSpriteRef[client] = EntIndexToEntRef(ent);
		}
	}
	*/

	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!IsValidClient(attacker))	return Plugin_Continue;

	int boss = FF2_GetBossIndex(attacker);
	bool bChanged = false;

	if(damagecustom != TF_CUSTOM_HEADSHOT)
	{
		if(FF2_HasAbility(boss, this_plugin_name, "ff2_mlg_aimbot") && FF2_GetAbilityDuration(boss) > 0.0)
		{
			bChanged = true;
			damagetype |= DMG_CRIT;
		}
	}

	return bChanged ? Plugin_Changed : Plugin_Continue;
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dont)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if(!IsValidClient(client))	return Plugin_Continue;

	g_flIceDuration[client] = -1.0;

	int ice = EntRefToEntIndex(g_entIceBlock[client]);
    if (ice != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ice, "Kill");
		g_entIceBlock[client] = INVALID_ENT_REFERENCE;
	}

	int viewentity = EntRefToEntIndex(entSpriteRef[client]);
	if(IsValidEntity(viewentity))
	{
		SetClientViewEntity(client, client);
		AcceptEntityInput(viewentity, "kill");
		entSpriteRef[client] = -1;
	}

/*
	if(IsBoss(attacker))
	{
		int boss = FF2_GetBossIndex(attacker);

		if(TravisBeamCharge[attacker] >= 70.0)
		{
			float neededTimeStop = (100.0 - TravisBeamCharge[attacker]) / 5.0;

			if(TIMESTOP_IsTimeStopping())
			{
				TIMESTOP_DisableTimeStop();
			}

			TIMESTOP_EnableTimeStop(attacker, 0.1, neededTimeStop);
		}
	}
	*/

	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	g_flIceDuration[client] = -1.0;

	if(entSpriteRef[client] != -1)
	{
		int viewentity = EntRefToEntIndex(entSpriteRef[client]);
		if(IsValidEntity(viewentity))
		{
			AcceptEntityInput(viewentity, "kill");
			entSpriteRef[client] = -1;
		}
	}

}

stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}

public OnEntityCreated(entity, const String:classname[])
{
	if (StrContains(classname, "tf_projectile_"))
		return;
 	// SDKHook_SpawnPost

	SDKHook(entity, SDKHook_SpawnPost, OnSpawn);
	SDKHook(entity, SDKHook_StartTouch, OnStartTouch);
}

public Action OnStartTouch(int entity, int other)
{
	if (other > 0 && other <= MaxClients)
		return Plugin_Continue;

	// Only allow a rocket to bounce x times.
	if (g_nEntityBounce[entity] >= 50)
		return Plugin_Continue;

	SDKHook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public void OnSpawn(int entity)
{
	IsEntityCanReflect[entity] = false;
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if(!IsValidClient(owner)) return;

	if(CBS_Abilities[owner])
	{
		int observer;
		char angleString[80];
		float opAng[3];

		IsEntityCanReflect[entity]=true;
		g_nEntityBounce[entity]=0;
		// GetEntPropVector(entity,Prop_Data,"m_vecOrigin",opPos);
		GetEntPropVector(entity,Prop_Data, "m_angAbsRotation", opAng);
		Format(angleString, sizeof(angleString), "%.1f %.1f %.1f",
		opAng[0],
		opAng[1],
		opAng[2]);

		observer = CreateEntityByName("info_observer_point");
		DispatchKeyValue(observer, "Angles", angleString);
		DispatchKeyValue(observer, "TeamNum", "0");
		DispatchKeyValue(observer, "StartDisabled", "0");
		DispatchSpawn(observer);
		AcceptEntityInput(observer, "Enable");
		SetVariantString("!activator");
		AcceptEntityInput(observer, "SetParent", entity);
	}
/*
	if(CBS_UpgradeRage[owner])
	{
		float opAng[3];
		float opPos[3];
		float tempPos[3];
		float tempAng[3];
		float tempVelocity[3];
		float opVelocity[3];

		int boss = FF2_GetBossIndex(owner);
		int arrowCount = FF2_GetAbilityArgument(boss, this_plugin_name, "ff2_CBS_upgrade_rage", 1, 5);

		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", opPos);
		GetEntPropVector(entity, Prop_Send, "m_angRotation", opAng);
		GetEntPropVector(entity, Prop_Data, "m_vecVelocity", opVelocity);

		float arrowSpeed = GetVectorLength(opVelocity);

		float Random = 10.0;
		float Random2 = Random*-1;
		int counter = 0;

		for(int count=0; count < arrowCount; count++)
		{
			tempAng[0] = opAng[0] + GetRandomFloat(Random2,Random);
			tempAng[1] = opAng[1] + GetRandomFloat(Random2,Random);
			// avoid unwanted collision
			int i2 = count%4;
			switch(i2)
			{
				case 0:
				{
					counter++;
					tempPos[0] = opPos[0] + counter;
				}
				case 1:
				{
					tempPos[1] = opPos[1] + counter;
				}
				case 2:
				{
					tempPos[0] = opPos[0] - counter;
				}
				case 3:
				{
					tempPos[1] = opPos[1] - counter;
				}
			}

			GetVectorAngles(tempAng, tempVelocity);

			tempVelocity[0] *= arrowSpeed;
			tempVelocity[1] *= arrowSpeed;
			tempVelocity[2] *= arrowSpeed;

			int arrow = CreateEntityByName("tf_projectile_arrow");
			if(!IsValidEntity(arrow)) break;

			Debug("arrow = %i", arrow);

			IsEntityCanReflect[arrow] = true;

			SetEntPropEnt(arrow, Prop_Send, "m_hOwnerEntity", owner);
			SetEntProp(arrow,    Prop_Send, "m_bCritical",  0);
			SetEntProp(arrow,    Prop_Send, "m_iTeamNum", GetClientTeam(owner));

			SetEntDataFloat(arrow,
				FindSendPropInfo("CTFProjectile_Arrow" , "m_iDeflected") + 4,
				100.0,
				true); // set damage
			// SetEntData(arrow, FindSendPropInfo("CTFProjectile_Arrow" , "m_nSkin"), (iTeam-2), 1, true);

			SetVariantInt(GetClientTeam(owner));
			AcceptEntityInput(arrow, "TeamNum", -1, -1, 0);

			SetVariantInt(GetClientTeam(owner));
			AcceptEntityInput(arrow, "SetTeam", -1, -1, 0);

			DispatchSpawn(arrow);

			TeleportEntity(arrow, tempPos, tempAng, tempVelocity);
		}
	}
	*/
}
public Action:FF2_OnPlayBoss(int client, int bossIndex)
{
	CheckAbilities(client, true);
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

  	if(StrEqual(ability_name, "ff2_tank"))
	{
		RocketCooldown[client] = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_tank", 1, 1.5);

		float clientEyePos[3];
		float clientEyeAngles[3];
		float vecrt[3];
		float angVector[3];

		GetClientEyePosition(client, clientEyePos);
		GetClientEyeAngles(client, clientEyeAngles);

		GetAngleVectors(clientEyeAngles, angVector, vecrt, NULL_VECTOR);
		NormalizeVector(angVector, angVector);

		float speed = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_tank", 5, 1200.0);

		angVector[0] *= speed;
		angVector[1] *= speed;
		angVector[2] *= speed;

		int rocket = SpawnRocket(client, clientEyePos, clientEyeAngles, angVector, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_tank", 6, 90.5), true);
		if(IsValidEntity(rocket))
		{
			SetEntPropFloat(rocket, Prop_Send, "m_flModelScale", 5.0);
			int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			TF2Attrib_SetByDefIndex(weapon, 521, 1.0);
			TF2Attrib_SetByDefIndex(weapon, 642, 0.0); // 99
			TF2Attrib_SetByDefIndex(weapon, 99, 2.5);

			char path[PLATFORM_MAX_PATH];
			FF2_GetAbilityArgumentString(boss, this_plugin_name, "ff2_tank", 7, path, sizeof(path));

			if(path[0] != '\0')
			{
				EmitSoundToAll(path, client, _, _, _, _, _, client, clientEyePos);
			}
		}
	}

	if(StrEqual(ability_name, "ff2_rage_stone"))
	{
		CreateStone(boss);
	}
	if(StrEqual(ability_name, "ff2_mlg_aimbot"))
	{
		Aimbot_SetState(client, AimbotType_Aimbot, true);
		Aimbot_SetState(client, AimbotType_NoSpread, true);
		Aimbot_SetState(client, AimbotType_SlientAim, true);
	}

/*
	if(StrEqual(ability_name, "ff2_CBS_upgrade_rage"))
	{
		Debug("CBS_UpgradeRage[client] = true");
		CBS_UpgradeRage[client] = true;
	}
*/
}

void CreateStone(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	int stoneCount = FF2_GetAbilityArgument(boss, this_plugin_name, "ff2_rage_stone", 1, 10);
	float PropVelocity = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_rage_stone", 2, 10000.0);
	int stoneHealth = FF2_GetAbilityArgument(boss, this_plugin_name, "ff2_rage_stone", 3, 400);
	char strModelPath[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "ff2_rage_stone", 4, strModelPath, sizeof(strModelPath));

	for(int count=0; count<stoneCount; count++)
	{
		int prop = CreateEntityByName("prop_physics_override");
		if(IsValidEntity(prop))
		{
			// Debug("%i", prop);
			SetEntityModel(prop, strModelPath);
			SetEntityMoveType(prop, MOVETYPE_VPHYSICS);
			SetEntProp(prop, Prop_Send, "m_CollisionGroup", 5);
			SetEntProp(prop, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER_TOUCH_DEBRIS); // not solid
			SetEntProp(prop, Prop_Send, "m_nSolidType", SOLID_VPHYSICS); // not solid
			SetEntProp(prop, Prop_Data, "m_takedamage", 2);
			SetEntProp(prop, Prop_Data, "m_iMaxHealth", stoneHealth);
			SetEntProp(prop, Prop_Data, "m_iHealth", stoneHealth);
			DispatchSpawn(prop);

			float position[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", position);

			float velocity[3];

			velocity[0] = GetRandomFloat(PropVelocity*0.5, PropVelocity*1.5);
			velocity[1] = GetRandomFloat(PropVelocity*0.5, PropVelocity*1.5);
			velocity[2] = GetRandomFloat(PropVelocity*0.5, PropVelocity*1.5);
			NormalizeVector(velocity, velocity);


			TeleportEntity(prop, position, NULL_VECTOR, velocity);
			// TeleportEntity(prop, position, NULL_VECTOR, NULL_VECTOR);

			SDKHook(prop, SDKHook_Touch, OnStoneTouch);
			SDKHook(prop, SDKHook_StartTouch, OnStoneTouch);
		}
		else
			break;
	}
}


public Action OnStoneTouch(int entity, int other)
{
	float modelScale = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");

	if (other > 0 && other <= MaxClients)
	{
		if(!IsBossTeam(other))
		{
			SDKHooks_TakeDamage(other, entity, entity, 15.0, DMG_SLASH, -1);
		}
		else
		{
			KickEntity(other, entity);
		}

		if(modelScale-0.008 < 0.1)
		{
			AcceptEntityInput(entity, "kill");
			return Plugin_Continue;
		}
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", modelScale-0.008);
	}
	else if(other > 0)
	{
		float position[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);

		float otherPosition[3];
		GetEntPropVector(other, Prop_Send, "m_vecOrigin", otherPosition);

		float goalVector[3], goalOtherVector[3];
		MakeVectorFromPoints(position, otherPosition, goalVector);
		MakeVectorFromPoints(otherPosition, position, goalOtherVector);

		NormalizeVector(goalVector, goalVector);
		ScaleVector(goalVector, -2500.0);

		NormalizeVector(goalOtherVector, goalOtherVector);
		ScaleVector(goalOtherVector, -2500.0);

		TeleportEntity(entity, position, NULL_VECTOR, goalVector);
		TeleportEntity(other, position, NULL_VECTOR, goalOtherVector);
	}
	else
	{
		decl Float:vOrigin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);

		decl Float:vAngles[3];
		GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);

		decl Float:vVelocity[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);

		new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);

		if(!TR_DidHit(trace))
		{
			CloseHandle(trace);
			return Plugin_Continue;
		}

		decl Float:vNormal[3];
		TR_GetPlaneNormal(trace, vNormal);

		//PrintToServer("Surface Normal: [%.2f, %.2f, %.2f]", vNormal[0], vNormal[1], vNormal[2]);

		CloseHandle(trace);

		new Float:dotProduct = GetVectorDotProduct(vNormal, vVelocity);

		ScaleVector(vNormal, dotProduct);
		ScaleVector(vNormal, 2.0);

		decl Float:vBounceVec[3];
		SubtractVectors(vVelocity, vNormal, vBounceVec);

		decl Float:vNewAngles[3];
		GetVectorAngles(vBounceVec, vNewAngles);

		//PrintToServer("Angles: [%.2f, %.2f, %.2f] -> [%.2f, %.2f, %.2f]", vAngles[0], vAngles[1], vAngles[2], vNewAngles[0], vNewAngles[1], vNewAngles[2]);
		//PrintToServer("Velocity: [%.2f, %.2f, %.2f] |%.2f| -> [%.2f, %.2f, %.2f] |%.2f|", vVelocity[0], vVelocity[1], vVelocity[2], GetVectorLength(vVelocity), vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));

		TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);
	}

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(FF2_GetRoundState() != 1)
	{
		return Plugin_Continue;
	}

	bool changed = false;

	if(IsValidClient(client) && IsPlayerAlive(client))
	{
			// Debug("%N: %i", client, buttons);

		 	int boss = FF2_GetBossIndex(client);
			int mainboss = FF2_GetBossIndex(0);

			if(boss == -1 && FF2_HasAbility(mainboss, this_plugin_name, "rage_arrowkeyattack") && FF2_GetAbilityDuration(mainboss) > 0.0)
			{
				/*
				float maxSpeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");

				float clientAngles[3];

				float moveFwdAngles[3];
				float moveRightAngles[3];

				float moveBackAngles[3];
				float moveLeftAngles[3];

				float totalMoveVelocity[3];
				float velocity[3];
				GetEntPropVector(client, Prop_Send, "m_vecAbsVelocity", velocity);
				GetClientEyeAngles(client, clientAngles);

				clientAngles[2] = 0.0;

				GetAngleVectors(clientAngles, moveFwdAngles, moveRightAngles, NULL_VECTOR);

				for(int count=0; count<3; count++)
				{
					moveBackAngles[count] = moveFwdAngles[count] * -1.0;
					moveLeftAngles[count] = moveRightAngles[count] * -1.0;
				}

				if(buttons & IN_FORWARD|IN_RIGHT|IN_LEFT|IN_BACK)
				{
					if(buttons & IN_FORWARD)
					{
						AddVectors(totalMoveVelocity, moveBackAngles, totalMoveVelocity);
					}
					if(buttons & IN_RIGHT)
					{
						AddVectors(totalMoveVelocity, moveLeftAngles, totalMoveVelocity);
					}
					if(buttons & IN_LEFT)
					{
						AddVectors(totalMoveVelocity, moveRightAngles, totalMoveVelocity);
					}
					if(buttons & IN_BACK)
					{
						AddVectors(totalMoveVelocity, moveFwdAngles, totalMoveVelocity);
					}

					if(GetEntityFlags(client) & FL_ONGROUND)
						ScaleVector(totalMoveVelocity, maxSpeed);
					else
					{
						ScaleVector(totalMoveVelocity, maxSpeed*0.3); // TODO: 부자연스러우면 추가 작업.
						// float velocity[3];
						// GetEntPropVector(client, Prop_Send, "m_vecAbsVelocity", velocity);
					}

					totalMoveVelocity[2] = velocity[2];

					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, totalMoveVelocity);
				}
				*/

				if(buttons & IN_FORWARD|IN_MOVERIGHT|IN_MOVELEFT|IN_BACK)
				{
					changed = true;

					vel[0] = -vel[0];
					vel[1] = -vel[1];

					if(buttons & IN_MOVELEFT){

						buttons &= ~IN_MOVELEFT;
						buttons |= IN_MOVERIGHT;

					}else if(buttons & IN_MOVERIGHT){

						buttons &= ~IN_MOVERIGHT;
						buttons |= IN_MOVELEFT;

					}

					if(buttons & IN_FORWARD){

						buttons &= ~IN_FORWARD;
						buttons |= IN_BACK;

					}else if(buttons & IN_BACK){

						buttons &= ~IN_BACK;
						buttons |= IN_FORWARD;

					}
				}
			}

			if(enableVagineer && entSpriteRef[client] != -1)
			{
				int viewentity = EntRefToEntIndex(entSpriteRef[client]);

				float vecclientAngles[3];
				GetClientEyeAngles(client, vecclientAngles);

				vecclientAngles[1] = -179.0;

				TeleportEntity(viewentity, NULL_VECTOR, vecclientAngles, NULL_VECTOR);
			}

		    if(buttons & IN_ATTACK)
		    {
				if(Sub_SaxtonReflect[client])
				{
					if(GetEntPropFloat(client, Prop_Send, "m_flNextAttack") > GetGameTime()
					|| GetEntPropFloat(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), Prop_Send, "m_flNextPrimaryAttack") > GetGameTime())
						return Plugin_Continue;

					int ent;
					float clientPos[3];
					float clientEyeAngles[3];
					float end_pos[3];
					float targetPos[3];
					// float targetEndPos[3];
					float vecrt[3];
					float angVector[3];

					GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientPos);
					GetClientEyeAngles(client, clientEyeAngles);
					GetEyeEndPos(client, 100.0, end_pos);

					while((ent = FindEntityByClassname(ent, "tf_projectile_*")) != -1)
					{
						if(GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity") == client)
						 continue;

						GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetPos);

						if(GetVectorDistance(end_pos, targetPos) <= 100.0)
						{
							SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);

							if(HasEntProp(ent, Prop_Send, "m_iTeamNum"))
							{
								SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
							}
							if(HasEntProp(ent, Prop_Send, "m_bCritical"))
							{
								SetEntProp(ent, Prop_Send, "m_bCritical", 1);
							} // m_iDeflected
							if(HasEntProp(ent, Prop_Send, "m_iDeflected"))
							{
								SetEntProp(ent, Prop_Send, "m_iDeflected", 1);
							}
							if(HasEntProp(ent, Prop_Send, "m_hThrower"))
							{
								SetEntPropEnt(ent, Prop_Send, "m_hThrower", client);
							}
							if(HasEntProp(ent, Prop_Send, "m_hDeflectOwner"))
							{
								SetEntPropEnt(ent, Prop_Send, "m_hDeflectOwner", client);
							}

							GetAngleVectors(clientEyeAngles, angVector, vecrt, NULL_VECTOR);
							NormalizeVector(angVector, angVector);

							angVector[0] *= 1500.0;
							angVector[1] *= 1500.0;
							angVector[2] *= 1500.0;

							TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, angVector);
							EmitSoundToAll("player/flame_out.wav", ent, _, _, _, _, _, ent, targetPos);
						}
					}
				}
			}
/*
			if(IsTravis[client])
			{
				TravisBeamCharge[client] -= FF2_GetAbilityArgumentFloat(FF2_GetBossIndex(boss), this_plugin_name, "ff2_travis", 2, 0.01);

				if(TravisBeamCharge[client] < 0.0)
					TravisBeamCharge[client] = 0.0;

				PrintCenterText(client, "빔 카타나 충전율: %.1f%%\n무기를 휘둘러 충전", TravisBeamCharge[client]);
			}
*/
			if(IsTank[client])
			{
				SetOverlay(client, "Effects/combine_binocoverlay");

				int ent = -1;
				float range = 75.0;
				float clientPos[3];
				float targetPos[3];
				GetClientAbsOrigin(client, clientPos);

				while((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1) // FIXME: 한 문장 안에 다 넣으면 스크립트 처리에 문제가 생김.
			    {
			      GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetPos);

			      if(GetVectorDistance(clientPos, targetPos) <= range)
			      {
			        SDKHooks_TakeDamage(ent, client, client, 30.0, DMG_SLASH|DMG_SHOCK|DMG_ENERGYBEAM|DMG_BURN, -1);
			      }
			    }

			    while((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)  // FIXME: 한 문장 안에 다 넣으면 스크립트 처리에 문제가 생김.
			    {
			      GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetPos);

			      if(GetVectorDistance(clientPos, targetPos) <= range)
			      {
			        SDKHooks_TakeDamage(ent, client, client, 30.0, DMG_SLASH|DMG_SHOCK|DMG_ENERGYBEAM|DMG_BURN, -1);
			      }
			    }


			    while((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1) // FIXME: 한 문장 안에 다 넣으면 스크립트 처리에 문제가 생김.
			    {
			      GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetPos);

			      if(GetVectorDistance(clientPos, targetPos) <= range)
			      {
			        SDKHooks_TakeDamage(ent, client, client, 30.0, DMG_SLASH|DMG_SHOCK|DMG_ENERGYBEAM|DMG_BURN, -1);
			      }
			    }
			}

			if(buttons & IN_ATTACK2 && IsTank[client] && GetGameTime() > RocketCooldown[client])
			{
				RocketCooldown[client] = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_tank", 1, 1.5);

				float clientEyePos[3];
				float clientEyeAngles[3];
				float vecrt[3];
				float angVector[3];

				GetClientEyePosition(client, clientEyePos);
				GetClientEyeAngles(client, clientEyeAngles);

				GetAngleVectors(clientEyeAngles, angVector, vecrt, NULL_VECTOR);
				NormalizeVector(angVector, angVector);

				float speed = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_tank", 2, 1200.0);

				clientEyePos[2] -= 12.0;

				angVector[0] *= speed;
				angVector[1] *= speed;
				angVector[2] *= speed;

				int rocket = SpawnRocket(client, clientEyePos, clientEyeAngles, angVector, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_tank", 3, 14.5), true);
				if(IsValidEntity(rocket))
				{
					int weapon2 = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

					TF2Attrib_SetByDefIndex(weapon2, 521, 0.0); //642
					TF2Attrib_SetByDefIndex(weapon2, 642, 3.0);
					TF2Attrib_SetByDefIndex(weapon2, 99, 1.0);

					char path[PLATFORM_MAX_PATH];
					FF2_GetAbilityArgumentString(boss, this_plugin_name, "ff2_tank", 4, path, sizeof(path));

					if(path[0] != '\0')
					{
						EmitSoundToAll(path, client, _, _, _, _, _, client, clientEyePos);
					}

				}
			}

			if((buttons & IN_FORWARD || buttons & IN_LEFT || buttons & IN_RIGHT)
			&& IsTank[client])
			{
			 	bool NearWall = false;
				float StartOrigin[3];
				float StartAngle[3];
				float tempAngle[3];
				float EndOrigin[3];
				float vecrt[3];
				float Velocity[3];

				float Distance;
				Handle TraceRay;

				GetClientEyePosition(client, StartOrigin);
				GetClientEyeAngles(client, StartAngle);

				GetAngleVectors(StartAngle, Velocity, vecrt, NULL_VECTOR);
				NormalizeVector(Velocity, Velocity);

				tempAngle[0] = 50.0;
				tempAngle[1] = StartAngle[1];
				tempAngle[2] = StartAngle[2];

				for(int y = 50; y >= -50; y--)
				{
					tempAngle[0] -= 1.0;

					// TraceRay = TR_TraceRayEx(StartOrigin, tempAngle, MASK_SOLID, RayType_Infinite);
					TraceRay = TR_TraceRayFilterEx(StartOrigin, tempAngle, MASK_SOLID, RayType_Infinite, TraceRayNoPlayer, client);

					if(TR_DidHit(TraceRay))
					{
						TR_GetEndPosition(EndOrigin, TraceRay);
						Distance = (GetVectorDistance(StartOrigin, EndOrigin));

						if(Distance < 60.0 && !TR_PointOutsideWorld(EndOrigin)) NearWall = true;
					}

					CloseHandle(TraceRay);
		/*
					PrintCenterText(client, "Distance: %.1f\n%.1f %.1f %.1f %s", Distance, Velocity[0], Velocity[1], Velocity[2],
					NearWall ? "true" : "false"
					);
		*/

					if(NearWall)
					{
						float Speed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed")*0.8;

						if(buttons & IN_JUMP)
							Speed *= 2.0;

						Velocity[1] *= 180.0;
						Velocity[2] *= Speed;
						Velocity[0] *= 180.0;

						TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, Velocity);

						DoingWallWalking[client] = NearWall;

						break;
					}
				}
			}

			if(IsTank[client])
			{
				float StartAngle[3];
				float tempAngle[3];
				GetClientEyeAngles(client, StartAngle);

				if(DoingWallWalking[client])
				{
					CoolingWallWalking[client] = false;
					tempAngle[0] = StartAngle[0] > 0.0 ? 0.0 : StartAngle[0];
				}
				else if(GetEntityFlags(client) & FL_ONGROUND)
				{
					tempAngle[0] = 0.0;
				}

				tempAngle[1] = StartAngle[1];
				tempAngle[2] = StartAngle[2];

				if(!CoolingWallWalking[client])
				{
					char Input[100];

					char modelPath[PLATFORM_MAX_PATH];
					GetClientModel(client, modelPath, sizeof(modelPath));

					SetVariantString(modelPath);
					AcceptEntityInput(client, "SetCustomModel", client);

					Format(Input, sizeof(Input), "%.1f %.1f %.1f", tempAngle[0], tempAngle[1], tempAngle[2]);

					SetVariantBool(true);
					AcceptEntityInput(client, "SetCustomModelRotates", client);

					SetVariantString(Input);
					AcceptEntityInput(client, "SetCustomModelRotation", client);

					RequestFrame(ClassAniTimer, client);

					if(GetEntityFlags(client) & FL_ONGROUND)
					{
						CoolingWallWalking[client] = true;
					}
				}
			}
	}
	return Plugin_Continue;
}

void KickEntity(int client, int entity)
{
	float clientEyeAngles[3];
	float vecrt[3];
	float angVector[3];

	GetClientEyeAngles(client, clientEyeAngles);
	GetAngleVectors(clientEyeAngles, angVector, vecrt, NULL_VECTOR);
	NormalizeVector(angVector, angVector);

	angVector[0] *= 1500.0;
	angVector[1] *= 1500.0;
	angVector[2] *= 1500.0;

	TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, angVector);
	// SetEntProp(entity, Prop_Send, "m_CollisionGroup", 2);

}


 public Action FF2_OnBossAbilityTime(int boss, char[] abilityName, int slot, float &abilityDuration, float &abilityCooldown)
 {
	 int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	 if(IsTravis[client] && abilityDuration > 0.0)
	 {
		 TravisBeamCharge[client] = 100.0;
	 }

 } //

public Action FF2_OnAbilityTimeEnd(int boss, int slot)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	if(FF2_HasAbility(boss, this_plugin_name, "ff2_mlg_aimbot"))
	{
		Aimbot_SetState(client, AimbotType_Aimbot, false);
		Aimbot_SetState(client, AimbotType_NoSpread, false);
		Aimbot_SetState(client, AimbotType_SlientAim, false);
	}
}

public Action OnRoundStart(Handle timer)
{
  	CheckAbilities();

  	if(AttackAndDef)
		FF2_SetGameState(Game_AttackAndDefense);
}

void CheckAbilities(int client=0, bool onlyforclient=false)
{
  int boss;
  AllLastmanStanding = false;
  AttackAndDef = false;
  enableVagineer = false;
  // enableIceGround = false;

  for(int target=1; target <= MaxClients; target++)
  {
	  	if(onlyforclient && target != client)
		{
			continue;
		}

		if(entSpriteRef[target] != -1)
		{
			int viewentity = EntRefToEntIndex(entSpriteRef[target]);
			if(IsValidEntity(viewentity))
			{
				if(IsClientInGame(target))
					SetClientViewEntity(target, target);
				AcceptEntityInput(viewentity, "kill");

				entSpriteRef[target] = -1;
			}
		}
		entSpriteRef[target] = -1;


		if(IsClientInGame(target))
		{
			if(IsTank[target])
			{
				SetOverlay(target, "");

				SDKUnhook(target, SDKHook_StartTouch, OnTankTouch);
				SDKUnhook(target, SDKHook_Touch, OnTankTouch);
			}
			if(IsTank[target]) // TODO: 개별화
			{
				float StartAngle[3];
				float tempAngle[3];
				char Input[100];

				GetClientEyeAngles(target, StartAngle);

				tempAngle[0] = 0.0;
				tempAngle[1] = StartAngle[1];
				tempAngle[2] = StartAngle[2];

				Format(Input, sizeof(Input), "%.1f %.1f %.1f", tempAngle[0], tempAngle[1], tempAngle[2]);

				SetVariantBool(true);
				AcceptEntityInput(target, "SetCustomModelRotates", target);

				SetVariantString(Input);
				AcceptEntityInput(target, "SetCustomModelRotation", target);

				RequestFrame(ClassAniTimer, target);

				SetVariantBool(false);
				AcceptEntityInput(target, "SetCustomModelRotates", target);
			}
		}

		Sub_SaxtonReflect[target] = false;
		CBS_Abilities[target] = false;
		CBS_UpgradeRage[target] = false;

		CanWallWalking[target] = false;
		DoingWallWalking[target] = false;
		CoolingWallWalking[target] = false;

		IsTank[target] = false;

		RocketCooldown[target] = 0.0;
		WalkingSoundCooldown[target] = 0.0;

		IsTravis[target] = false;
		TravisBeamCharge[target] = 0.0;

	    if((boss=FF2_GetBossIndex(target)) != -1)
	    {
			if(FF2_HasAbility(boss, this_plugin_name, "ff2_wallwalking"))
			{
				CanWallWalking[target] = true;
			}
	      	if(FF2_HasAbility(boss, this_plugin_name, "ff2_saxtonreflect"))
	        	Sub_SaxtonReflect[target] = true;
			if(FF2_HasAbility(boss, this_plugin_name, "ff2_CBS_abilities"))
		    	CBS_Abilities[target] = true;
			if(FF2_HasAbility(boss, this_plugin_name, "ff2_lastmanstanding"))
				AllLastmanStanding = true;
			if(FF2_HasAbility(boss, this_plugin_name, "ff2_attackanddef"))
				AttackAndDef = true;
			if(FF2_HasAbility(boss, this_plugin_name, "ff2_travis"))
				IsTravis[target] = true;

			if(FF2_HasAbility(boss, this_plugin_name, "ff2_tank"))
			{
				IsTank[target] = true;
				SetOverlay(target, "Effects/combine_binocoverlay");

				char model[PLATFORM_MAX_PATH];
				float StartAngle[3];
				float tempAngle[3];
				GetClientEyeAngles(target, StartAngle);

				GetClientModel(target, model, sizeof(model));
				SetVariantString(model);
				AcceptEntityInput(target, "SetCustomModel", target);

				char Input[100];

				tempAngle[0] = 0.0;
				tempAngle[1] = StartAngle[1];
				tempAngle[2] = StartAngle[2];

				Format(Input, sizeof(Input), "%.1f %.1f %.1f", tempAngle[0], tempAngle[1], tempAngle[2]);

				SetVariantBool(true);
				AcceptEntityInput(target, "SetCustomModelRotates", target);

				SetVariantString(Input);
				AcceptEntityInput(target, "SetCustomModelRotation", target);

				RequestFrame(ClassAniTimer, target);

				SDKHook(target, SDKHook_StartTouch, OnTankTouch);
				SDKHook(target, SDKHook_Touch, OnTankTouch);
			}
			/*
			if(FF2_HasAbility(boss, this_plugin_name, "ff2_vagineer_passive"))
			{
				enableVagineer = true;
				for(int spTarget=1; spTarget <= MaxClients; spTarget++)
				{
					if(!IsValidClient(spTarget) || !IsPlayerAlive(spTarget))
					{
						entSpriteRef[spTarget] = -1;
						continue;
					}

					float clientPos[3];
					GetClientEyePosition(spTarget, clientPos);

					int ent = CreateViewEntity(spTarget, clientPos);
					if(IsValidEntity(ent))
					{
						entSpriteRef[spTarget] = EntIndexToEntRef(ent);
					}
				}
			}
			*/
		}

  }


	if(AllLastmanStanding)
	{
		for(client=1; client<=MaxClients; client++)
	    {
	  	 if(IsClientInGame(client) && IsPlayerAlive(client) && !IsBossTeam(client))
	    	{
	    		FF2_EnablePlayerLastmanStanding(client);
	    	}
	    }
	}
}

public Action OnTankTouch(int entity, int other)
{
	if (other > 0 && other <= MaxClients)
	{
		if(IsTank[entity])
		{
			SDKHooks_TakeDamage(other, entity, entity, 30.0, DMG_SLASH, -1);
		}
	}
}

public bool TraceRayNoPlayer(int iEntity, int iMask, any iData)
{
    return (!IsValidClient(iEntity));
}

public void ClassAniTimer(int client)
{
	if(IsClientInGame(client))
	{
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	}

}

public Action FF2_OnTakePercentDamage(int victim, int &attacker, PercentDamageType:damageType, float &damage)
{
	if(IsTank[victim])
	{
		damage *= 0.6;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

void SetOverlay(int client, const char[] overlay)						// changes a client's screen overlay (requires clientcommand, they could disable so, enforce with smac or something if you care.)
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	ClientCommand(client, "r_screenoverlay \"%s\"", overlay);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") | FCVAR_CHEAT);
}

int CreateViewEntity(int client, float pos[3])
{
	int entity;
	if((entity = CreateEntityByName("env_sprite")) != -1)
	{
		DispatchKeyValue(entity, "model", SPRITE);
		DispatchKeyValue(entity, "renderamt", "0");
		DispatchKeyValue(entity, "rendercolor", "0 0 0");
		DispatchSpawn(entity);

		float angle[3];
		GetClientEyeAngles(client, angle);

		TeleportEntity(entity, pos, angle, NULL_VECTOR);
		TeleportEntity(client, NULL_VECTOR, angle, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client, entity, 0);
		SetClientViewEntity(client, entity);
		return entity;
	}
	return -1;
}

stock int SpawnRocket(int client, float origin[3], float angles[3], float velocity[3], float damage, bool allowcrit)
{
	int ent=CreateEntityByName("tf_projectile_rocket");
	if(!IsValidEntity(ent)){
		 return -1;
		}
	int clientTeam = GetClientTeam(client);
	int damageOffset = FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4;

	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(ent, Prop_Send, "m_bCritical", allowcrit ? 1 : 0);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", clientTeam);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 4);
	SetEntProp(ent, Prop_Data, "m_takedamage", 0);
	// SetEntPropEnt(ent, Prop_Send, "m_nForceBone", -1);
	SetEntPropVector(ent, Prop_Send, "m_vecMins", Float:{0.0,0.0,0.0});
	SetEntPropVector(ent, Prop_Send, "m_vecMaxs", Float:{0.0,0.0,0.0});
	SetEntDataFloat(ent, damageOffset, damage); // set damage
	SetVariantInt(clientTeam);
	AcceptEntityInput(ent, "TeamNum", -1, -1, 0);
	SetVariantInt(clientTeam);
	AcceptEntityInput(ent, "SetTeam", -1, -1, 0);
	DispatchSpawn(ent);
	SetEntPropEnt(ent, Prop_Send, "m_hOriginalLauncher", GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"));
	SetEntPropEnt(ent, Prop_Send, "m_hLauncher", GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"));

	TeleportEntity(ent, origin, angles, velocity);

	return ent;
}

public void GetEyeEndPos(int client, float max_distance, float endPos[3])
{
	if(IsClientInGame(client))
	{
		if(max_distance<0.0)
			max_distance=0.0;
		float PlayerEyePos[3];
		float PlayerAimAngles[3];
		GetClientEyePosition(client,PlayerEyePos);
		GetClientEyeAngles(client,PlayerAimAngles);
		float PlayerAimVector[3];
		GetAngleVectors(PlayerAimAngles,PlayerAimVector,NULL_VECTOR,NULL_VECTOR);
		if(max_distance>0.0){
			ScaleVector(PlayerAimVector,max_distance);
		}
		else{
			ScaleVector(PlayerAimVector,3000.0);
		}
      AddVectors(PlayerEyePos,PlayerAimVector,endPos);
	}
}

public Action OnTouch(int entity, int other)
{
	if(!IsEntityCanReflect[entity]) return Plugin_Continue;

	decl Float:vOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);

	decl Float:vAngles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);

	decl Float:vVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);

	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);

	if(!TR_DidHit(trace))
	{
		CloseHandle(trace);
		return Plugin_Continue;
	}

	decl Float:vNormal[3];
	TR_GetPlaneNormal(trace, vNormal);

	//PrintToServer("Surface Normal: [%.2f, %.2f, %.2f]", vNormal[0], vNormal[1], vNormal[2]);

	CloseHandle(trace);

	new Float:dotProduct = GetVectorDotProduct(vNormal, vVelocity);

	ScaleVector(vNormal, dotProduct);
	ScaleVector(vNormal, 2.0);

	decl Float:vBounceVec[3];
	SubtractVectors(vVelocity, vNormal, vBounceVec);

	decl Float:vNewAngles[3];
	GetVectorAngles(vBounceVec, vNewAngles);

	//PrintToServer("Angles: [%.2f, %.2f, %.2f] -> [%.2f, %.2f, %.2f]", vAngles[0], vAngles[1], vAngles[2], vNewAngles[0], vNewAngles[1], vNewAngles[2]);
	//PrintToServer("Velocity: [%.2f, %.2f, %.2f] |%.2f| -> [%.2f, %.2f, %.2f] |%.2f|", vVelocity[0], vVelocity[1], vVelocity[2], GetVectorLength(vVelocity), vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));

	TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);
	g_nEntityBounce[entity]++;

	SDKUnhook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public bool TEF_ExcludeEntity(int entity, int contentsMask, any data)
{
	return (entity != data);
}

stock bool IsBossTeam(int client)
{
    return FF2_GetBossTeam() == GetClientTeam(client);
}

stock bool IsValidClient(int client)
{
    return (0<client && client<=MaxClients && IsClientInGame(client));
}
