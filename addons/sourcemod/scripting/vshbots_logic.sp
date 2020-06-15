#include <sdktools>
#include <tf2_stocks>
#pragma newdecls required

Handle AttackTimer;
Handle Attack2Timer;

public Plugin myinfo = 
{
	name = "VSH/FF2 Bots[logic]",
	author = "tRololo312312",
	description = "Gamemode logic for TFBots",
	version = "1.1",
	url = "http://steamcommunity.com/profiles/76561198039186809"
}

public void OnMapStart()
{
	CreateTimer(305.0, InfoTimer,_,TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action InfoTimer(Handle timer)
{
	PrintToChatAll("This server is using VSH/FF2 Bots plugin by tRololo312312");
}

void moveForward(float vel[3], float MaxSpeed)
{
	vel[0] = MaxSpeed;
}

void moveBackwards(float vel[3],float MaxSpeed)
{
	vel[0] = -MaxSpeed;
}

void moveSide(float vel[3],float MaxSpeed)
{
	vel[1] = MaxSpeed;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, 
							float vel[3], float angles[3], int& weapon, 
							int &subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(IsValidClient(client))
	{
		if(IsFakeClient(client))
		{
			if(IsPlayerAlive(client))
			{
				static float camangle[3], clientEyes[3], targetEyes[3];
				GetClientEyePosition(client, clientEyes);
				TFClassType class = TF2_GetPlayerClass(client);
				int stunFlag = GetEntData(client, FindSendPropInfo("CTFPlayer","m_iStunFlags"));
				int team = GetClientTeam(client);
				int Ent = Client_GetClosest(clientEyes, client);
				
				if(TF2_IsPlayerInCondition(client, TFCond_Cloaked))
				{
					int iMeleeEnt = GetPlayerWeaponSlot(client, 2);
					SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iMeleeEnt);
				}
				
				if(class == TFClass_Medic && team == 2)
				{
					if(IsWeaponSlotActive(client, 0))
					{
						buttons |= IN_ATTACK;
					}
					if(TF_GetUberLevel(client)>=100.00)
					{
						buttons |= IN_ATTACK2;
					}
				}
				
				if(team == 3)
				{
					SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", 340.0);
				}
				
				if(Ent != -1)
				{
					if(team == 2)
					{
						static float vec[3], angle[3];
						GetClientAbsOrigin(Ent, targetEyes);
						GetEntPropVector(Ent, Prop_Data, "m_angRotation", angle);
						if(class == TFClass_Soldier && IsWeaponSlotActive(client, 0) || class == TFClass_DemoMan)
						{
							targetEyes[2] += 2.5;
							targetEyes[1] += GetRandomFloat(-20.0, 20.0);
						}
						else
						{
							targetEyes[2] += GetRandomFloat(10.0, 60.0);
							targetEyes[1] += GetRandomFloat(-20.0, 20.0);
						}
						MakeVectorFromPoints(targetEyes, clientEyes, vec);
						GetVectorAngles(vec, camangle);
						camangle[0] *= -1.0;
						camangle[1] += 180.0;
						ClampAngle(camangle);
						TeleportEntity(client, NULL_VECTOR, camangle, NULL_VECTOR);
						
						if(AttackTimer == INVALID_HANDLE)
						{
							AttackTimer = CreateTimer(1.5, ResetAttackTimer);
						}
						else if(class != TFClass_Pyro)
						{
							if(TF2_IsPlayerInCondition(Ent, TFCond_Ubercharged))
							{
								Handle WallBehind;
								static float lookangle[3], ClientLocation[3], WallBehindVec[3], lookDir[3];
								moveBackwards(vel,400.0);
								GetClientEyeAngles(client, lookangle);
								GetClientEyePosition(client, ClientLocation);
								lookangle[0] = 0.0;
								lookangle[2] = 0.0;
								lookangle[1] += 200.0;
								GetAngleVectors(lookangle, lookDir, NULL_VECTOR, NULL_VECTOR);
								ScaleVector(lookDir, 50.0);
								AddVectors(ClientLocation, lookDir, WallBehindVec);
								WallBehind = TR_TraceRayFilterEx(ClientLocation,WallBehindVec,MASK_PLAYERSOLID,RayType_EndPoint,Filter);
								if(TR_DidHit(WallBehind))
								{
									TR_GetEndPosition(WallBehindVec, WallBehind);
									float wallDistance;
									wallDistance = GetVectorDistance(ClientLocation,WallBehindVec);
									if(wallDistance <60.0)
									{
										moveSide(vel,400.0);
									}
								}
								
								delete WallBehind;
							}
							else
							{
								buttons |= IN_ATTACK;
							}
						}

						float location_check[3];
						GetClientAbsOrigin(client, location_check);

						float chainDistance;
						chainDistance = GetVectorDistance(location_check,targetEyes);
						
						if(TF2_IsPlayerInCondition(client, TFCond_Ubercharged))
						{
							moveForward(vel,400.0);
						}
						else if(chainDistance <400.0)
						{
							if(IsWeaponSlotActive(client, 2))
							{
								moveForward(vel,400.0);
							}
							else
							{
								Handle WallBehind;
								static float lookangle[3], ClientLocation[3], WallBehindVec[3], lookDir[3];
								moveBackwards(vel,400.0);
								GetClientEyeAngles(client, lookangle);
								GetClientEyePosition(client, ClientLocation);
								lookangle[0] = 0.0;
								lookangle[2] = 0.0;
								lookangle[1] += 200.0;
								GetAngleVectors(lookangle, lookDir, NULL_VECTOR, NULL_VECTOR);
								ScaleVector(lookDir, 50.0);
								AddVectors(ClientLocation, lookDir, WallBehindVec);
								WallBehind = TR_TraceRayFilterEx(ClientLocation,WallBehindVec,MASK_PLAYERSOLID,RayType_EndPoint,Filter);
								if(TR_DidHit(WallBehind))
								{
									TR_GetEndPosition(WallBehindVec, WallBehind);
									float wallDistance;
									wallDistance = GetVectorDistance(ClientLocation,WallBehindVec);
									if(wallDistance <60.0)
									{
										moveSide(vel,400.0);
									}
								}
								
								delete WallBehind;
							}
							
							if(class == TFClass_Pyro)
							{
								buttons |= IN_ATTACK;
							}
							if(class == TFClass_Spy)
							{
								buttons |= IN_ATTACK2;
							}
						}
						
						if(stunFlag == TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_NOSOUNDOREFFECT)
						{
							Handle WallBehind;
							moveBackwards(vel,400.0);
							static float lookangle[3], ClientLocation[3], WallBehindVec[3], lookDir[3];
							moveBackwards(vel,400.0);
							GetClientEyeAngles(client, lookangle);
							GetClientEyePosition(client, ClientLocation);
							lookangle[0] = 0.0;
							lookangle[2] = 0.0;
							lookangle[1] += 200.0;
							GetAngleVectors(lookangle, lookDir, NULL_VECTOR, NULL_VECTOR);
							ScaleVector(lookDir, 50.0);
							AddVectors(ClientLocation, lookDir, WallBehindVec);
							WallBehind = TR_TraceRayFilterEx(ClientLocation,WallBehindVec,MASK_PLAYERSOLID,RayType_EndPoint,Filter);
							if(TR_DidHit(WallBehind))
							{
								TR_GetEndPosition(WallBehindVec, WallBehind);
								float wallDistance;
								wallDistance = GetVectorDistance(ClientLocation,WallBehindVec);
								if(wallDistance <60.0)
								{
									moveSide(vel,400.0);
								}
							}
							
							delete WallBehind;
						}
						
						if(TF2_IsPlayerInCondition(client, TFCond_Ubercharged) && class == TFClass_Pyro)
						{
							buttons |= IN_ATTACK;
						}
						else if(class == TFClass_Pyro && chainDistance <150.0)
						{
							buttons |= IN_ATTACK2;
						}
					}
					if(team == 3)
					{
						static float vec[3], angle[3];
						GetClientAbsOrigin(Ent, targetEyes);
						float location_check[3];
						GetClientAbsOrigin(client, location_check);
						float chainDistance;
						chainDistance = GetVectorDistance(location_check,targetEyes);
						GetEntPropVector(Ent, Prop_Data, "m_angRotation", angle);
						if(chainDistance <150.0)
						{
							targetEyes[2] += 33.5;
						}
						else
						{
							if(IsWeaponSlotActive(client, 0) || IsWeaponSlotActive(client, 1))
							{
								targetEyes[2] += 33.5;
							}
							else
							{
								targetEyes[2] += 1300.0;
							}
						}
						MakeVectorFromPoints(targetEyes, clientEyes, vec);
						GetVectorAngles(vec, camangle);
						camangle[0] *= -1.0;
						camangle[1] += 180.0;
						ClampAngle(camangle);

						if(Attack2Timer == INVALID_HANDLE)
						{
							FakeClientCommand(client, "voicemenu 0 0");
							Attack2Timer = CreateTimer(1.0, ResetAttack2Timer);
						}
						else
						{
							buttons |= IN_ATTACK;
						}
						
						if(chainDistance <400.0)
						{
							moveForward(vel,400.0);
						}
						TeleportEntity(client, NULL_VECTOR, camangle, NULL_VECTOR);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action ResetAttackTimer(Handle timer)
{
	AttackTimer = INVALID_HANDLE;
}

public Action ResetAttack2Timer(Handle timer)
{
	Attack2Timer = INVALID_HANDLE;
}

bool IsValidClient( int client ) 
{
	if(!(1 <= client <= MaxClients ) || !IsClientInGame(client)) 
		return false; 
	return true; 
}

stock int GetHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

stock bool IsWeaponSlotActive(int iClient, int iSlot)
{
    return GetPlayerWeaponSlot(iClient, iSlot) == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

stock int Client_GetClosest(float vecOrigin_center[3], const int client)
{
	static float vecOrigin_edict[3];
	float distance = -1.0;
	int closestEdict = -1;
	for(int i=1;i<=MaxClients;i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || (i == client))
			continue;
		GetEntPropVector(i, Prop_Data, "m_vecOrigin", vecOrigin_edict);
		GetClientEyePosition(i, vecOrigin_edict);
		if(GetClientTeam(i) != GetClientTeam(client))
		{
			TFClassType class = TF2_GetPlayerClass(client);
			int team = GetClientTeam(client);
			if(team == 2 && class == TFClass_Medic || !IsFakeClient(i) && TF2_IsPlayerInCondition(i, TFCond_Cloaked) || !IsFakeClient(i) && TF2_IsPlayerInCondition(i, TFCond_Disguised) || team == 3 && TF2_IsPlayerInCondition(i, TFCond_Ubercharged) || TF2_IsPlayerInCondition(client, TFCond_Cloaked))
				continue;
			if(IsPointVisible(vecOrigin_center, vecOrigin_edict))
			{
				float edict_distance = GetVectorDistance(vecOrigin_center, vecOrigin_edict);
				if((edict_distance < distance) || (distance == -1.0))
				{
					distance = edict_distance;
					closestEdict = i;
				}
			}
		}
	}
	return closestEdict;
}

stock void ClampAngle(float fAngles[3])
{
	while(fAngles[0] > 89.0)  fAngles[0]-=360.0;
	while(fAngles[0] < -89.0) fAngles[0]+=360.0;
	while(fAngles[1] > 180.0) fAngles[1]-=360.0;
	while(fAngles[1] <-180.0) fAngles[1]+=360.0;
}

stock float TF_GetUberLevel(int client)
{
	int  index = GetPlayerWeaponSlot(client, 1);
	if(IsValidEntity(index)
	&& (GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==29
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==211
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==35
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==411
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==663
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==796
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==805
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==885
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==894
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==903
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==912
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==961
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==970
	|| GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex")==998))
		return GetEntPropFloat(index, Prop_Send, "m_flChargeLevel")*100.0;
	else
		return 0.0;
}

stock bool IsPointVisible(const float start[3], const float end[3])
{
	TR_TraceRayFilter(start, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceEntityFilterStuff);
	return TR_GetFraction() >= 0.9;
}

public bool TraceEntityFilterStuff(int entity, int mask)
{
	return entity > MaxClients;
}

public bool Filter(int entity, int mask)
{
	return !(IsValidClient(entity));
}
