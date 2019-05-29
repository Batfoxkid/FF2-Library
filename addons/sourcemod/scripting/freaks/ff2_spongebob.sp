#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <sdkhooks>

public Plugin myinfo=
{
    name="Freak Fortress 2 : spongeBob's Abilities",
    author="Nopied",
    description="....",
    version="2017_02_01",
};

bool CanResize[MAXPLAYERS+1];

public void OnPluginStart2()
{
    HookEvent("arena_round_start", OnRoundStart);
    HookEvent("teamplay_round_start", OnRoundStart_Pre);
}

public Action OnRoundStart_Pre(Handle event, const char[] name, bool dont)
{
    CreateTimer(10.4, CheckAbilityTimer, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnRoundStart(Handle event, const char[] name, bool dont)
{
  CheckAbility();
}

public Action CheckAbilityTimer(Handle timer)
{
    CheckAbility();
}

void CheckAbility()
{
    int client, boss;

    for(client=1; client<=MaxClients; client++)
    {
        if(CanResize[client])
        {
            SDKUnhook(client, SDKHook_PreThinkPost, ResizeTimer);
        }

        CanResize[client] = false;

        if((boss=FF2_GetBossIndex(client)) != -1)
        {
            if(FF2_HasAbility(boss, this_plugin_name, "ff2_spongebob"))
            {
                CanResize[client] = true;

                SDKHook(client, SDKHook_PreThinkPost, ResizeTimer);
            }

        }
    }
}

public void ResizeTimer(int client)
{
    if(FF2_GetRoundState() == 1 && IsClientInGame(client) && IsPlayerAlive(client))
    {
        int boss = FF2_GetBossIndex(client);
        if(boss != -1 && CanResize[client] && FF2_GetAbilityDuration(boss, 0) <= 0.0)
        {
            TryResize(boss);
        }
    }
    else
    {
        SDKUnhook(client, SDKHook_PreThinkPost, ResizeTimer);
    }
}


public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
{
    if(StrEqual(abilityName, "ff2_spongebob", true))
    {
        PrintCenterText(GetClientOfUserId(FF2_GetBossUserId(boss)), "앉기: 천천히 신체 사이즈 줄이기");
    }
}

public Action:FF2_OnBossAbilityTime(boss, String:abilityName[], slot, &Float:abilityDuration, &Float:abilityCooldown)
{
    if(FF2_HasAbility(boss, this_plugin_name, "rage_spongebob") && slot == 0 && abilityDuration > 0.0)
    {
        int client = GetClientOfUserId(FF2_GetBossUserId(boss));
        float currentSize = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
        float niceSize;
        float maxSize = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "rage_spongebob", 2, 10.0);

        float clientPos[3];
        GetClientEyePosition(client, clientPos);

        niceSize = currentSize + FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "rage_spongebob", 1, 0.1);
        if(niceSize > maxSize)
            niceSize = maxSize;

        SetEntPropFloat(client, Prop_Send, "m_flModelScale", niceSize);
        UpdateEntityHitbox(client, niceSize*5.8);

        if(IsPlayerStuck(client, true))
        {
            int target = TR_GetEntityIndex();

            if(IsValidClient(target) && IsPlayerAlive(target))
            {
                SDKHooks_TakeDamage(target, client, client, 100.0, DMG_SLASH, -1);
            }
        }

        float ratius = niceSize * 12.0;
        float targetPos[3];

        for(int target=1; target<=MaxClients; target++)
        {
            if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) != GetClientTeam(client))
            {
                GetClientEyePosition(target, targetPos);

                if(GetVectorDistance(clientPos, targetPos) <= ratius)
                {
                    SDKHooks_TakeDamage(target, client, client, 20.0, DMG_SLASH, -1);
                }
            }
        }
    }
}


