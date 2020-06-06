
#include <sdkhooks>
#include <tf2attributes>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo=
{
	name		= "Freak Fortress 2: Body Effects",
	author		= "Deathreus",
	description = "Various effects that apply to the various parts of the body",
	version		= "1.2",
};

int BossTeam=view_as<int>(TFTeam_Blue);
//int g_iParticle[MAXPLAYERS+1][3];

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", Event_RoundEnd, EventHookMode_PostNoCopy);
	AddNormalSoundHook(SoundHook);
}

public Action FF2_OnAbility2(int iBoss, const char[] pluginName, const char[] abilityName, int iStatus) {
	// This will do nothing but compiler gets mad at me without it
	return Plugin_Continue;
}

public Action Event_RoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	BossTeam = FF2_GetBossTeam();
	int iBoss;
	for (int iIndex; (iBoss=GetClientOfUserId(FF2_GetBossUserId(iIndex)))>0; iIndex++)
	{
		ClearParticles(iBoss);
		if(FF2_HasAbility(iIndex, this_plugin_name, "footprints"))
		{
			int iFootPrintType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "footprints", 1);
			static float flFootPrintId;
			switch(iFootPrintType)
			{
				case 1: flFootPrintId = 1.0;
				case 2: flFootPrintId = 8421376.0;
				case 3: flFootPrintId = 5322826.0;
				case 4: flFootPrintId = 13595446.0;
				case 5: flFootPrintId = 8208497.0;
				case 6: flFootPrintId = 2.0;
				case 7: flFootPrintId = 3100495.0;
			}
			TF2Attrib_SetByName(iBoss, "SPELL: set Halloween footstep type", flFootPrintId);
		}
		
		if(FF2_HasAbility(iIndex, this_plugin_name, "body_effect"))
		{
			static char sEffectType[64];
			FF2_GetAbilityArgumentString(iIndex, this_plugin_name, "body_effect", 1, sEffectType, sizeof(sEffectType));
			int iAttachType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "body_effect", 2, -1);
			int iAttachPoint = FF2_GetAbilityArgument(iIndex, this_plugin_name, "body_effect", 3, -1);
			TE_ParticleToAll(sEffectType, _, _, _, iBoss, iAttachType, iAttachPoint);
		}
		
		if(FF2_HasAbility(iIndex, this_plugin_name, "eye_effect"))
		{
			int iEyeEffectType = FF2_GetAbilityArgument(iIndex, this_plugin_name, "eye_effect", 1);
			int iEyeEffectColor = FF2_GetAbilityArgument(iIndex, this_plugin_name, "eye_effect", 2);
			
			static float flEyeEffectId, flEyeColorId;
			switch(iEyeEffectType)
			{
				case 1: flEyeEffectId = 2002.0;
				case 2: flEyeEffectId = 2003.0;
				case 3: flEyeEffectId = 2004.0;
				case 4: flEyeEffectId = 2005.0;
				case 5: flEyeEffectId = 2006.0;
				case 6: flEyeEffectId = 2007.0;
				case 7: flEyeEffectId = 2008.0;
			}
			switch(iEyeEffectColor)
			{
				case 1: flEyeColorId = 1.0;
				case 2: flEyeColorId = 2.0;
				case 3: flEyeColorId = 3.0;
				case 4: flEyeColorId = 4.0;
				case 5: flEyeColorId = 5.0;
				case 6: flEyeColorId = 6.0;
				case 7: flEyeColorId = 7.0;
			}
			
			int iWeapon = GetEntPropEnt(iBoss, Prop_Send, "m_hActiveWeapon");
			TF2Attrib_SetByDefIndex(iWeapon, 2025, 3.0);
			TF2Attrib_SetByDefIndex(iWeapon, 2013, flEyeEffectId);
			TF2Attrib_SetByDefIndex(iWeapon, 2014, flEyeColorId);
			
			SetEntProp(iBoss, Prop_Send, "m_nStreaks", 20);
		}
	}
}

public Action Event_RoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iBoss;
	for (int iIndex = 0; (iBoss=GetClientOfUserId(FF2_GetBossUserId(iIndex)))>0; iIndex++)
	{
		if(FF2_HasAbility(iIndex, this_plugin_name, "body_effect"))
		{
			ClearParticles(iBoss);
			TE_ParticleToAll("ghost_appearation", _, _, _, iBoss);
		}
		if(FF2_HasAbility(iIndex, this_plugin_name, "eye_effect"))
		{
			int iWeapon = GetEntProp(iBoss, Prop_Send, "m_hActiveWeapon");
			TF2Attrib_RemoveByName(iWeapon, "killstreak effect");
			TF2Attrib_RemoveByName(iWeapon, "killstreak idleeffect");
			TF2Attrib_RemoveByName(iWeapon, "killstreak tier");
			SetEntProp(iBoss, Prop_Send, "m_nStreaks", 0);
		}
	}
}

