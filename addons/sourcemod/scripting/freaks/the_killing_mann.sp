
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define LIFELOSE_THEME			"freak_fortress_2/killingmann/theme_secondlife_fx.mp3"		// life lost, will be stopped when round ends
int killing_mann_life;

#define KILLINGMANN "killing_mann_themechange"
#define FAR_FUTURE 100000000.0

#define SPECIALSPELLS "special_spells"
bool HasSpellAbility[MAXPLAYERS+1]=false;
bool SpellsAreOnCoolDown[MAXPLAYERS+1]=false;
float Spellragecost[MAXPLAYERS+1];
float SpellHudNotificationAt[MAXPLAYERS+1]=FAR_FUTURE;
float SpellsCooldownEndsIn[MAXPLAYERS+1]=FAR_FUTURE;
int spellsnumber;
char SpellsHUDText[MAXPLAYERS+1][10][256];

public Plugin myinfo = {
	name	= "Freak Fortress 2: The Killing Manns abilities",
	author	= "M7",
	version = "1.0",
};

public void OnPluginStart2()
{
	HookEvent("teamplay_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", event_round_start, EventHookMode_PostNoCopy);
	
	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", event_round_end, EventHookMode_PostNoCopy);
	
	PrecacheSound(LIFELOSE_THEME);
}

public Action event_round_start(Event event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	
	for(int clientIdx=1; clientIdx <= MaxClients; clientIdx++)
	{
		if(!IsValidClient(clientIdx))
			continue;
		
		killing_mann_life = 0;
		SpellHudNotificationAt[clientIdx]=FAR_FUTURE;
		SpellsCooldownEndsIn[clientIdx]=FAR_FUTURE;
		HasSpellAbility[clientIdx]=false;
		SpellsAreOnCoolDown[clientIdx]=false;
		
		int bossIdx=FF2_GetBossIndex(clientIdx); // Well this seems to be the solution to make it multi-boss friendly
		if(bossIdx>=0)
		{
			if(FF2_HasAbility(bossIdx, this_plugin_name, SPECIALSPELLS))
			{
				Spellragecost[clientIdx]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SPECIALSPELLS, 2);
				SpellHudNotificationAt[clientIdx]=GetEngineTime()+1.0;
				HasSpellAbility[clientIdx]=true;
				
				for(int arg=5;arg<=10;arg++)
				{
					ReadCenterText(bossIdx, SPECIALSPELLS, arg, SpellsHUDText[clientIdx][arg-5]);
				}
			}
		}
	}
}

public void OnGameFrame()
{
	SpellsTick(GetEngineTime());
}