void TryResize(int boss)
{
    int client = GetClientOfUserId(FF2_GetBossUserId(boss));
    float currentSize = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
    float niceSize;

    float minSize = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_spongebob", 1, 0.3);
    float maxSize = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, "ff2_spongebob", 2, 5.0);

    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);

    if(GetClientButtons(client) & IN_DUCK)
    {
        niceSize = currentSize - 0.02;
        if(niceSize < minSize)
            niceSize = minSize;

        SetEntPropFloat(client, Prop_Send, "m_flModelScale", niceSize);
        UpdateEntityHitbox(client, niceSize*5.8);
    }
    else
    {
        niceSize = currentSize + 0.02;
        if(niceSize > maxSize)
            niceSize = maxSize;

        if(IsSpotSafe(client, clientPos, niceSize) && !IsPlayerStuck(client, false))
        {
            SetEntPropFloat(client, Prop_Send, "m_flModelScale", niceSize);
            UpdateEntityHitbox(client, niceSize*5.8);

            if(IsPlayerStuck(client, false))
            {
                niceSize = currentSize - 0.3;
                if(niceSize < minSize)
                    niceSize = minSize;

                SetEntPropFloat(client, Prop_Send, "m_flModelScale", niceSize);
                UpdateEntityHitbox(client, niceSize*5.8);
            }
        }

    }

    /*
    for(float suar = maxSize; suar >= minSize; suar -= 0.05)
    {
        if(IsSpotSafe(client, clientPos, suar) && !IsPlayerStuck(client))
        {
            SetEntPropFloat(client, Prop_Send, "m_flModelScale", suar);
            UpdateEntityHitbox(client, (suar - 0.1)*3.8);
            break;
        }
        else if(IsPlayerStuck(client))
        {
            SetEntPropFloat(client, Prop_Send, "m_flModelScale", minSize);
            break;
        }
    }
    */
}

stock bool:IsPlayerStuck(iEntity, bool findTarget=false)
{
    decl Float:vecMin[3], Float:vecMax[3], Float:vecOrigin[3];

    GetEntPropVector(iEntity, Prop_Send, "m_vecMins", vecMin);
    GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", vecMax);
    GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);

    if(!findTarget)
    {
        TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceAnything, iEntity);
    }
    else
    {
        TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_SOLID, TraceRayPlayerOnly, iEntity);
    }
    return (TR_DidHit());
}

public bool:TraceRayPlayerOnly(iEntity, iMask, any:iData)
{
    return (IsValidClient(iEntity) && IsValidClient(iData) && iEntity != iData);
}

stock bool:IsValidClient(iClient)
{
    return bool:(0 < iClient && iClient <= MaxClients && IsClientInGame(iClient));
}

stock void UpdateEntityHitbox(const int client, const float fScale)
{
     static const Float:vecTF2PlayerMin[3] = { -50.5, -70.5, 0.0 }, Float:vecTF2PlayerMax[3] = { 50.5,  70.5, 120.0 };
    // static const Float:vecTF2PlayerMin[3] = { -24.5, -24.5, 0.0 }, Float:vecTF2PlayerMax[3] = { 24.5,  24.5, 83.0 };

    decl Float:vecScaledPlayerMin[3], Float:vecScaledPlayerMax[3];

    vecScaledPlayerMin = vecTF2PlayerMin;
    vecScaledPlayerMax = vecTF2PlayerMax;

    ScaleVector(vecScaledPlayerMin, fScale);
    ScaleVector(vecScaledPlayerMax, fScale);

    SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMins", vecScaledPlayerMin);
    SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMaxs", vecScaledPlayerMax);
}

bool ResizeTraceFailed;

stock void constrainDistance(const float[] startPoint, float[] endPoint, float distance, float maxDistance)
{
	float constrainFactor = maxDistance / distance;
	endPoint[0] = ((endPoint[0] - startPoint[0]) * constrainFactor) + startPoint[0];
	endPoint[1] = ((endPoint[1] - startPoint[1]) * constrainFactor) + startPoint[1];
	endPoint[2] = ((endPoint[2] - startPoint[2]) * constrainFactor) + startPoint[2];
}

