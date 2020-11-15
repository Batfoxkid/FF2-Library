/*
"laser_attack"
arg0은 무조건 0
arg1: 레이저 지속시간
arg2: 레이저 경고 시간
arg3: 레이저 범위
arg4: 레이저의 공격력 (0.1초 간격)
arg5: 지진효과.
arg6: 사운드 경로 (경고)
arg7: 번개 효과 모델(?) 경로 (자세히 알지 못하는 부분입니다..)
arg8: 사운드 경로(발사 중)
arg9: 번개 효과 모델(?) 경로 (arg7이랑은 다른 부분입니다.)
arg10: 레이저에 불 효과?
arg11: 레이저 범위
arg12: 건물 데미지 보너스
arg13: 플레이어 피격 사운드
arg14: 레이저 최소 크기(넓이?) (기본 0.1)
arg15: 레이저 최대 크기(넓이?) (기본 6.0)

arg20:Red (레이저 색상)(0 - 255)
arg21:Green (레이저 색상)(0 - 255)
arg22:Blue (레이저 색상)(0 - 255)
arg23: 레이저 투명도(완전 투명: 0 - 완전 잘 보임: 255)

필독: arg7과 arg9는 미적용시 기본 모델로 바뀝니다.
필독: 사용하려는 사운드는 모두 다운로드와 캐시를 콘픽에서 하셔야 합니다!
필독: 레이저가 너무 클 경우 보스 본인은 레이저가 안보일 수도 있어요!
*/
#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <freak_fortress_2>
#include <sdkhooks>

int BeamSprite[MAXPLAYERS+1], HaloSprite[MAXPLAYERS+1], GlowSprite[MAXPLAYERS+1];
// bool canSpawnParticle;

float clientRageBeamTime[MAXPLAYERS+1];
float clientRageBeamWarmTime[MAXPLAYERS+1];
Handle clientRageTimer[MAXPLAYERS+1]=INVALID_HANDLE;

public Plugin myinfo=
{
    name="Freak Fortress 2 : For touhou users.",
    author="Nopied",
    description="....",
    version="9.9",
};

public void OnPluginStart2()
{
  return; // 아무 쓸모도 없지만, 컴파일러가 요구함.
}

public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
{
  if(!strcmp(abilityName, "laser_attack"))
  {
    int client=GetClientOfUserId(FF2_GetBossUserId(boss));
    char path[PLATFORM_MAX_PATH];
    FF2_GetAbilityArgumentString(boss, this_plugin_name, "laser_attack", 7, path, sizeof(path)); // "materials/sprites/lgtning.vmt"
    if(path[0] == '\0') strcopy(path, sizeof(path), "materials/sprites/lgtning.vmt");
    BeamSprite[client]=PrecacheModel(path);

    FF2_GetAbilityArgumentString(boss, this_plugin_name, "laser_attack", 9, path, sizeof(path)); // "materials/sprites/halo01.vmt"
    if(path[0] == '\0') strcopy(path, sizeof(path), "materials/sprites/halo01.vmt");
    HaloSprite[client]=PrecacheModel(path);

    Rage_Beam(boss);
  }
}

