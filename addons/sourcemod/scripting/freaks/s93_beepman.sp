/*
	Beepman's Abilities:
	
	Coded by SHADoW NiNE TR3S.
	
	Some code snippets from sarysa & pelipoika
	
	bHop code from SeriTools and ReFlexPoison
	
	rage_scramble:
		arg0 - ability slot
		arg1 - distance
		arg2 - duration
	
	special_hijacksg
		arg1 - Button mode (1 - Reload, 2 - Special)
		arg2 - RAGE cost
		arg3 - Hijack range (default is 'ragedist' value)
		arg4 - Cooldown between uses (default 10 secs)
		arg5 - Grace period (before sentries are completely hijacked)
		
	special_bhop
		arg1 - Use simple bhop or advanced bhop? 1 = simple, 2 = advanced
		
		Advanced bHop
		arg2 - Sets the maximum number of frames the bhop calculation is active after touching the ground
		arg3 - Sets the velocity penalty multiplier per frame the player jumped too late. (1.0 = no penalty)
		
		Simple bhop
		arg4 - Increase velocity by this amount (hammer units)
		arg5 - Auto-bHop? (Press and hold JUMP)
*/

#pragma semicolon 1

#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2items>
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>

#pragma newdecls required

public Plugin myinfo = {
	name = "Freak Fortress 2: Beepman's Abilities",
	author = "93SHADoW",
	description="THE HAAAAAAAAAAAAAX!",
	version="1.3",
};

#define SCRAMBLE "rage_scramble"
#define HIJACK "special_hijacksg"
#define TRAILS "special_trails"
#define BHOP "special_bhop"


bool AfterJumpFrame[MAXPLAYERS+1];
int FloorFrames[MAXPLAYERS+1];
bool PlayerOnGround[MAXPLAYERS+1];
float AirSpeed[MAXPLAYERS + 1][3];
int BaseVelocity;
int MaxBhopFrames[MAXPLAYERS+1];
float FramePenalty[MAXPLAYERS+1];
bool PlayerInTriggerPush[MAXPLAYERS+1];

bool HookedTriggerPushes=false;
bool bHopEnabled[MAXPLAYERS+1];
bool simplebHop[MAXPLAYERS+1];
bool autobHop[MAXPLAYERS+1];

bool HasTrails[MAXPLAYERS+1];

#define INACTIVE 100000000.0
int currentBossIdx;
int enemies;
bool HasHijackAbility[MAXPLAYERS+1]=false;
bool scrambleKeys[MAXPLAYERS+1]=false;
bool IsOnCoolDown[MAXPLAYERS+1]=false;
float ragecost[MAXPLAYERS+1];
float LoopHudNotificationAt[MAXPLAYERS+1]=INACTIVE;
float UnscrambleAt[MAXPLAYERS+1]=INACTIVE;
float CooldownEndsIn[MAXPLAYERS+1]=INACTIVE;

char HUDText[MAXPLAYERS+1][10][256];

int trailIdx[MAXPLAYERS+1];

#define	MAX_EDICT_BITS	11
#define	MAX_EDICTS		(1 << MAX_EDICT_BITS)

int sentryProperties[MAX_EDICTS][10];
int trailOwner[MAX_EDICTS];

public void OnPluginStart2() // No bugs pls
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("arena_win_panel", Event_WinPanel);
}

