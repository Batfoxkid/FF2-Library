#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <freak_fortress_2>

int clientWeapon[MAXPLAYERS+1];

public Plugin myinfo=
{
	name="Freak Fortress 2: Sam's Abilities",
	author="Nopied",
	description="",
	version="wat.",
};

public void OnPluginStart2()
{
	HookEvent("player_spawn", OnPlayerSpawn);
}

public Action OnPlayerSpawn(Handle event, const char[] name, bool dont)
{
	int client=GetClientOfUserId(GetEventInt(event, "userid"));

	if(clientWeapon[client] && IsValidEntity(clientWeapon[client]))
	{
		SetEntityRenderMode(clientWeapon[client], RENDER_TRANSCOLOR);
		SetEntityRenderColor(clientWeapon[client], _, _, _, 255);
		clientWeapon[client]=0;
	}

}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
  if(!strcmp(ability_name, "rage_sam"))
	{
		Rage_Sam(boss);
	}
}

void Rage_Sam(int boss)
{
	int bossClient=GetClientOfUserId(FF2_GetBossUserId(boss));
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsBossTeam(client) && IsPlayerAlive(client))
		{
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, 10.0);
			TF2_StunPlayer(client, 10.0, 1.0, TF_STUNFLAG_NOSOUNDOREFFECT|TF_STUNFLAG_THIRDPERSON, bossClient); // TODO: 시간 커스터마이즈

			// 들고있던 무기 떨구기 || 107: 이속 증가

			int weapon=GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

			if(weapon!=clientWeapon[client] && IsValidEntity(weapon))
			{
				if(clientWeapon[client] && IsValidEntity(clientWeapon[client]))
				{
					SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
					SetEntityRenderColor(clientWeapon[client], _, _, _, 255);
				}
				SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(weapon, 255, 255, 255, 75);
				clientWeapon[client]=weapon;
				PrintCenterText(client, "들고 있던 무기를 사용할 수 없게 되었습니다!");
			}
		}
	}
}

public void OnClientDisconnect(int client)
{
	clientWeapon[client]=0;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsValidClient(client) || !clientWeapon[client])
		return Plugin_Continue;

	int weapon2=GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(weapon2 == clientWeapon[client] && IsValidEntity(weapon2))
	{
		if(buttons & IN_ATTACK|IN_ATTACK2|IN_ATTACK3|IN_RELOAD)
		{
			PrintCenterText(client, "분노로 인해 사용할 수 없습니다!");
		}
		SetEntPropFloat(weapon2, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+0.2);
		SetEntPropFloat(weapon2, Prop_Send, "m_flNextSecondaryAttack", GetGameTime()+0.2);
		SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime()+0.2);
	}
	return Plugin_Continue;
}

stock int SpawnWeaponProp(int client, int weapon)
{
	int ent=CreateEntityByName("prop_physics_override");

	if(!IsValidEntity(ent)) return -1;

	float clientPos[3];
	GetClientEyePosition(client, clientPos);

	SetEntProp(ent, Prop_Data, "m_takedamage", 2);
	SetEntProp(ent, Prop_Send, "m_nModelIndex", GetEntProp(weapon, Prop_Send, "m_nModelIndex"));

	DispatchSpawn(ent);
	TeleportEntity(ent, clientPos, NULL_VECTOR, NULL_VECTOR);
	SetEntityMoveType(ent, MOVETYPE_VPHYSICS);

	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 0);

	return ent;
}

stock bool IsValidClient(int client)
{
    return (0<client && client<=MaxClients && IsClientInGame(client));
}

stock bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}

stock bool IsBossTeam(int client)
{
    return FF2_GetBossTeam() == GetClientTeam(client);
}