Rage_Beam(int boss)
{
  int client=GetClientOfUserId(FF2_GetBossUserId(boss));
  char path[PLATFORM_MAX_PATH];
  FF2_GetAbilityArgumentString(boss, this_plugin_name, "laser_attack", 6, path, sizeof(path));
  EmitSoundToAll(path);

  if(clientRageBeamTime[client]<=0.0)
    clientRageTimer[client]=CreateTimer(0.1, OnBeam, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

  clientRageBeamTime[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 1, 10.0);
  clientRageBeamWarmTime[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 2, 1.5);

  SetEntityMoveType(client, MOVETYPE_NONE);
  TF2_AddCondition(client, TFCond_Ubercharged, clientRageBeamTime[client]+clientRageBeamWarmTime[client]);
}

public Action OnBeam(Handle timer, int client)
{
  if(FF2_GetRoundState() != 1 || !IsClientInGame(client) || !IsPlayerAlive(client) || clientRageBeamTime[client]<=0.0)
  {
      char path[PLATFORM_MAX_PATH];
/*
      FF2_GetAbilityArgumentString(boss, this_plugin_name, "laser_attack", 6, path, sizeof(path));
      for(int target=1; target<=MaxClients; target++)
      {
          if(IsClientInGame(target))
            StopSound(target, SNDCHAN_AUTO, path);
      } //TODO: 이게 필요해..?
*/

      FF2_GetAbilityArgumentString(FF2_GetBossIndex(client), this_plugin_name, "laser_attack", 8, path, sizeof(path));
      for(int target=1; target<=MaxClients; target++)
      {
          if(IsClientInGame(target))
            StopSound(target, SNDCHAN_AUTO, path);
      }

      clientRageBeamTime[client]=0.0;
      clientRageBeamWarmTime[client]=0.0;
      SetEntityMoveType(client, MOVETYPE_WALK);
      clientRageTimer[client]=INVALID_HANDLE;
      return Plugin_Stop;
  }

  int boss=FF2_GetBossIndex(client);
  char path[PLATFORM_MAX_PATH];

  if(FF2_GetAbilityArgument(boss, this_plugin_name, "laser_attack", 5, 1))
    EarthQuakeEffect(client);

  if(clientRageBeamWarmTime[client]>0.0){
    clientRageBeamWarmTime[client]-=0.1;
    return Plugin_Continue;
  }
  else if(clientRageBeamWarmTime[client]<=0.0 && clientRageBeamWarmTime[client] != -1.0){
    FF2_GetAbilityArgumentString(boss, this_plugin_name, "laser_attack", 8, path, sizeof(path));
    EmitSoundToAll(path);

    clientRageBeamWarmTime[client]=-1.0;
  }

  clientRageBeamTime[client]-=0.1;

  float clientPos[3];
  float clientEyeAngles[3];
  float end_pos[3];
  float damage=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 4, 12.0);
  float range=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 11, 50.0);
  int rgba[4];

  rgba[0]=FF2_GetAbilityArgument(boss, this_plugin_name, "laser_attack", 20, 0);
  rgba[1]=FF2_GetAbilityArgument(boss, this_plugin_name, "laser_attack", 21, 255);
  rgba[2]=FF2_GetAbilityArgument(boss, this_plugin_name, "laser_attack", 22, 0);
  rgba[3]=FF2_GetAbilityArgument(boss, this_plugin_name, "laser_attack", 23, 255);

  GetClientEyePosition(client, clientPos);
  GetClientEyeAngles(client, clientEyeAngles);
  GetEyeEndPos(client, 0.0, end_pos);

  clientPos[2]-=28.0;
  clientPos[1]-=14.0;
  clientPos[0]-=17.0;

  TE_SetupBeamPoints(clientPos, end_pos, BeamSprite[client], HaloSprite[client], 10, 50, FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 14, 0.1)
  , FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 15, 6.0)
  , 25.0, 0, 64.0, rgba, 40);
  TE_SendToAll();

