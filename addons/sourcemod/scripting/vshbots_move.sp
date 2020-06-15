
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

float flag_pos[3];
float ClientPosition[3];

public Plugin myinfo=
{
	name= "VSH/FF2 Bots[moving]",
	author= "tRololo312312",
	description= "Makes TFBots move to enemys location",
	version= "1.1",
	url= "http://steamcommunity.com/profiles/76561198039186809"
}

public void OnAllPluginsLoaded()
{
	Handle PFind = FindPluginByFile("vshbots_logic.smx");
	if(PFind != INVALID_HANDLE)
	{
		if(GetPluginStatus(PFind) != Plugin_Running)
		{
			SetFailState("logic plugin for these bots is not loaded!");
		}
	}
	else
	{
		SetFailState("logic plugin for these bots is not loaded!");
	}
}

public void OnPluginStart()
{
	HookEvent("arena_round_start", RoundStarted);
}

public void OnMapStart()
{
	CreateTimer(0.1, MoveTimer,_,TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnFlagTouch(int point, int client)
{
	for(client=1;client<=MaxClients;client++)
	{
		if(IsClientInGame(client))
		{
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action RoundStarted(Handle  event , const char[] name , bool dontBroadcast)
{
	CreateTimer(1.0, LoadStuff);
	CreateTimer(1.0, LoadStuff2);
	CreateTimer(2.0, FindFlag);
}

public Action LoadStuff(Handle timer)
{
	int teamflags = CreateEntityByName("item_teamflag");
	if(IsValidEntity(teamflags))
	{
		DispatchKeyValue(teamflags, "trail_effect", "0");
		DispatchKeyValue(teamflags, "ReturnTime", "1");
		DispatchKeyValue(teamflags, "flag_model", "models/empty.mdl");
		DispatchSpawn(teamflags);
		SetEntProp(teamflags, Prop_Send, "m_iTeamNum", 3);
	}
}

public Action LoadStuff2(Handle timer)
{
	int teamflags2 = CreateEntityByName("item_teamflag");
	if(IsValidEntity(teamflags2))
	{
		DispatchKeyValue(teamflags2, "trail_effect", "0");
		DispatchKeyValue(teamflags2, "ReturnTime", "1");
		DispatchKeyValue(teamflags2, "flag_model", "models/empty.mdl");
		DispatchSpawn(teamflags2);
		SetEntProp(teamflags2, Prop_Send, "m_iTeamNum", 2);
	}
}

public Action FindFlag(Handle timer)
{
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "item_teamflag"))!=INVALID_ENT_REFERENCE)
	{
		SDKHook(ent, SDKHook_StartTouch, OnFlagTouch );
		SDKHook(ent, SDKHook_Touch, OnFlagTouch );
	}
}

public Action MoveTimer(Handle timer)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client))
			{
				int entIndex = -1;
				int entIndex2 = -1;
				GetClientAbsOrigin(client, ClientPosition);
				int Ent = Client_GetClosest(ClientPosition, client);
				int team = GetClientTeam(client);
				if(team == 3)
				{
					GetClientAbsOrigin(client, flag_pos);
					while((entIndex = FindEntityByClassname(entIndex, "item_teamflag")) != INVALID_ENT_REFERENCE)
					{
						int iTeamNum = GetEntProp(entIndex, Prop_Send, "m_iTeamNum");
						if (iTeamNum == 3)
						{
							TeleportEntity(entIndex, flag_pos, NULL_VECTOR, NULL_VECTOR);
						}
					}
				}
				if(Ent != -1 && team == 3)
				{
					static float ClosestClient[3];
					GetClientAbsOrigin(Ent, ClosestClient);
					while((entIndex2 = FindEntityByClassname(entIndex2, "item_teamflag")) != INVALID_ENT_REFERENCE)
					{
						int iTeamNum = GetEntProp(entIndex2, Prop_Send, "m_iTeamNum");
						if (iTeamNum == 2)
						{
							TeleportEntity(entIndex2, ClosestClient, NULL_VECTOR, NULL_VECTOR);
						}
					}
				}
			}
		}
	}
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
		GetClientAbsOrigin(i, vecOrigin_edict);
		if(GetClientTeam(i) != GetClientTeam(client))
		{
			float edict_distance = GetVectorDistance(vecOrigin_center, vecOrigin_edict);
			if((edict_distance < distance) || (distance == -1.0))
			{
				distance = edict_distance;
				closestEdict = i;
			}
		}
	}
	return closestEdict;
}
