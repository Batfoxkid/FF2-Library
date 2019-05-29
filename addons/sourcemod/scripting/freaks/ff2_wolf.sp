#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define SOUND_SHIELD "weapons/medi_shield_deploy.wav"

//int PlayerShield[MAXPLAYERS+1];
//

public Plugin:myinfo=
{
	name="Freak Fortress 2: Wolf's Abilities",
	author="Nopied◎",
	description="",
	version="EE",
};

public void OnPluginStart2()
{
  if(!IsSoundPrecached(SOUND_SHIELD))
    PrecacheSound(SOUND_SHIELD);
  HookEvent("medigun_shield_blocked_damage", OnBlocked, EventHookMode_Post);
}

public Action OnBlocked(Handle event, const char[] name, bool dont)
{
  int boss=FF2_GetBossIndex(GetClientOfUserId(GetEventInt(event, "userid")));
  if(FF2_HasAbility(boss, this_plugin_name, "wolf_deflecter"))
  {
		int client=GetClientOfUserId(GetEventInt(event, "userid"));
		float abilityTime=FF2_GetAbilityDuration(boss);
		float damage = GetEventFloat(event, "damage");
		/*
		FF2_SetBossCharge(boss, 0, FF2_GetBossCharge(boss, 0)+(GetEventFloat(event, "damage")*100.0/float(FF2_GetBossRageDamage(boss))));
		if(FF2_GetBossCharge(boss, 0) > 100.0)
			FF2_SetBossCharge(boss, 0, 100.0);


		*/
		if(abilityTime <= 0.0)
		{
			if(GetEntPropFloat(client, Prop_Send, "m_flRageMeter") > 15.0)
				SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 15.0);
			return Plugin_Continue;
		}

		float eyePos[3];
		float clientPos[3];
		GetClientEyePosition(client, clientPos);

		float distance;

		for(int target = 1;  target < MaxClients; target++)
		{
			if(IsValidClient(target))
			{
				if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(client) != GetClientTeam(target))
				{
					float targetPos[3];
					GetClientEyePosition(target, targetPos);
					distance = GetVectorDistance(clientPos, targetPos);
					GetEyeEndPos(client, distance, eyePos);

					if(GetVectorDistance(targetPos, eyePos) <= 100.0 && CanSeeTarget(client, target))
					{
						SDKHooks_TakeDamage(target,
						  GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon"),
						  client,
						  (damage*(-((GetVectorDistance(targetPos, eyePos)-100.0))*0.01))*1.3);
					}
				  }
			 }
		}

		FF2_SetAbilityDuration(boss, abilityTime-3.0);
  }
	return Plugin_Continue;
}

stock bool CanSeeTarget(int client, int target)
{
	float clientPos[3];
	float targetPos[3];
	Handle trace;
	bool didhit = false;

	GetClientEyePosition(client, clientPos);
	GetClientEyePosition(target, targetPos);

	trace = TR_TraceRayFilterEx(clientPos, targetPos, MASK_SHOT, RayType_EndPoint, TraceRayPlayerOnly, client);

	didhit = TR_DidHit(trace);
	CloseHandle(trace);

	return didhit;
}

public Action FF2_OnAbilityTimeEnd(int boss, int slot)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	if(FF2_HasAbility(boss, this_plugin_name, "wolf_deflecter"))
	{
		SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 22.5);
	}
}

public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
{
  if(!strcmp(abilityName, "wolf_deflecter"))
  {
		int client=GetClientOfUserId(FF2_GetBossUserId(boss));
    // PlayerShield[client]=SpawnShield(client);
		SpawnShield(client);
  }
}

stock int SpawnShield(int client)
{
  int shield = CreateEntityByName("entity_medigun_shield");
  if(IsValidEntity(shield))
  {
    SetEntPropEnt(shield, Prop_Send, "m_hOwnerEntity", client);
    SetEntProp(shield, Prop_Send, "m_iTeamNum", GetClientTeam(client));
    SetEntProp(shield, Prop_Data, "m_iInitialTeamNum", GetClientTeam(client));
    if (GetClientTeam(client) == _:TFTeam_Red) DispatchKeyValue(shield, "skin", "0");
    else if (GetClientTeam(client) == _:TFTeam_Blue) DispatchKeyValue(shield, "skin", "1");
    SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 99999999.9);
    SetEntProp(client, Prop_Send, "m_bRageDraining", 1);
    DispatchSpawn(shield);
    EmitSoundToClient(client, "weapons/medi_shield_deploy.wav", shield);
    SetEntityModel(shield, "models/props_mvm/mvm_player_shield2.mdl");
	SDKHook(shield, SDKHook_StartTouch, OnStartTouch);
	return shield;
  }
	return -1;
}