/*
    // 파티클 구문

  float particlePos[3];
  float particleTime=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 15, 0.12);
  canSpawnParticle=true;
  FF2_GetAbilityArgumentString(boss, this_plugin_name, "laser_attack", 14, path, sizeof(path));

  if(path[0] != '\0')
  {
      Handle trace;
      trace = TR_TraceRayFilterEx(clientPos, clientEyeAngles, MASK_ALL, RayType_Infinite, TraceAnything);
      TR_GetEndPosition(particlePos, trace);

      while(!TR_PointOutsideWorld(particlePos))
      {
          Handle trace2;
          if(canSpawnParticle &&)
          {
            CreateTimer(particleTime, RemoveEntity, AttachParticle(client, path, particlePos), TIMER_FLAG_NO_MAPCHANGE);
            canSpawnParticle=false;
          }
          // CreateTimer(particleTime, RemoveEntity, AttachParticle(client, path, particlePos, false), TIMER_FLAG_NO_MAPCHANGE);

          trace2 = TR_TraceRayFilterEx(particlePos, clientEyeAngles, MASK_ALL, RayType_Infinite, TraceAnything);
          TR_GetEndPosition(particlePos, trace2);
          CloseHandle(trace2);
      }
  }
*/

  float targetPos[3];
  float targetEndPos[3];
  FF2_GetAbilityArgumentString(boss, this_plugin_name, "laser_attack", 13, path, sizeof(path));

  for(int target=1; target<=MaxClients; target++)
  {
    if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) != FF2_GetBossTeam())
    {
      GetClientEyePosition(target, targetPos);
      GetEyeEndPos(client, GetVectorDistance(clientPos, targetPos), targetEndPos);

      if(GetVectorDistance(targetPos, targetEndPos) <= range && !TF2_IsPlayerInCondition(target, TFCond_Ubercharged))
      {
        SDKHooks_TakeDamage(target, client, client, damage, DMG_SLASH|DMG_SHOCK|DMG_ENERGYBEAM, -1, _, targetEndPos);

        if(path[0] != '\0'){
            EmitSoundToAll(path, target, _, _, _, _, _, target, targetPos);
            EmitSoundToAll(path, target, _, _, _, _, _, target, targetPos);
        }

        if(FF2_GetAbilityArgument(boss, this_plugin_name, "laser_attack", 10, 1))
            TF2_IgnitePlayer(target, client);
      }
    }
  }

  int ent = -1;

  while((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1) // FIXME: 한 문장 안에 다 넣으면 스크립트 처리에 문제가 생김.
  {
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetPos);
    GetEyeEndPos(client, GetVectorDistance(clientPos, targetPos), targetEndPos);

    if(GetVectorDistance(targetPos, targetEndPos) <= range)
    {
      SDKHooks_TakeDamage(ent, client, client, damage*FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 12, 1.5), DMG_SLASH|DMG_SHOCK|DMG_ENERGYBEAM|DMG_BURN, -1, _, targetEndPos);
    }
  }

  while((ent = FindEntityByClassname(ent, "obj_dispenser")) != -1)  // FIXME: 한 문장 안에 다 넣으면 스크립트 처리에 문제가 생김.
  {
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetPos);
    GetEyeEndPos(client, GetVectorDistance(clientPos, targetPos), targetEndPos);

    if(GetVectorDistance(targetPos, targetEndPos) <= range)
    {
      SDKHooks_TakeDamage(ent, client, client, damage*FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 12, 1.5), DMG_SLASH|DMG_SHOCK|DMG_ENERGYBEAM|DMG_BURN, -1, _, targetEndPos);
    }
  }


  while((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1) // FIXME: 한 문장 안에 다 넣으면 스크립트 처리에 문제가 생김.
  {
    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", targetPos);
    GetEyeEndPos(client, GetVectorDistance(clientPos, targetPos), targetEndPos);

    if(GetVectorDistance(targetPos, targetEndPos) <= range)
    {
      SDKHooks_TakeDamage(ent, client, client, damage*FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "laser_attack", 12, 1.5), DMG_SLASH|DMG_SHOCK|DMG_ENERGYBEAM|DMG_BURN, -1, _, targetEndPos);
    }
  }

  return Plugin_Continue;
}

public Action Timer_RemoveEntity(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(IsValidEntity(entity))
	{
		RemoveEntity(entity);
	}
}

public bool TraceAnything(int entity, int contentsMask)
{
    return true;
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

void EarthQuakeEffect(int client)
{
    int flags = GetCommandFlags("shake") & (~FCVAR_CHEAT);
    SetCommandFlags("shake", flags);

    FakeClientCommand(client, "shake");

    flags = GetCommandFlags("shake") | (FCVAR_CHEAT);
    SetCommandFlags("shake", flags);
}

/*
int AttachParticle(int entity, char[] particleType, float position[3], bool attach=true)
{
	int particle=CreateEntityByName("info_particle_system");

	char targetName[128];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
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
*/