public void Event_WinPanel(Event event, const char[] name, bool dontBroadcast)
{
	for(int clientIdx=MaxClients; clientIdx; clientIdx--)
	{
		if(!IsValidClient(clientIdx))
		{
			continue;
		}
		if(HookedTriggerPushes)
		{
			UnhookTriggerPushes();
		}
		HasTrails[clientIdx]=false;
		Trail_Remove(clientIdx);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int clientIdx=MaxClients; clientIdx; clientIdx--)
	{
		if(!IsValidClient(clientIdx))
		{
			continue;
		}
		autobHop[clientIdx] = false;
		simplebHop[clientIdx] = false;
		FloorFrames[clientIdx] = MaxBhopFrames[clientIdx] + 1;
		AirSpeed[clientIdx][0] = 0.0;
		AirSpeed[clientIdx][1] = 0.0;
		AfterJumpFrame[clientIdx] = false;
		PlayerInTriggerPush[clientIdx] = false;
		bHopEnabled[clientIdx]=false;
		MaxBhopFrames[clientIdx]=0;
		FramePenalty[clientIdx]=0.0;
		HasTrails[clientIdx]=false;
		LoopHudNotificationAt[clientIdx]=INACTIVE;
		CooldownEndsIn[clientIdx]=INACTIVE;
		UnscrambleAt[clientIdx]=INACTIVE;
		HasHijackAbility[clientIdx]=false;
		scrambleKeys[clientIdx]=false;
		IsOnCoolDown[clientIdx]=false;
		
		Trail_Remove(clientIdx);
		
		int bossIdx=FF2_GetBossIndex(clientIdx); // Well this seems to be the solution to make it multi-boss friendly
		if(bossIdx>=0)
		{
			bHopEnabled[clientIdx]=FF2_HasAbility(bossIdx, this_plugin_name, BHOP);
			if(bHopEnabled[clientIdx])
			{
				HookedTriggerPushes=true;
				simplebHop[clientIdx]=view_as<bool>(FF2_GetAbilityArgument(bossIdx,this_plugin_name, BHOP, 1));
				MaxBhopFrames[clientIdx]=FF2_GetAbilityArgument(bossIdx, this_plugin_name, BHOP, 2, 12);
				FramePenalty[clientIdx]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, BHOP, 3, 0.975);
				autobHop[clientIdx]=view_as<bool>(FF2_GetAbilityArgument(bossIdx,this_plugin_name, BHOP, 5));
			}
			
			if(FF2_HasAbility(bossIdx, this_plugin_name, HIJACK))
			{
				ragecost[clientIdx]=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HIJACK, 2);
				LoopHudNotificationAt[clientIdx]=GetEngineTime()+1.0;
				HasHijackAbility[clientIdx]=true;
				int entity = SpawnWeapon(clientIdx, "tf_weapon_builder", 28, 101, 5, "391 ; 2"); // Builder
				SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
				SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
				SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
				SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
				
				for(int arg=7;arg<=15;arg++)
				{
					ReadCenterText(bossIdx, HIJACK, arg, HUDText[clientIdx][arg-7]);
				}
			}
			
			HasTrails[clientIdx]=FF2_HasAbility(bossIdx, this_plugin_name, TRAILS);
			if(HasTrails[clientIdx])
			{
				char trailPath[PLATFORM_MAX_PATH];
				FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, TRAILS, 1, trailPath, sizeof(trailPath));
				int alpha=FF2_GetAbilityArgument(bossIdx, this_plugin_name, TRAILS, 2);
				
				PrecacheModel(trailPath);
				PrecacheDecal(trailPath, true);
				Trail_Attach(clientIdx, trailPath, alpha, FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TRAILS, 3, 1.0), FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TRAILS, 4, 22.0), FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, TRAILS, 5, 0.0), FF2_GetAbilityArgument(bossIdx, this_plugin_name, TRAILS, 6, 5));
			}
		}
	}
	
	if(HookedTriggerPushes)
	{
		BaseVelocity = FindSendPropInfo("CBasePlayer","m_vecBaseVelocity");
		HookTriggerPushes();
	}
}

public void FF2_OnAbility2(int boss,const char[] plugin_name,const char[] ability_name,int action)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
	int bossIdx=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name, SCRAMBLE)) // Keyboard scramble
	{	
		float pos[3], pos2[3], dist;
		float dist2=FF2_GetAbilityArgumentFloat(boss, this_plugin_name,ability_name, 1, FF2_GetRageDist(boss, this_plugin_name, ability_name));
		GetEntPropVector(bossIdx, Prop_Send, "m_vecOrigin", pos);
		
		enemies=0;
		for(int targetIdx=1;targetIdx<=MaxClients;targetIdx++)
		{
			if(IsValidLivingPlayer(targetIdx))
			{
				GetEntPropVector(targetIdx, Prop_Send, "m_vecOrigin", pos2);
				dist=GetVectorDistance(pos,pos2);
				if(dist<dist2 && GetClientTeam(targetIdx)!=FF2_GetBossTeam())
				{
					scrambleKeys[targetIdx]=true;
					UnscrambleAt[targetIdx]=GetEngineTime()+FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 2);
					enemies++;
				}
			}
		}
		if(enemies==1)
		{
			char bossName[128];
			FF2_GetBossSpecial(boss, bossName, sizeof(bossName));
			CPrintToChatAll(HUDText[bossIdx][5], bossName);
		}
	}
}

