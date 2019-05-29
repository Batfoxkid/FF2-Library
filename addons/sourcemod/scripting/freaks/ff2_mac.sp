#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

bool IsPlayerCharging[MAXPLAYERS+1];

float PlayerDuration[MAXPLAYERS+1];
float PlayerTickDamage[MAXPLAYERS+1][MAXPLAYERS+1];
// PlayerTickDamage[attckerIndex][victimIndex]


public Plugin myinfo=
{
    name="Freak Fortress 2: Mac Abilities",
    author="Nopied◎",
    description="",
    version="",
};

public void OnPluginStart2()
{
    // ?
}

public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
{
  if(!strcmp(abilityName, "ff2_mac_laser"))
  {
		// int client=GetClientOfUserId(FF2_GetBossUserId(boss));
		PrepareLaser(boss);
  }
}

void PrepareLaser(int boss)
{
    int client=GetClientOfUserId(FF2_GetBossUserId(boss));
    int index;
    IsPlayerCharging[client] = true;

    PlayerDuration[client] = GetGameTime() + FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_mac_laser", 1, 8.0);

    for(int target = 1; target <= MaxClients; target++)
    {
        if(target != client && IsClientInGame(target) && IsPlayerAlive(target)
    && !IsValidEntity((index = TF2_HasGlow(client, target)))
        )
        {
            TF2_CreateGlow(client, target);
        }
        PlayerTickDamage[client][target] = 0.0;
    }

    SDKUnhook(client, SDKHook_PreThinkPost, OnPlayerThink);
    SDKHook(client, SDKHook_PreThinkPost, OnPlayerThink);
}

public void OnPlayerThink(int client)
{
    // 보스 시야에 든 플레이어는 PlayerTickDamage에 데미지 축적됨.
    // 그 플레이어의 HP와 틱 데미지를 가산하여 윤곽선 표시 (체력비례로 초록 -> 빨강)

    int index;

    if(!IsPlayerCharging[client]
        || GetGameTime() >= PlayerDuration[client]
        || !IsClientInGame(client)
        || !IsPlayerAlive(client)
        )
    {
        IsPlayerCharging[client] = false;

        for(int target = 1; target <= MaxClients; target++)
        {
            if(target != client && IsClientInGame(target) && IsPlayerAlive(target))
            {
                if(IsValidEntity((index = TF2_HasGlow(client, target))))
                {
                    AcceptEntityInput(index, "Kill");
                }

            }
            PlayerTickDamage[client][target] = 0.0;
        }

        if(GetGameTime() >= PlayerDuration[client])
            FF2_SetBossCharge(FF2_GetBossIndex(client), 0, 50.0);

        SDKUnhook(client, SDKHook_PreThinkPost, OnPlayerThink);
        // 발사
        return;
    }
    ////////////////////////////////////////////////////////////////////

    int boss = FF2_GetBossIndex(client);
    bool prepareAttack = (GetClientButtons(client) & IN_ATTACK) ? true : false;
    float clientPos[3], targetPos[3];
    float damage = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_mac_laser", 2, 0.5); // = 106.7
    GetClientEyePosition(client, clientPos);

    for(int target = 1; target <= MaxClients; target++)
    {
        if(target != client && IsClientInGame(target) && IsPlayerAlive(target))
        {
            GetClientEyePosition(target, targetPos);
            if(CanHit(client, clientPos, targetPos))
            {
                PlayerTickDamage[client][target] += damage;
                Debug("데미지: %.1f", PlayerTickDamage[client][target]);

                if(prepareAttack)
                {
                    HitTarget(client, target);
                    continue;
                }

            }

            if(IsValidEntity((index = TF2_HasGlow(client, target))))
            {
                int colors[4] = {0, 0, 0, 255};

                float remaining = - (PlayerTickDamage[client][target] - float(GetEntProp(target, Prop_Data, "m_iMaxHealth")));
                // 0 = 빨강, PlayerTickDamage가 m_iMaxHealth보다 낮을 경우 초록색

                if(remaining < 0.0) // 즉사
                {
                    colors[0] = 255;
                }
                else if(float(GetEntProp(target, Prop_Data, "m_iMaxHealth")) == remaining) // 노 데미지
                {
                    colors[1] = 255;
                }
                else
                {
                    float div = remaining / float(GetEntProp(target, Prop_Data, "m_iMaxHealth"));

                    if(div > 0.5)
                    {
                        colors[0] = RoundFloat(255.0 * div);
                        colors[1] = 255;
                    }
                    else
                    {
                        colors[0] = 255;
                        colors[1] = RoundFloat(255.0 * div);
                    }
                }
            }
        }

    }
}

void HitTarget(int client, int target)
{
    IsPlayerCharging[client] = false;

    SDKHooks_TakeDamage(target, client, client, PlayerTickDamage[client][target], DMG_GENERIC, -1);
}

bool CanHit(int client, float clientPos[3], float targetPos[3])
{
    TR_TraceRayFilter(clientPos, targetPos, MASK_SOLID, RayType_EndPoint, TraceRayWithOutPlayer, client);
    return TR_DidHit();
}

public bool TraceRayWithOutPlayer(int entity, int contentsMask, any data)
{
    /*
    if(IsValidClient(entity) && entity != data)
    {
        return true;
    }
    return false;
    */
    return entity != data;
}

stock bool IsValidClient(int client)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client));
}

stock bool IsBossTeam(int client)
{
    return FF2_GetBossTeam() == GetClientTeam(client);
}


// Copied from RainbowGlow
stock int TF2_CreateGlow(int owner, int iEnt)
{
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);

	char strGlowColor[18];
	Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(180, 255));

	int ent = CreateEntityByName("tf_glow");
    if(IsValidEntity(ent))
    {
    	DispatchKeyValue(ent, "targetname", "RainbowGlow");
    	DispatchKeyValue(ent, "target", strName);
    	DispatchKeyValue(ent, "Mode", "0");
    	DispatchKeyValue(ent, "GlowColor", strGlowColor);
    	DispatchSpawn(ent);

        SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", owner);

    	AcceptEntityInput(ent, "Enable");
        return ent;
    }

	return -1;
}

stock int TF2_HasGlow(int owner, int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt
        && GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity") == owner)
		{
			return index;
		}
	}

	return -1;
}

stock void TF2_SetGlowColor(int ent, int colors[4])
{
    char strGlowColor[18];
	Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", colors[0], colors[1], colors[2], colors[3]);

    DispatchKeyValue(ent, "GlowColor", strGlowColor);
}