public Action SoundHook(int clients[MAXPLAYERS], int& numClients, char sSound[PLATFORM_MAX_PATH],
	  int& iEntity, int& channel, float& volume, int& level, int& pitch, int& flags,
	  char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
	if (!IsValidClient(iEntity, true, true)) return Plugin_Continue;
	int iBoss = FF2_GetBossIndex(iEntity);
	
	if(FF2_HasAbility(iBoss, this_plugin_name, "foot_quakes"))
	{
		float flRange = FF2_GetAbilityArgumentFloat(iBoss, this_plugin_name, "foot_quakes", 1, 500.0);
		if (StrContains(sSound, "player/footsteps/", false) != -1)
		{
			static float bossPosition[3], targetPosition[3];
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", bossPosition);
			for(int iTarget = 0; iTarget <= MaxClients; iTarget++)
			{
				if(!IsValidClient(iTarget, true) || iTarget == iEntity)
					continue;
				GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", targetPosition);
				float flDistance = GetVectorDistance(bossPosition, targetPosition);
				if(flDistance <= flRange)
				{
					ScreenShake(iTarget, FloatAbs((500.0 - flDistance) / (500.0 - 0.0) * 15.0), 5.0, 1.0);
				}
			}
			if(FF2_GetAbilityArgument(iBoss, this_plugin_name, "foot_quakes", 2, 0) == 1)
				ScreenShake(iEntity, _, 5.0, 1.0);
		}
	}
	return Plugin_Continue;
}

stock bool IsValidClient(int iClient, bool bAlive = false, bool bTeam = false)
{
	if(iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient))
		return false;

	if(IsClientSourceTV(iClient) || IsClientReplay(iClient))
		return false;
	
	if(bAlive && !IsPlayerAlive(iClient))
		return false;
	
	if(bTeam && GetClientTeam(iClient) != BossTeam)
		return false;

	return true;
}

stock void ClearParticles(int iClient)
{
	TF2Attrib_SetByName(iClient, "SPELL: set Halloween footstep type", 0.0);
	TF2Attrib_SetByName(iClient, "killstreak effect", 0.0);
	TF2Attrib_SetByName(iClient, "killstreak idleeffect", 0.0);
	TF2Attrib_SetByName(iClient, "killstreak tier", 0.0);
	
	/*
	for (int i = 0; i < 3; i++)
	{
		int iEntity = EntRefToEntIndex(g_iParticle[iClient][i]);
		if (iEntity > MaxClients && IsValidEntity(iEntity)) RemoveEntity(iEntity);
		g_iParticle[iClient][i] = INVALID_ENT_REFERENCE;
	}
	*/
}

/*
stock void MakeParticle(int client, char[] effect, char[] attachment)
{
	static float pos[3];
	static float ang[3];
	static char buffer[128];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	GetClientEyeAngles(client, ang);
	ang[0] *= -1;
	ang[1] += 180.0;
	if (ang[1] > 180.0) ang[1] -= 360.0;
	ang[2] = 0.0;
	int particle = CreateEntityByName("info_particle_system");
	if (!IsValidEntity(particle)) return -1;
	TeleportEntity(particle, pos, ang, NULL_VECTOR);
	DispatchKeyValue(particle, "effect_name", effect);
	SetVariantString("!activator");
	AcceptEntityInput(particle, "SetParent", client, particle, 0);
	if (attachment[0] != '\0')
	{
		SetVariantString(attachment);
		AcceptEntityInput(particle, "SetParentAttachmentMaintainOffset", particle, particle, 0);
	}
	Format(buffer, sizeof(buffer), "%s_%s%d", effect, attachment, particle);
	DispatchKeyValue(particle, "targetname", buffer);
	DispatchSpawn(particle);
	ActivateEntity(particle);
	SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", client);
	AcceptEntityInput(particle, "Start");
	return particle;
}
*/

void TE_ParticleToAll(char[] sName, float flOrigin[3]=NULL_VECTOR, float flStart[3]=NULL_VECTOR, float flAngles[3]=NULL_VECTOR, int iEntIndex=-1, int iAttachType=-1, int iAttachPoint=-1, bool bResetParticles=true)
{
	// find string table
	int tblidx = FindStringTable("ParticleEffectNames");
	int stridx = FindStringIndex(tblidx, sName);
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", flOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", flOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", flOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", flStart[0]);
	TE_WriteFloat("m_vecStart[1]", flStart[1]);
	TE_WriteFloat("m_vecStart[2]", flStart[2]);
	TE_WriteVector("m_vecAngles", flAngles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	if (iEntIndex!=-1)
	{
		TE_WriteNum("entindex", iEntIndex);
	}
	if (iAttachType!=-1)
	{
		TE_WriteNum("m_iAttachType", iAttachType);
	}
	if (iAttachPoint!=-1)
	{
		TE_WriteNum("m_iAttachmentPointIndex", iAttachPoint);
	}
	TE_WriteNum("m_bResetParticles", bResetParticles ? 1 : 0);	 
	TE_SendToAll();
}

stock void ScreenShake(int iTarget, float flIntensity=30.0, float flDuration=10.0, float flFrequency=3.0)
{
	BfWrite bf = null;
	if ((bf = UserMessageToBfWrite(StartMessageOne("Shake", iTarget))) != null)
	{
		bf.WriteByte(0);
		bf.WriteFloat(flIntensity);
		bf.WriteFloat(flDuration);
		bf.WriteFloat(flFrequency);
		EndMessage();
	}
}