public void SpellsTick(float currentTime)
{
	for(int clientIdx=1;clientIdx<=MaxClients;clientIdx++)
	{
		if(!IsValidClient(clientIdx)|| FF2_GetRoundState()!=1 || !FF2_IsFF2Enabled())
			continue;
		
		if(currentTime>=SpellsCooldownEndsIn[clientIdx])
		{
			if(IsBoss(clientIdx) && HasSpellAbility[clientIdx])
			{
				SetHudTextParams(-1.0, 1.0, 1.0, 0, 255, 0, 255);
				ShowHudText(clientIdx, -1, SpellsHUDText[clientIdx][2]);	
				SpellsAreOnCoolDown[clientIdx]=false;
				SpellsCooldownEndsIn[clientIdx]=FAR_FUTURE;
			}
		}
		
		if(currentTime>=SpellHudNotificationAt[clientIdx])
		{
			if(IsBoss(clientIdx) && FF2_GetBossCharge(FF2_GetBossIndex(clientIdx),0)>=Spellragecost[clientIdx] && !SpellsAreOnCoolDown[clientIdx] && HasSpellAbility[clientIdx])
			{
				int buttonmode=FF2_GetAbilityArgument(FF2_GetBossIndex(clientIdx), this_plugin_name, SPECIALSPELLS, 1);
				
				SetHudTextParams(-1.0, 1.0, 1.0, 0, 255, 0, 255);
				ShowHudText(clientIdx, -1, SpellsHUDText[clientIdx][1], SpellsHUDText[clientIdx][buttonmode==1 ? 3 : 4], RoundFloat(Spellragecost[clientIdx]));	
			}		
			SpellHudNotificationAt[clientIdx]=GetEngineTime()+1.0;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	int bossIdx=FF2_GetBossIndex(client);
	if(bossIdx>=0 && FF2_HasAbility(bossIdx, this_plugin_name, SPECIALSPELLS))
	{
		int buttonmode=FF2_GetAbilityArgument(bossIdx, this_plugin_name, SPECIALSPELLS, 1); // Use RELOAD, or SPECIAL to activate ability
		if(buttonmode==2 &&(buttons & IN_ATTACK3) || buttonmode==1 && (buttons & IN_RELOAD))
		{
			if(SpellsAreOnCoolDown[client]) // Prevent ability from firing if ability is on cooldown
			{
				switch(buttonmode)
				{
					case 1: buttons &= ~IN_RELOAD;
					case 2: buttons &= ~IN_ATTACK3;
				}
				SetHudTextParams(-1.0, 0.96, 3.0, 255, 0, 0, 255);
				ShowHudText(client, -1, SpellsHUDText[bossIdx][0]);	
				return Plugin_Changed;
			}
			
			if(FF2_GetBossCharge(bossIdx, 0)<Spellragecost[client]) // Not enough RAGE, prevent ability
			{
				switch(buttonmode)
				{
					case 1: buttons &= ~IN_RELOAD;
					case 2: buttons &= ~IN_ATTACK3;
				}
				SetHudTextParams(-1.0, 0.96, 3.0, 255, 0, 0, 255);
				ShowHudText(client, -1, SpellsHUDText[bossIdx][5], RoundFloat(Spellragecost[client]));	
				return Plugin_Changed;
			}
			
			FF2_SetBossCharge(bossIdx, 0, FF2_GetBossCharge(bossIdx,0)-Spellragecost[client]);
			SpellsAreOnCoolDown[client]=true;
			SpellsCooldownEndsIn[client]=GetEngineTime()+FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, SPECIALSPELLS, 3, 10.0);
			spellsnumber=FF2_GetAbilityArgument(bossIdx, this_plugin_name, SPECIALSPELLS, 4);
			CastSpell(client, spellsnumber);
			switch(buttonmode)
			{
				case 1: buttons &= ~IN_RELOAD;
				case 2: buttons &= ~IN_ATTACK3;
			}
			
			return Plugin_Continue;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public void CastSpell(int client, int Spellsnumber)
{
	if(!IsValidClient(client)|| FF2_GetRoundState()!=1 || !FF2_IsFF2Enabled())
		return;
			
	if(Spellsnumber==-1)
		Spellsnumber=GetRandomInt(0,4);
	
	switch(Spellsnumber)
	{
		case 0: ShootProjectile(client, "tf_projectile_spellfireball");
		case 1: ShootProjectile(client, "tf_projectile_spellbats");
		case 2: ShootProjectile(client, "tf_projectile_lightningorb");
		case 3: ShootProjectile(client, "tf_projectile_spellmeteorshower");
		case 4: ShootProjectile(client, "tf_projectile_spellspawnboss");
	}
}

int ShootProjectile(int iClient, char strEntname[48] = "")
{
	float flAng[3]; // original
	float flPos[3]; // original
	GetClientEyeAngles(iClient, flAng);
	GetClientEyePosition(iClient, flPos);
	
	int iTeam = GetClientTeam(iClient);
	int iSpell = CreateEntityByName(strEntname);
	
	if(!IsValidEntity(iSpell))
		return -1;
	
	float flVel1[3];
	float flVel2[3];
	
	GetAngleVectors(flAng, flVel2, NULL_VECTOR, NULL_VECTOR);
	
	flVel1[0] = flVel2[0]*1100.0; //Speed of a tf2 rocket.
	flVel1[1] = flVel2[1]*1100.0;
	flVel1[2] = flVel2[2]*1100.0;
	
	SetEntPropEnt(iSpell, Prop_Send, "m_hOwnerEntity", iClient);
	SetEntProp(iSpell, Prop_Send, "m_bCritical", (GetRandomInt(0, 100) <= 5)? 1 : 0, 1);
	SetEntProp(iSpell, Prop_Send, "m_iTeamNum", iTeam, 1);
	SetEntProp(iSpell, Prop_Send, "m_nSkin", (iTeam-2));
	
	TeleportEntity(iSpell, flPos, flAng, NULL_VECTOR);
	
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "TeamNum", -1, -1, 0);
	SetVariantInt(iTeam);
	AcceptEntityInput(iSpell, "SetTeam", -1, -1, 0); 
	
	DispatchSpawn(iSpell);
	TeleportEntity(iSpell, NULL_VECTOR, NULL_VECTOR, flVel1);
	
	return iSpell;
}

public Action event_round_end(Event event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			killing_mann_life = 0;
			StopSound(client, SNDCHAN_AUTO, LIFELOSE_THEME);
		}
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	return Plugin_Continue;
}

public Action FF2_OnLoseLife(int index, int& lives, int maxLives)
{		
	int userid = FF2_GetBossUserId(index);
	int client=GetClientOfUserId(userid);
	if(index==-1 || !IsValidEdict(client) || !FF2_HasAbility(index, this_plugin_name, KILLINGMANN))
		return Plugin_Continue;
	
	FF2_StopMusic(0);
		
	EmitSoundToAll(LIFELOSE_THEME);
		
	killing_mann_life++;
		
	return Plugin_Continue;
}

public Action FF2_OnMusic(char[] path, float& time)
{
	if (killing_mann_life)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

stock bool IsValidClient(int client, bool isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}

stock bool IsBoss(int client)
{
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	if(FF2_GetBossIndex(client)==-1) return false;
	return true;
}

stock void ReadCenterText(int bossIdx, const char[] ability_name, int argInt, char[] centerText)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, PLATFORM_MAX_PATH);
	ReplaceString(centerText, PLATFORM_MAX_PATH, "\\n", "\n");
}