stock void ReadCenterText(int bossIdx, const char[] ability_name, int argInt, char[] centerText)
{
	FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, ability_name, argInt, centerText, 256);
	ReplaceString(centerText, 256, "\\n", "\n");
}

public void OnGameFrame()
{
	TickTock(GetEngineTime());
}

public void TickTock(float currentTime)
{
	
	for(int clientIdx=1;clientIdx<=MaxClients;clientIdx++)
	{
		if(!IsValidClient(clientIdx)|| FF2_GetRoundState()!=1 || !FF2_IsFF2Enabled())
			continue;
			
			
		if(bHopEnabled[clientIdx] && !simplebHop[clientIdx])
		{

			if(!PlayerInTriggerPush[clientIdx])
			{
				if(GetEntityFlags(clientIdx) & FL_ONGROUND) 
				{
					if (!PlayerOnGround[clientIdx]) 
					{
						// first ground frame
						PlayerOnGround[clientIdx]=true;
						// reset floor frame counter
						FloorFrames[clientIdx]=0;
					}
					else
					{ 
						// another ground frame
						if(FloorFrames[clientIdx] <= MaxBhopFrames[clientIdx])
						{
							FloorFrames[clientIdx]++;
                        }
                    }
                }
				else // in air 
				{ 
					if(AfterJumpFrame[clientIdx])
					{
						// apply the boostsecond air frame 
						// to prevent some glitchiness
						// only apply within the maxbhopframes range
                        if(FloorFrames[clientIdx] <= MaxBhopFrames[clientIdx])
						{
							float finalvec[3];
							// get current speed
							GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", finalvec);
							// calculate difference between the speed on the last air frame
							// before hitting the ground and the speed while in the second air frame
							// and apply the late jump penalty to it
							finalvec[0] = ((AirSpeed[clientIdx][0] - finalvec[0]) * Pow(FramePenalty[clientIdx], float(FloorFrames[clientIdx])));
							finalvec[1] = ((AirSpeed[clientIdx][1] - finalvec[1]) * Pow(FramePenalty[clientIdx], float(FloorFrames[clientIdx])));
							finalvec[2] = 0.0;
							// set the difference as boost
							SetEntDataVector(clientIdx, BaseVelocity, finalvec, true);					
                        }
                        AfterJumpFrame[clientIdx] = false;
                    }
					if(PlayerOnGround[clientIdx])
					{ 
						// first air frame
						// player not on ground anymore
						PlayerOnGround[clientIdx] = false;
						AfterJumpFrame[clientIdx] = true;
					}
					else 
					{
						// get air speed
						// NOTE: this has to be done every airframe
						// to have the last speed value of the frame _before_ landing,
						// not of the landing frame itself, as the speed is already changed
						// in that frame if the player lands on sloped surfaces in some
						// angles :/
						GetEntPropVector(clientIdx, Prop_Data, "m_vecVelocity", AirSpeed[clientIdx]);
					}
				}
			}
        }
		
		if(currentTime>=CooldownEndsIn[clientIdx])
		{
			if(IsBoss(clientIdx) && HasHijackAbility[clientIdx])
			{
				SetHudTextParams(-1.0, 1.0, 1.0, 0, 255, 0, 255);
				ShowHudText(clientIdx, -1, HUDText[clientIdx][2]);	
				IsOnCoolDown[clientIdx]=false;
				CooldownEndsIn[clientIdx]=INACTIVE;
			}
		}
		
		if(currentTime>=LoopHudNotificationAt[clientIdx])
		{
			if(IsBoss(clientIdx) && FF2_GetBossCharge(FF2_GetBossIndex(clientIdx),0)>=ragecost[clientIdx] && !IsOnCoolDown[clientIdx] && HasHijackAbility[clientIdx])
			{
				int buttonmode=FF2_GetAbilityArgument(FF2_GetBossIndex(clientIdx), this_plugin_name, HIJACK, 1);
				
				SetHudTextParams(-1.0, 1.0, 1.0, 0, 255, 0, 255);
				ShowHudText(clientIdx, -1, HUDText[clientIdx][1], HUDText[clientIdx][buttonmode==1 ? 3 : 4], RoundFloat(ragecost[clientIdx]));	
			}		
			LoopHudNotificationAt[clientIdx]=GetEngineTime()+1.0;
		}
		
		if(currentTime>=UnscrambleAt[clientIdx])
		{
			if(enemies==1)
			{
				CPrintToChatAll(HUDText[clientIdx][IsPlayerAlive(clientIdx) ? 6 : 7]);
				enemies=0;
			}
			scrambleKeys[clientIdx]=false;
			UnscrambleAt[clientIdx]=INACTIVE;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	/*
	 * TO-DO: i really gotta start organizing this crap.
	 */
	 
	int bossIdx=FF2_GetBossIndex(client);
	if(bossIdx>=0 && bHopEnabled[client] && simplebHop[client] && GetEntityFlags(client) & FL_ONGROUND && buttons & IN_JUMP)
	{	
		static float fVelocity[3];
		static bool negativefloat=false;
	
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
		
		if(autobHop[client])
		{
			fVelocity[2]=267.0;
		}
		
		negativefloat=fVelocity[1]<0.0 ? true : false;
		
		if(negativefloat)
		{
			fVelocity[1] -= FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, BHOP, 4, 1.0);
		}
		else
		{
			fVelocity[1] += FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, BHOP, 4, 1.0);
		}
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
		
		if(FF2_GetAbilityArgument(bossIdx,this_plugin_name,BHOP,6))
		{
			PrintToChat(client, "Velocity: %f", fVelocity[1]);
		}
		
		return Plugin_Continue;
	}
	
	// Sentry Hijack
	if(bossIdx>=0 && FF2_HasAbility(bossIdx, this_plugin_name, HIJACK))
	{
		int buttonmode=FF2_GetAbilityArgument(bossIdx, this_plugin_name, HIJACK, 1); // Use RELOAD, or SPECIAL to activate ability
		if(buttonmode==2 &&(buttons & IN_ATTACK3) || buttonmode==1 && (buttons & IN_RELOAD))
		{
			if(IsOnCoolDown[client]) // Prevent ability from firing if ability is on cooldown
			{
				switch(buttonmode)
				{
					case 1: buttons &= ~IN_RELOAD;
					case 2: buttons &= ~IN_ATTACK3;
				}
				SetHudTextParams(-1.0, 0.96, 3.0, 255, 0, 0, 255);
				ShowHudText(client, -1, HUDText[bossIdx][0]);	
				return Plugin_Changed;
			}
			
			if(FF2_GetBossCharge(bossIdx, 0)<ragecost[client]) // Not enough RAGE, prevent ability
			{
				switch(buttonmode)
				{
					case 1: buttons &= ~IN_RELOAD;
					case 2: buttons &= ~IN_ATTACK3;
				}
				SetHudTextParams(-1.0, 0.96, 3.0, 255, 0, 0, 255);
				ShowHudText(client, -1, HUDText[bossIdx][8], RoundFloat(ragecost[client]));	
				return Plugin_Changed;
			}
			
			// Else, we start the sentry hijack process
			
			float bossPosition[3], buildingPosition[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
			float duration=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HIJACK, 1, 4.0); // Grace period between disabling and fully hijacking sentry
			
			int building, sentry;
			while((building=FindEntityByClassname(building, "obj_sentrygun"))!=-1) // Let's look for sentries to hijack
			{
				GetEntPropVector(building, Prop_Send, "m_vecOrigin", buildingPosition);
				if(GetVectorDistance(bossPosition, buildingPosition)<=FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HIJACK, 3) && GetEntProp(building, Prop_Send, "m_iTeamNum")!=FF2_GetBossTeam())
				{
					SetEntProp(building, Prop_Data, "m_takedamage", 0);
					SetEntProp(building, Prop_Send, "m_bDisabled", 1);
					CreateTimer(duration, Timer_Hijack, EntIndexToEntRef(building));
					sentry++;
				}
			}
			
			if(sentry) // Let's not drain RAGE if no sentries are within range.
			{
				FF2_SetBossCharge(bossIdx, 0, FF2_GetBossCharge(bossIdx,0)-ragecost[client]);
				currentBossIdx=client;
				IsOnCoolDown[client]=true;
				CooldownEndsIn[client]=GetEngineTime()+FF2_GetAbilityArgumentFloat(bossIdx, this_plugin_name, HIJACK, 4, 10.0);
				switch(buttonmode)
				{
					case 1: buttons &= ~IN_RELOAD;
					case 2: buttons &= ~IN_ATTACK3;
				}
				return Plugin_Changed;
			}
			
			return Plugin_Continue;
		}
		return Plugin_Continue;
	}


	// Keyboard scramble 
	if(IsValidLivingPlayer(client) && scrambleKeys[client]) // Only affect raged players...
	{
		switch(GetRandomInt(1,27)) // Fake lag
		{
			case 1: GetRandomInt(1,2)==1 ? (buttons &= IN_ATTACK) : (buttons &= ~IN_ATTACK);
			case 2: GetRandomInt(1,2)==1 ? (buttons &= IN_ATTACK2) : (buttons &= ~IN_ATTACK2);
			case 3: GetRandomInt(1,2)==1 ? (buttons &= IN_ATTACK3) : (buttons &= ~IN_ATTACK3);
			case 4: GetRandomInt(1,2)==1 ? (buttons &= IN_JUMP) : (buttons &= ~IN_JUMP);
			case 5: GetRandomInt(1,2)==1 ? (buttons &= IN_DUCK) : (buttons &= ~IN_DUCK);
			case 6: GetRandomInt(1,2)==1 ? (buttons &= IN_FORWARD) : (buttons &= ~IN_FORWARD);
			case 7: GetRandomInt(1,2)==1 ? (buttons &= IN_BACK) : (buttons &= ~IN_BACK);
			case 8: GetRandomInt(1,2)==1 ? (buttons &= IN_USE) : (buttons &= ~IN_USE);
			case 9: GetRandomInt(1,2)==1 ? (buttons &= IN_CANCEL) : (buttons &= ~IN_CANCEL);
			case 10: GetRandomInt(1,2)==1 ? (buttons &= IN_LEFT) : (buttons &= ~IN_LEFT);
			case 11: GetRandomInt(1,2)==1 ? (buttons &= IN_RIGHT) : (buttons &= ~IN_RIGHT);
			case 12: GetRandomInt(1,2)==1 ? (buttons &= IN_MOVELEFT) : (buttons &= ~IN_MOVELEFT);
			case 13: GetRandomInt(1,2)==1 ? (buttons &= IN_MOVERIGHT) : (buttons &= ~IN_MOVERIGHT);
			case 14: GetRandomInt(1,2)==1 ? (buttons &= IN_RUN) : (buttons &= ~IN_RUN);
			case 15: GetRandomInt(1,2)==1 ? (buttons &= IN_RELOAD) : (buttons &= ~IN_RELOAD);
			case 16: GetRandomInt(1,2)==1 ? (buttons &= IN_ALT1) : (buttons &= ~IN_ALT1);
			case 17: GetRandomInt(1,2)==1 ? (buttons &= IN_ALT2) : (buttons &= ~IN_ALT2);
			case 18: GetRandomInt(1,2)==1 ? (buttons &= IN_SCORE) : (buttons &= ~IN_SCORE);
			case 19: GetRandomInt(1,2)==1 ? (buttons &= IN_WALK) : (buttons &= ~IN_WALK);
			case 20: GetRandomInt(1,2)==1 ? (buttons &= IN_ZOOM) : (buttons &= ~IN_ZOOM);
			case 21: GetRandomInt(1,2)==1 ? (buttons &= IN_WEAPON1) : (buttons &= ~IN_WEAPON1);
			case 22: GetRandomInt(1,2)==1 ? (buttons &= IN_WEAPON2) : (buttons &= ~IN_WEAPON2);
			case 23: GetRandomInt(1,2)==1 ? (buttons &= IN_BULLRUSH) : (buttons &= ~IN_BULLRUSH);
			case 24: GetRandomInt(1,2)==1 ? (buttons &= IN_GRENADE1) : (buttons &= ~IN_GRENADE1);	
			case 25: GetRandomInt(1,2)==1 ? (buttons &= IN_GRENADE2) : (buttons &= ~IN_GRENADE2);
			case 26: return Plugin_Handled;
			case 27: return Plugin_Continue;
		}
		switch(GetRandomInt(1,4)) // More fake lag rage
		{
			case 1: return Plugin_Handled;
			case 2: return Plugin_Continue;
			case 3: return Plugin_Handled;
			case 4: return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public Action Timer_Hijack(Handle timer, any buildingIdx) // Grace period ends here
{
	int owner;
	int building=EntRefToEntIndex(buildingIdx);
	if(FF2_GetRoundState()==1 && building>MaxClients && IsValidEntity(building))
	{
		if ((owner = GetEntDataEnt2(building, FindSendPropInfo("CObjectSentrygun", "m_hBuilder"))) != -1)
		{
			SetEntProp(building, Prop_Data, "m_takedamage", 2);
			SetEntProp(building, Prop_Send, "m_bDisabled", 0);
			
			// Retrieve original sentry properties
			sentryProperties[building][0] = GetEntDataEnt2(building, FindSendPropInfo("CObjectSentrygun", "m_hBuilder"));
			sentryProperties[building][1] = GetEntProp(building, Prop_Send, "m_iTeamNum");
			sentryProperties[building][2] = GetEntProp(building, Prop_Send, "m_nSkin");
			
			owner=currentBossIdx;
			AcceptEntityInput(building, "SetBuilder", owner);
			SetEntPropEnt(building, Prop_Send, "m_hBuilder", owner);
			SetEntProp(building, Prop_Send, "m_iTeamNum", GetClientTeam(owner));
			SetEntProp(building, Prop_Send, "m_nSkin", GetClientTeam(owner) - 2);
			
			float duration2=FF2_GetAbilityArgumentFloat(FF2_GetBossIndex(currentBossIdx), this_plugin_name, HIJACK, 6);
			if(duration2)
			{
				CreateTimer(duration2, Timer_RestoreSentry, EntIndexToEntRef(building));
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_RestoreSentry(Handle timer, any buildingIdx) // Restore
{
	int owner;
	int building=EntRefToEntIndex(buildingIdx);
	if(FF2_GetRoundState()==1 && building>MaxClients && IsValidEntity(building))
	{
		if ((owner = GetEntDataEnt2(building, FindSendPropInfo("CObjectSentrygun", "m_hBuilder"))) != -1)
		{
			owner=sentryProperties[building][0];
			AcceptEntityInput(building, "SetBuilder", owner);
			SetEntPropEnt(building, Prop_Send, "m_hBuilder", sentryProperties[building][0]);
			SetEntProp(building, Prop_Send, "m_iTeamNum", sentryProperties[building][1]);
			SetEntProp(building, Prop_Send, "m_nSkin", sentryProperties[building][2]);			
		}
	}
	return Plugin_Continue;
}

stock bool IsPlayerCloaked(int client)
{
	return (TF2_IsPlayerInCondition(client, TFCond_Cloaked) || TF2_IsPlayerInCondition(client, TFCond_Stealthed) || TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade));
}

// We need to spawn tf_weapon_builder, hence this.
stock int SpawnWeapon(int client, char[] name, int index, int level, int qual, char[] att)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2 = 0;
		for (int i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==null)
		return -1;
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;
	EquipPlayerWeapon(client, entity);
	return entity;
}

// Check for valid boss
stock bool IsBoss(int client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	return true;
}

// Stocks below by sarysa
stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client);
}

stock bool IsValidLivingPlayer(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;
		
	return IsClientInGame(client) && IsPlayerAlive(client);
}

// TRAILS :D
void Trail_Attach(int client, char[] trail, int alpha, float lifetime=1.0, float startwidth=22.0, float endwidth=0.0, int rendermode)
{
	int entIndex = CreateEntityByName("env_spritetrail");
	if (entIndex > 0 && IsValidEntity(entIndex))
	{
		trailIdx[client] = entIndex;
		trailOwner[entIndex] = client;
		char strTargetName[MAX_NAME_LENGTH];
		GetClientName(client, strTargetName, sizeof(strTargetName));

		DispatchKeyValue(client, "targetname", strTargetName);
		Format(strTargetName,sizeof(strTargetName),"clienttrail%d",client);
		DispatchKeyValue(client, "targetname", strTargetName);
		DispatchKeyValue(entIndex, "parentname", strTargetName);
		

		DispatchKeyValue(entIndex, "spritename", trail);
		SetEntPropFloat(entIndex, Prop_Send, "m_flTextureRes", 0.05);
			
		char sTemp[5];
		IntToString(alpha, sTemp, sizeof(sTemp));
		DispatchKeyValue(entIndex, "renderamt", sTemp);
			
		DispatchKeyValueFloat(entIndex, "lifetime", lifetime);
		DispatchKeyValueFloat(entIndex, "startwidth", startwidth);
		DispatchKeyValueFloat(entIndex, "endwidth", endwidth);
		
		IntToString(rendermode, sTemp, sizeof(sTemp));
		DispatchKeyValue(entIndex, "rendermode", sTemp);
			
		DispatchSpawn(entIndex);
		float f_origin[3];
		GetClientAbsOrigin(client, f_origin);
		f_origin[2] += 14.0; // 34
		TeleportEntity(entIndex, f_origin, NULL_VECTOR, NULL_VECTOR);
		SetVariantString(strTargetName);
		AcceptEntityInput(entIndex, "SetParent");
		
		SDKHook(entIndex, SDKHook_SetTransmit, Hook_SetTransmit);
	}	
}

void Trail_Remove(int client)
{
	int ent = trailIdx[client];
	if (ent != 0)
	{
		SDKUnhook(ent, SDKHook_SetTransmit, Hook_SetTransmit);
		if (IsValidEntity(ent))
		{
			AcceptEntityInput(ent, "Kill");
		}
		trailIdx[client] = 0;
	}
}

public Action Hook_SetTransmit(int entity, int client)
{
	if(IsPlayerCloaked(trailOwner[entity]))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void HookTriggerPushes()
{
	// hook trigger_pushes to disable velocity calculation in these, allowing
	// the push to be applied correctly
	int index = -1;
	while ((index = FindEntityByClassname2(index, "trigger_push"))!=-1)
	{
		SDKHook(index, SDKHook_StartTouch, Event_EntityOnStartTouch);
		SDKHook(index, SDKHook_EndTouch, Event_EntityOnEndTouch);
	}
	HookedTriggerPushes=true;
}

void UnhookTriggerPushes()
{
    // unhook trigger_pushes to disable velocity calculation in these, allowing
    // the push to be applied correctly
	int index = -1;
	while((index = FindEntityByClassname2(index, "trigger_push")) != -1)
	{
		SDKUnhook(index, SDKHook_StartTouch, Event_EntityOnStartTouch);
		SDKUnhook(index, SDKHook_EndTouch, Event_EntityOnEndTouch);
	}
	HookedTriggerPushes=false;
}

int FindEntityByClassname2(int startEnt, const char[] classname)
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt))
	{
		startEnt--;
	}
	return FindEntityByClassname(startEnt, classname);
}

public void Event_EntityOnStartTouch(int entity, int client)
{
    if (client <= MAXPLAYERS
        && IsValidEntity(client)
        && IsClientInGame(client)) {
        PlayerInTriggerPush[client] = true;
    }
}

public void Event_EntityOnEndTouch(int entity, int client)
{
    if(client <= MAXPLAYERS && IsValidEntity(client) && IsClientInGame(client))
	{
		PlayerInTriggerPush[client] = false;
    }
}