public Action OnStartTouch(int entity, int other)
{
	if (other <= MaxClients)
		return Plugin_Continue;

	char classname[60];
	GetEntityClassname(other, classname, sizeof(classname));
	// Debug(classname);

	if(GetEntPropEnt(other, Prop_Send, "m_hOwnerEntity") != GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")
	&& !StrContains(classname, "tf_projectile_"))
	{
		float RocketPos[3];
	  	float RocketAng[3];
	  	float RocketVec[3];
	  	float TargetPos[3];
	  	float TargetVec[3];
	  	float MiddleVec[3];
		// Debug("ppp");

	  	GetPlayerEyeEnd(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), TargetPos);

	  	GetEntPropVector( other, Prop_Data, "m_vecAbsOrigin", RocketPos );
	  	GetEntPropVector( other, Prop_Data, "m_angRotation", RocketAng );
	  	GetEntPropVector( other, Prop_Data, "m_vecAbsVelocity", RocketVec );

	  	float RocketSpeed = GetVectorLength( RocketVec );
	  	SubtractVectors( TargetPos, RocketPos, TargetVec );
	  	NormalizeVector( TargetVec, RocketVec );
	  	AddVectors( RocketVec, TargetVec, MiddleVec );
	  	NormalizeVector( RocketVec, RocketVec );
	  	GetVectorAngles( RocketVec, RocketAng );
	  	//SetEntPropVector( other, Prop_Data, "m_angRotation", RocketAng );

	  	ScaleVector( RocketVec, RocketSpeed );
		TeleportEntity(other, NULL_VECTOR, RocketAng, RocketVec);

		SetEntPropEnt(other, Prop_Send, "m_hOwnerEntity", GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
		SetEntProp(other, Prop_Send, "m_iTeamNum", GetEntProp(entity, Prop_Send, "m_iTeamNum"));

		if(HasEntProp(other, Prop_Send, "m_bTouched"))
			SetEntProp(other, Prop_Send, "m_bTouched", 0);

		if(HasEntProp(other, Prop_Send, "m_iDeflected"))
			SetEntProp(other, Prop_Send, "m_iDeflected", 1);

		int boss = FF2_GetBossIndex(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
		FF2_SetAbilityDuration(boss, FF2_GetAbilityDuration(boss) - 3.0);

		return Plugin_Handled;
	}
	return Plugin_Continue;

	// SDKHook(entity, SDKHook_Touch, OnTouch);
}
/*
public Action OnTouch(int entity, int other)
{
	char classname[60];
	GetEntityClassname(other, classname, sizeof(classname));
	// Debug(classname);

	if(GetEntPropEnt(other, Prop_Send, "m_hOwnerEntity") != GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")
	&& !StrContains(classname, "tf_projectile_"))
	{
		float RocketPos[3];
  		float RocketAng[3];
  		float RocketVec[3];
  		float TargetPos[3];
  		float TargetVec[3];
  		float MiddleVec[3];
		// Debug("ppp");

  		GetPlayerEyeEnd(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), TargetPos);

  		GetEntPropVector( other, Prop_Data, "m_vecAbsOrigin", RocketPos );
  		GetEntPropVector( other, Prop_Data, "m_angRotation", RocketAng );
  		GetEntPropVector( other, Prop_Data, "m_vecAbsVelocity", RocketVec );

  		float RocketSpeed = GetVectorLength( RocketVec );
  		SubtractVectors( TargetPos, RocketPos, TargetVec );

  		NormalizeVector( TargetVec, RocketVec );

  		AddVectors( RocketVec, TargetVec, MiddleVec );

  		NormalizeVector( RocketVec, RocketVec );

  		GetVectorAngles( RocketVec, RocketAng );
  		//SetEntPropVector( other, Prop_Data, "m_angRotation", RocketAng );

  		ScaleVector( RocketVec, RocketSpeed );

		TeleportEntity(other, NULL_VECTOR, RocketAng, RocketVec);

		SetEntPropEnt(other, Prop_Send, "m_hOwnerEntity", GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
	    SetEntProp(other, Prop_Send, "m_iTeamNum", GetEntProp(entity, Prop_Send, "m_iTeamNum"));

		if(HasEntProp(other, Prop_Send, "m_bTouched"))
			SetEntProp(other, Prop_Send, "m_bTouched", 0);

		if(HasEntProp(other, Prop_Send, "m_iDeflected"))
			SetEntProp(other, Prop_Send, "m_iDeflected", 1);

		int boss = FF2_GetBossIndex(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"));
		FF2_SetAbilityDuration(boss, FF2_GetAbilityDuration(boss) - 3.0);

		return Plugin_Handled;
	}
	return Plugin_Continue;
}
*/

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

public int GetPlayerEye(int client)
{
	float vAngles[3]; float vOrigin[3];
	float tempAngles[3];
	Handle trace;
	int damaged;

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	trace = TR_TraceRayFilterEx(vOrigin, tempAngles, MASK_SHOT, RayType_Infinite, TraceRayPlayerOnly, client);

	if(TR_DidHit(trace))
	{
		damaged = TR_GetEntityIndex(trace);
		CloseHandle(trace);
		return damaged;
	}
	CloseHandle(trace);

	return -1;
}

public void GetPlayerEyeEnd(int client, float end[3])
{
	float vAngles[3]; float vOrigin[3];

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceRayPlayerOnly, client);

	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(end, trace);
	}
	CloseHandle(trace);
}

public bool TraceRayPlayerOnly(int iEntity, int iMask, any iData)
{
    return (IsValidClient(iEntity) && IsValidClient(iData) && iEntity != iData);
}

stock bool IsValidClient(client)
{
	return (0 < client && client < MaxClients && IsClientInGame(client));
}
