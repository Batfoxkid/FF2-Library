#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <stocksoup/sdkports/util>

#pragma newdecls required

public Plugin myinfo=
{
	name="Freak Fortress 2 : Freddy Krueger's Ability",
	author="Nopied",
	description="FF2",
	version="1.1",
};

public void OnPluginStart2()
{
	return;
}

public void OnEntityCreated(entity, const char[] classname)
{
	if(!StrContains(classname, "trigger_hurt", false))
	{
		SDKHook(entity, SDKHook_StartTouch, OnTriggerTouched);
		SDKHook(entity, SDKHook_Touch, OnTriggerTouched);
	}
}

public Action OnTriggerTouched(int entity, int client)
{
	int mainboss = FF2_GetBossIndex(0);

	if(FF2_HasAbility(mainboss, this_plugin_name, "ff2_nightmare") /*&& FF2_GetAbilityDuration(mainboss) > 0.0*/)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnGameFrame()
{
	int boss, mainboss;
	mainboss = FF2_GetBossIndex(0);
	bool hideHUD = FF2_HasAbility(mainboss, this_plugin_name, "ff2_nightmare");
	float bossCharge;

	for(int client = 1; client <= MaxClients; client++)
	{
		if(!IsClientInGame(client)) continue;
		else if(!IsPlayerAlive(client))
		{
			SetEntProp(client, Prop_Send, "m_iHideHUD", ( 1<<3 )); // TODO: ??? 체력만 안보이게하면 유용한데?
			continue;
		}

		boss = FF2_GetBossIndex(client);

		if(hideHUD && boss == -1)
		{
			SetEntProp(client, Prop_Send, "m_iHideHUD", ( 1<<8 )|( 1<<9 ));
			continue;
		} 

		if(!FF2_HasAbility(boss, this_plugin_name, "ff2_nightmare")) continue;

		bossCharge = FF2_GetBossCharge(boss, 0);

		if(bossCharge < 100.0)  // TODO: FF2 2.0에서 삭제
		{
			SetEntityRenderMode(client, RENDER_TRANSCOLOR);
			SetEntityRenderColor(client, _, _, _, 55 + RoundFloat(200.0 - (bossCharge * 2.0)));
			// 보스 분노 100: 55
			// 보스 분노 0: 255
		}
		else
		{
			FF2_DoAbility(boss, this_plugin_name, "ff2_nightmare", 0, 0);
			char temp[PLATFORM_MAX_PATH];
			FF2_RandomSound("sound_ability", temp, sizeof(temp), boss, 0);
			FF2_SetBossCharge(boss, 0, bossCharge - 100.0);
		}
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));

	if(StrEqual(ability_name, "ff2_nightmare"))
	{
		// m_nSequence, m_flPlaybackRate

		int targetlist[MAXPLAYERS+1];
		int targetCount = 0;
		float targetPos[3], clientPos[3];
		float targetAngles[3], clientAngles[3];

		GetClientEyePosition(client, clientPos);
		GetClientEyeAngles(client, clientAngles);

		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, _, _, _, 255);

		int animationentity = CreateEntityByName("prop_dynamic_override");
		if(IsValidEntity(animationentity))
		{
			char model[PLATFORM_MAX_PATH];
			// float pos[3];
			// GetClientEyePosition(client, pos);
			GetClientModel(client, model, sizeof(model));

			DispatchKeyValue(animationentity, "model", model);

			DispatchSpawn(animationentity);
			SetEntPropEnt(animationentity, Prop_Send, "m_hOwnerEntity", client);

			if(GetEntProp(client, Prop_Send, "m_iTeamNum") == 0)
				SetEntProp(animationentity, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nForcedSkin"));
			else
				SetEntProp(animationentity, Prop_Send, "m_nSkin", GetClientTeam(client) - 2);

			SetEntProp(animationentity, Prop_Send, "m_nSequence", GetEntProp(client, Prop_Send, "m_nSequence"));
			SetEntPropFloat(animationentity, Prop_Send, "m_flPlaybackRate", GetEntPropFloat(client, Prop_Send, "m_flPlaybackRate")); //

			float tempAngle[3];

			tempAngle[0] = clientAngles[0];
			tempAngle[1] = clientAngles[1];
			tempAngle[2] = 0.0;
			TeleportEntity(animationentity, clientPos, tempAngle, NULL_VECTOR);
		}

		for(int target = 1; target<=MaxClients; target++)
		{
			if(!IsClientInGame(target) || !IsPlayerAlive(target)) continue;

			if(GetClientTeam(client) != GetClientTeam(target))
			{
				targetlist[targetCount++] = target;
				UTIL_ScreenFade(target, {0, 0, 0, 255}, 0.1, 5.0);
			}
		}

		int bestTarget = targetlist[GetRandomInt(0, targetCount-1)];

		GetClientEyePosition(bestTarget, targetPos);
		GetClientEyeAngles(bestTarget, targetAngles);

		float tempVelocity[3], tempTargetVelocity[3];

		GetEntPropVector(client, Prop_Data, "m_vecVelocity", tempVelocity);
		GetEntPropVector(bestTarget, Prop_Data, "m_vecVelocity", tempTargetVelocity);

		ScaleVector(tempVelocity, -1.1);
		ScaleVector(tempTargetVelocity, -1.1);

		TeleportEntity(bestTarget, clientPos, clientAngles, tempVelocity);
		TeleportEntity(client, targetPos, targetAngles, tempVelocity);
	}
}


stock bool IsBoss(int client)
{
	return FF2_GetBossIndex(client) != -1;
}

stock bool IsValidClient(int client)
{
	return (0<client && client <= MaxClients && IsClientInGame(client));
}