public bool IsSpotSafe(clientIdx, float playerPos[3], float sizeMultiplier)
{
	ResizeTraceFailed = false;
	static Float:mins[3];
	static Float:maxs[3];
	mins[0] = -24.0 * sizeMultiplier;
	mins[1] = -24.0 * sizeMultiplier;
	mins[2] = 0.0;
	maxs[0] = 24.0 * sizeMultiplier;
	maxs[1] = 24.0 * sizeMultiplier;
	maxs[2] = 83.0 * sizeMultiplier;

	// the eight 45 degree angles and center, which only checks the z offset
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, 0.0, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], 0.0, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1], maxs[2])) return false;

	// 22.5 angles as well, for paranoia sake
	if (!Resize_TestResizeOffset(playerPos, mins[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], mins[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0], maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, mins[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, mins[0] * 0.5, maxs[1], maxs[2])) return false;
	if (!Resize_TestResizeOffset(playerPos, maxs[0] * 0.5, maxs[1], maxs[2])) return false;

	// four square tests
	if (!Resize_TestSquare(playerPos, mins[0], maxs[0], mins[1], maxs[1], maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.75, maxs[0] * 0.75, mins[1] * 0.75, maxs[1] * 0.75, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.5, maxs[0] * 0.5, mins[1] * 0.5, maxs[1] * 0.5, maxs[2])) return false;
	if (!Resize_TestSquare(playerPos, mins[0] * 0.25, maxs[0] * 0.25, mins[1] * 0.25, maxs[1] * 0.25, maxs[2])) return false;

	return true;
}

bool Resize_TestResizeOffset(const float bossOrigin[3], float xOffset, float yOffset, float zOffset)
{
	static Float:tmpOrigin[3];
	tmpOrigin[0] = bossOrigin[0];
	tmpOrigin[1] = bossOrigin[1];
	tmpOrigin[2] = bossOrigin[2];
	static Float:targetOrigin[3];
	targetOrigin[0] = bossOrigin[0] + xOffset;
	targetOrigin[1] = bossOrigin[1] + yOffset;
	targetOrigin[2] = bossOrigin[2];

	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;

	tmpOrigin[0] = targetOrigin[0];
	tmpOrigin[1] = targetOrigin[1];
	tmpOrigin[2] = targetOrigin[2] + zOffset;

	if (!Resize_OneTrace(targetOrigin, tmpOrigin))
		return false;

	targetOrigin[0] = bossOrigin[0];
	targetOrigin[1] = bossOrigin[1];
	targetOrigin[2] = bossOrigin[2] + zOffset;

	if (!(xOffset == 0.0 && yOffset == 0.0))
		if (!Resize_OneTrace(tmpOrigin, targetOrigin))
			return false;

	return true;
}

bool Resize_TestSquare(const float bossOrigin[3], float xmin, float xmax, float ymin, float ymax, float zOffset)
{
	static Float:pointA[3];
	static Float:pointB[3];
	for (new phase = 0; phase <= 7; phase++)
	{
		// going counterclockwise
		if (phase == 0)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 1)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 2)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmax;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 3)
		{
			pointA[0] = bossOrigin[0] + xmax;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 4)
		{
			pointA[0] = bossOrigin[0] + 0.0;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymin;
		}
		else if (phase == 5)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymin;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + 0.0;
		}
		else if (phase == 6)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + 0.0;
			pointB[0] = bossOrigin[0] + xmin;
			pointB[1] = bossOrigin[1] + ymax;
		}
		else if (phase == 7)
		{
			pointA[0] = bossOrigin[0] + xmin;
			pointA[1] = bossOrigin[1] + ymax;
			pointB[0] = bossOrigin[0] + 0.0;
			pointB[1] = bossOrigin[1] + ymax;
		}

		for (new shouldZ = 0; shouldZ <= 1; shouldZ++)
		{
			pointA[2] = pointB[2] = shouldZ == 0 ? bossOrigin[2] : (bossOrigin[2] + zOffset);
			if (!Resize_OneTrace(pointA, pointB))
				return false;
		}
	}

	return true;
}

public bool TraceAnything(int entity, int contentsMask)
{
    return false;
}

bool Resize_OneTrace(const float startPos[3], const float endPos[3])
{
	static Float:result[3];
	TR_TraceRayFilter(startPos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceAnything);
	if (ResizeTraceFailed)
	{
		return false;
	}
	TR_GetEndPosition(result);
	if (endPos[0] != result[0] || endPos[1] != result[1] || endPos[2] != result[2])
	{
		return false;
	}

	return true;
}
