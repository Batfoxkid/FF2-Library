#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <ff2_ams>

#define MAJOR_REVISION "3"
#define MINOR_REVISION "0"
#define PATCH_REVISION "1"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

public Plugin:myinfo = {
	name = "Freak Fortress 2: M7's new Abilities",
	author = "M76030",
	version = PLUGIN_VERSION,
};

//General thing(s)
#define INACTIVE 100000000.0
#define MAX_WEAPON_NAME_LENGTH 64
#define MAX_WEAPON_ARG_LENGTH 256
#define MAX_ENTITY_CLASSNAME_LENGTH 48

enum VoiceMode
{
	VoiceMode_None=-1,
	VoiceMode_Normal,
	VoiceMode_Robot,
	VoiceMode_BossCatchPhrase,
	VoiceMode_CatchPhrase,
}

enum Operators
{
	Operator_None=0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

//Charge_New_Salmon
#define SALMON_NEW "charge_new_salmon"
#define ZEPH_SND "ambient/siren.wav"
new Handle:jumpHUD;
new bEnableSuperDuperJump[MAXPLAYERS+1];
new SummonerIndex[MAXPLAYERS+1];
new String:SalmonModel[PLATFORM_MAX_PATH], String:Classname[64], String:Attributes[768], String:Condition[768];
new Sound, Minions, Notify, ModelMode, Class, Wearables, WeaponMode, WeaponIndex, Accessoires, Ammo, Clip, VO, PickupMode;
new Float:UberchargeDuration;
VoiceMode VOMode[MAXPLAYERS+1];

//Rage Outline
#define OUTLINE "rage_outline"
#define OUTLINEALIAS "ROL"
new bool:Outline_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Outline)
new Float:EndOutline;
new Float:Outlinedistance;

//Rage Buffs
#define BUFFS "rage_buffs"
#define BUFFSALIAS "RBF"
new bool:Buffs_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Buffs)
new Buffmode;

//Slay Minions
#define SLAY "slay_minions"
#define SLAYALIAS "SMO"
new bool:Slay_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Slay Minions)

//Special Fire
#define FIRE "special_fire"
#define FIREALIAS "SPF"
new bool:Fire_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Fire)
new bool:FireEnabled = true;
new Float:EndFire;
new Float:FireRange;

//Special Multimelees
#define MULTIWEAPONS "special_multimelee"
#define MWS_MAX_WEAPONS 10
new MWS_WeaponCount[MAXPLAYERS+1]; // arg2
new MWS_Slot[MAXPLAYERS+1][MWS_MAX_WEAPONS]; // argX6 (16, 26, 36...106)


#define SPECIALOUTLINE "special_outline"
#define AMSSTUN "special_ams_stun"
#define AMSSTUNALIAS "SAS"
#define MADMILKSTUN "special_stun"


// New Abilities
#define RAGETHEMECHANGE "special_ragetheme"
new String:RAGETHEME[PLATFORM_MAX_PATH];
new String:NORMALTHEME[PLATFORM_MAX_PATH];
new Handle:RageThemeTimer;
new StopMusic_RageVersion;
new bool:PlayingRightNow;

#define LIFELOSTHEMECHANGE "special_lifelose_theme"
new String:LIFELOSETHEME[PLATFORM_MAX_PATH];
new StopMusic_LifeLoseVersion;

#define LASTPLAYERSTHEME "special_lastman_theme"
new String:FEWPLAYERSTHEME[PLATFORM_MAX_PATH];
new StopMusic_FewPlayerVersion;

#define TRANSFORMATION "lifelose_transformation"
new String:lifelose_model[PLATFORM_MAX_PATH], String:lifelose_weapon_classname[32], String:lifelose_weapon_attributes[512];
new lifelose_playerclass, lifelose_weapon_defindex; 

#define REVIVE_BOSSES "rage_revive_bosses"
new bool:ReviveBosses_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
#define HEAL_BOSSES "rage_heal_bosses"
new bool:HealBosses_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

#define HEALTHONKILL "health_on_kill"
new Float:amountgainedhealth;
#define RAGEONKILL "rage_on_kill"
new Float:amountgainedrage;

public OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", event_round_end, EventHookMode_PostNoCopy);
	HookEvent("player_death", event_player_death);
	
	AddNormalSoundHook(SoundHook);
	jumpHUD = CreateHudSynchronizer();
	LoadTranslations("ff2_newsalmon.charge");
	PrecacheSound(ZEPH_SND,true);
}


public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
		
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			//For Charge_New_Salmon
			bEnableSuperDuperJump[client]=false;
			SummonerIndex[client]=-1;
			
			//for Rage_Outline
			EndOutline = INACTIVE;
			Outline_TriggerAMS[client] = false;
			
			//for Rage_Buffs
			Buffs_TriggerAMS[client] = false;
			
			//for Slay_Minions
			Slay_TriggerAMS[client] = false;
			
			//for Special_Fire
			EndFire = INACTIVE;
			Fire_TriggerAMS[client] = false;
			
			// for Healing and Reviving abilities
			ReviveBosses_TriggerAMS[client]=false;
			HealBosses_TriggerAMS[client]=false;
			
			VOMode[client]=VoiceMode_Normal;
			
			StopMusic_RageVersion = 0;
			StopMusic_LifeLoseVersion = 0;
			StopMusic_FewPlayerVersion = 0;
			PlayingRightNow = false;
			
			new boss=FF2_GetBossIndex(client);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, this_plugin_name, OUTLINE))
				{
					Outline_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, OUTLINE);
					if(Outline_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, OUTLINE, OUTLINEALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, BUFFS))
				{
					Buffs_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, BUFFS);
					if(Buffs_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, BUFFS, BUFFSALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, SLAY))
				{
					Slay_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, SLAY);
					if(Slay_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, SLAY, SLAYALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, FIRE))
				{
					Fire_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, FIRE);
					if(Fire_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, FIRE, FIREALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
			
				if(FF2_HasAbility(boss, this_plugin_name, SPECIALOUTLINE))
				{
					if(FF2_GetAbilityArgument(boss, this_plugin_name, SPECIALOUTLINE, 1))
						CreateTimer(1.0, Timer_OutlineStart, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

					CreateTimer(1.0, Timer_OutlineLoop, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				}
				if(FF2_HasAbility(boss, this_plugin_name, MADMILKSTUN))
				{
					for(new i=1; i<=MaxClients; i++)
					{
						if(IsClientInGame(i) && IsPlayerAlive(i))
						{
							SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
						}
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, AMSSTUN))
				{
					AMS_InitSubability(boss, client, this_plugin_name, AMSSTUN, AMSSTUNALIAS); // Important function to tell AMS that this subplugin supports it
				}
				
				if(FF2_HasAbility(boss, this_plugin_name, REVIVE_BOSSES))
				{
					ReviveBosses_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, REVIVE_BOSSES);
					if(ReviveBosses_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, REVIVE_BOSSES, "REVI"); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, HEAL_BOSSES))
				{
					HealBosses_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, HEAL_BOSSES);
					if(HealBosses_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, HEAL_BOSSES, "HEAL"); // Important function to tell AMS that this subplugin supports it
					}
				}
			}
		}
	}
}

public Action:event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			Outline_TriggerAMS[client] = false;
			SDKUnhook(client, SDKHook_PreThink, Outline_Prethink);
			
			//for Rage_Buffs
			Buffs_TriggerAMS[client] = false;
			
			//for Slay_Minions
			Slay_TriggerAMS[client] = false;
			
			//for Special_Fire
			Fire_TriggerAMS[client] = false;
			SDKUnhook(client, SDKHook_PreThink, Fire_Prethink);
			
			// for Healing and Reviving abilities
			ReviveBosses_TriggerAMS[client]=false;
			HealBosses_TriggerAMS[client]=false;
			
			// Sound Stops
			StopSound(client, SNDCHAN_AUTO, RAGETHEME);
			StopSound(client, SNDCHAN_AUTO, NORMALTHEME);
			StopSound(client, SNDCHAN_AUTO, LIFELOSETHEME);
			StopSound(client, SNDCHAN_AUTO, FEWPLAYERSTHEME);
		}
	}
	EndOutline = INACTIVE;
	EndFire = INACTIVE;
	PlayingRightNow = false;
	
	if(RageThemeTimer)
	{
		KillTimer(RageThemeTimer);
		RageThemeTimer = INVALID_HANDLE;
	}
	
	StopMusic_RageVersion = 0;
	StopMusic_LifeLoseVersion = 0;
	StopMusic_FewPlayerVersion = 0;
}

public Action:event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return Plugin_Continue;
	}
	
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	
	new boss=FF2_GetBossIndex(attacker); // Boss is an attacker
	if(boss!=-1)
	{
		if(FF2_HasAbility(boss, this_plugin_name, MULTIWEAPONS))
		{
			static String:weaponName[MAX_WEAPON_NAME_LENGTH];
			static String:weaponArgs[MAX_WEAPON_ARG_LENGTH];
			
			new rand = GetRandomInt(0, MWS_WeaponCount[attacker] - 1);
			new argOffset = (rand + 1) * 10;
			
			MWS_WeaponCount[attacker] = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, 1);
			new bool:Allweaponsgone = bool:FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, 2);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, MULTIWEAPONS, argOffset + 1, weaponName, MAX_WEAPON_NAME_LENGTH);
			new weaponIdx = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 2);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, MULTIWEAPONS, argOffset + 3, weaponArgs, MAX_WEAPON_ARG_LENGTH);
			new weaponVisibility = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 4);
			new alpha = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 5);
			new clip = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 7);
			new ammo = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 8);
			
			MWS_WeaponCount[attacker] = min(MWS_WeaponCount[attacker], MWS_MAX_WEAPONS);
			for (new i = 0; i < MWS_WeaponCount[attacker]; i++)
			{
				new offset = (10 * (i + 1));
				// a couple need to be stored as they're needed often
				MWS_Slot[attacker][i] = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, 6 + offset);
			}
	
			PrepareForWeaponSwitch(attacker, true);
			
			if(Allweaponsgone)
				TF2_RemoveAllWeapons(attacker);
			else
				TF2_RemoveWeaponSlot(attacker, MWS_Slot[attacker][rand]);
				
			new weapon = SpawnWeapon(attacker, weaponName, weaponIdx, 101, 5, weaponArgs, weaponVisibility);
	
			// alpha transparency, best if the viewmodel doesn't hold it well
			if (alpha != 255)
			{
				SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(weapon, 255, 255, 255, alpha);
			}
		
			// set clip and ammo last
			new offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
			if (offset >= 0)
			{
				SetEntProp(attacker, Prop_Send, "m_iAmmo", ammo, 4, offset);
				
				// the weirdness below is to avoid setting clips for invalid weapons like huntsman, flamethrower, minigun, and sniper rifles.
				// without the check below, these weapons would break.
				// as for energy weapons, I frankly don't care. they're a mess. don't use this code for making energy weapons.
				if (GetEntProp(weapon, Prop_Send, "m_iClip1") > 1 && GetEntProp(weapon, Prop_Send, "m_iClip1") < 128)
					SetEntProp(weapon, Prop_Send, "m_iClip1", clip);
			}
	
			// delay primary/secondary attack ever so slightly
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.5);
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 0.5);
		}
		
		if(FF2_HasAbility(boss, this_plugin_name, LASTPLAYERSTHEME))
		{
			new Playerleft = FF2_GetAbilityArgument(boss, this_plugin_name, LASTPLAYERSTHEME, 1);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, LASTPLAYERSTHEME, 2, FEWPLAYERSTHEME, sizeof(FEWPLAYERSTHEME));
			
			new playercount;
			for (new player = 1; player <= MaxClients; player++)
			{
				if (IsClientInGame(player) && IsPlayerAlive(player))
				{
					playercount++;
				}
			}
		
			if (playercount == Playerleft && !StopMusic_FewPlayerVersion) // play LMS over KS (event is before player dies, so there will be 1+boss+deader
			{
				FF2_StopMusic(0);
		
				if(FEWPLAYERSTHEME[0] != '\0')
				{
					PrecacheSound(FEWPLAYERSTHEME, true);
					EmitSoundToAll(FEWPLAYERSTHEME);
				}
				else
				{
					if(FF2_RandomSound("sound_fewplayersleft_theme", FEWPLAYERSTHEME, sizeof(FEWPLAYERSTHEME), boss))
					{
						EmitSoundToAll(FEWPLAYERSTHEME);
					}		
				}
				
				StopMusic_FewPlayerVersion++;
			}
		}
		if(FF2_HasAbility(boss, this_plugin_name, RAGEONKILL))
		{
			Float:amountgainedrage = FF2_GetAbilityArgumentFloat(boss,this_plugin_name,RAGEONKILL,1,0.0);
			new Float:rage = FF2_GetBossCharge(boss,0);
			new Float:ragetogive;
		
			if(rage + amountgainedrage > 100.0) // We don't want RAGE to exceed more than 100%
				ragetogive = 100.0;
			else if (rage + amountgainedrage < 100.0)
				ragetogive = rage+amountgainedrage;
		
			FF2_SetBossCharge(boss, 0, ragetogive);
		}
	
		if(FF2_HasAbility(boss, this_plugin_name, HEALTHONKILL))
		{
			Float:amountgainedhealth = FF2_GetAbilityArgumentFloat(boss,this_plugin_name,HEALTHONKILL,1,0.0);
		
			new health = FF2_GetBossHealth(boss);
			new maxhealth = FF2_GetBossMaxHealth(boss)*FF2_GetBossLives(boss);
		
			if(amountgainedhealth <= 1)
			{
				health = RoundToCeil(health + (maxhealth * amountgainedhealth));
			}
			else
			{
				health = RoundToCeil(health + amountgainedhealth);
			}
			if(health > maxhealth)
			{
				health = maxhealth;
			}
			
			FF2_SetBossHealth(boss, health);
		}
	}
	
	boss=FF2_GetBossIndex(client);	// Boss is the victim
	if(boss!=-1 && FF2_HasAbility(boss, this_plugin_name, SALMON_NEW) && !(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		for(new clone=1; clone<=MaxClients; clone++)
		{
			if(SummonerIndex[clone]==boss && IsValidClient(clone) && IsValidMinion(clone) && IsPlayerAlive(clone))
			{
				SummonerIndex[clone]=-1;
				ChangeClientTeam(clone, (FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue));
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{	
	if (attacker<1 || attacker>MaxClients || !IsValidClient(attacker))
		return Plugin_Continue;	
	new index = FF2_GetBossIndex(attacker);
	if (index!=-1 && client!=attacker && FF2_HasAbility(index, this_plugin_name, MADMILKSTUN) && GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon"))
	{
		new bool:Meleestun = bool:FF2_GetAbilityArgument(index, this_plugin_name, MADMILKSTUN, 2, 0);
		if (!Meleestun && GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
		{
			
		}
		else
		{
			new Float:duration=FF2_GetAbilityArgumentFloat(index, this_plugin_name, MADMILKSTUN, 1, 3.0);
			if (duration>0.25)
				TF2_StunPlayer(client, duration, 0.0, TF_STUNFLAGS_NORMALBONK, attacker);
		}	
	}
	return Plugin_Continue;
}

public Action:FF2_OnAbility2(boss,const String:plugin_name[],const String:ability_name[],action)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	new slot=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 0);
	if(!strcmp(ability_name,BUFFS))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Buffs_TriggerAMS[client]=false;
		}
		
		if(!Buffs_TriggerAMS[client])
			RBF_Invoke(client);
	}
	else if (!strcmp(ability_name,OUTLINE))
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Outline_TriggerAMS[client]=false;
		}
		
		if(!Outline_TriggerAMS[client])
			ROL_Invoke(client);
	}
	else if (!strcmp(ability_name,FIRE))
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Fire_TriggerAMS[client]=false;
		}
		
		if(!Fire_TriggerAMS[client])
			SPF_Invoke(client);
	}
	else if (!strcmp(ability_name,SLAY))
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Slay_TriggerAMS[client]=false;
		}
		
		if(!Slay_TriggerAMS[client])
			SMO_Invoke(client);
	}
	else if (!strcmp(ability_name,SALMON_NEW))
		Charge_New_Salmon(ability_name,boss,client,slot,action);
		
	// New Abilities
	else if(!strcmp(ability_name,RAGETHEMECHANGE))
	{
		new Float:duration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 1);
		FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 2, RAGETHEME, sizeof(RAGETHEME));

		if(!StopMusic_RageVersion)
		{
			FF2_StopMusic(0);
		
			StopMusic_RageVersion++;
		}
		
		if(!PlayingRightNow)
		{
			for(new i=0;i<=MaxClients;i++)
			{
				StopSound(i, SNDCHAN_AUTO, NORMALTHEME);
			}
		
			if(RAGETHEME[0] != '\0')
			{
				PrecacheSound(RAGETHEME, true);
				EmitSoundToAll(RAGETHEME);
			}
			else
			{
				if(FF2_RandomSound("sound_rage_theme", RAGETHEME, sizeof(RAGETHEME), boss))
				{
					EmitSoundToAll(RAGETHEME);
				}
			}
			
			PlayingRightNow = true;
		
			RageThemeTimer = CreateTimer(duration, BackToNormal, client);
		}
	}
	else if(!strcmp(ability_name,REVIVE_BOSSES))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			ReviveBosses_TriggerAMS[client]=false;
		}
		
		if(!ReviveBosses_TriggerAMS[client])
			REVI_Invoke(client);
	}
	else if(!strcmp(ability_name,HEAL_BOSSES))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			HealBosses_TriggerAMS[client]=false;
		}
		
		if(!HealBosses_TriggerAMS[client])
			HEAL_Invoke(client);
	}

	return Plugin_Continue;
}

public Action:Timer_OutlineLoop(Handle:timer)
{
	if(FF2_GetRoundState() != 1)
		return Plugin_Stop;

	for(new player=1; player<=MaxClients; player++)
	{
		if(IsClientInGame(player) && IsPlayerAlive(player))
		{
			if(GetClientTeam(player) != FF2_GetBossTeam())
				SetEntProp(player, Prop_Send, "m_bGlowEnabled", 1);

			TF2_AddCondition(player, TFCond_SpawnOutline, -1.0);
		}
	}
	return Plugin_Continue;
}

public Action:Timer_OutlineStart(Handle:timer, any:userid)
{
	new client=GetClientOfUserId(userid);
	TF2_AddCondition(client, TFCond_Healing, -1.0);
	TF2_AddCondition(client, TFCond_HalloweenQuickHeal, 170.0);
	return Plugin_Continue;
}

public Action:BackToNormal(Handle:timer, any:client)
{
	new boss=FF2_GetBossIndex(client);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, RAGETHEMECHANGE, 3, NORMALTHEME, sizeof(NORMALTHEME));
	
	for(new player=0;player<=MaxClients;player++)
	{
		StopSound(player, SNDCHAN_AUTO, RAGETHEME);
	}
	
	if(NORMALTHEME[0] != '\0')
	{
		PrecacheSound(NORMALTHEME, true);
		EmitSoundToAll(NORMALTHEME);
	}
	else
	{
		if(FF2_RandomSound("sound_normal_theme", NORMALTHEME, sizeof(NORMALTHEME), boss))
		{
			EmitSoundToAll(NORMALTHEME);
		}		
	}
	
	PlayingRightNow = false;
	RageThemeTimer = INVALID_HANDLE;
	
	return Plugin_Continue;
}


public bool:RBF_CanInvoke(client)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Buffed)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_DefenseBuffNoCritBlock)) return false;
	if(TF2_IsPlayerInCondition(client, TFCond_RegenBuffed)) return false;
	return true;
}

public RBF_Invoke(client)
{
	new Boss=FF2_GetBossIndex(client);
	Buffmode = FF2_GetAbilityArgument(Boss, this_plugin_name, BUFFS, 1); // Buff type
	
	if(Buffs_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_buffs", sound, sizeof(sound), Boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);	
		}
	}
	
	if(Buffmode==-1) // Random Buff
		Buffmode=GetRandomInt(0,6);
	if(Buffmode == 0 || Buffmode == 1 || Buffmode == 4 || Buffmode == 5)
	{
		TF2_AddCondition(client, TFCond_Buffed, FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, BUFFS, 2, 5.0)); // Minicrits
	}
	if(Buffmode == 0 || Buffmode == 2 || Buffmode == 4 || Buffmode == 6)
	{
		TF2_AddCondition(client, TFCond_DefenseBuffNoCritBlock, FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, BUFFS, 2, 5.0)); // Defense Buff
	}
	if(Buffmode == 0 || Buffmode == 3 || Buffmode == 5 || Buffmode == 6)
	{
		TF2_AddCondition(client, TFCond_RegenBuffed, FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, BUFFS, 2, 5.0));	// Speed boost and regen
	}
}


public bool:ROL_CanInvoke(client)
{
	return true;
}

public ROL_Invoke(client)
{
	new Boss=FF2_GetBossIndex(client);
	new Float:bossPosition[3], Float:targetPosition[3];
	Outlinedistance=FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, OUTLINE, 2, FF2_GetRageDist(Boss, this_plugin_name, OUTLINE));
	
	if(Outline_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_outline", sound, sizeof(sound), Boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	
	for(new i = 1; i <= MaxClients; i++ )
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!= FF2_GetBossTeam())
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPosition);
			if(GetVectorDistance(bossPosition, targetPosition)<=Outlinedistance)
			{
				SDKHook(i, SDKHook_PreThink, Outline_Prethink);
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
				EndOutline=GetEngineTime()+FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,OUTLINE,1,5.0); // Victim Move Speed Duration
			}
		}
	}
}

public Outline_Prethink(client)
{
	OutlineTick(client, GetEngineTime());
}

public OutlineTick(client, Float:gameTime)
{
	if(gameTime>=EndOutline)
	{
		for(new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!= FF2_GetBossTeam())
			{
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
			}
		}
		SDKUnhook(client, SDKHook_PreThink, Outline_Prethink);
	}
}


public bool:SPF_CanInvoke(client)
{
	if(!FireEnabled) return false;
	return true;
}

public SPF_Invoke(client)
{
	new Boss=FF2_GetBossIndex(client);
	new Float:bossPosition[3], Float:targetPosition[3];
	FireRange=FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, FIRE, 3, 555.0);
	
	if(Fire_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_fire", sound, sizeof(sound), Boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);	
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			if(!TF2_IsPlayerInCondition(target, TFCond_Ubercharged) && (GetVectorDistance(bossPosition, targetPosition)<=FireRange) && FireEnabled)
			{
				SDKHook(target, SDKHook_PreThink, Fire_Prethink);
				FireEnabled = false;
				EndFire=GetEngineTime()+FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,FIRE,1,5.0);
				CreateTimer(FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,FIRE,2,5.0), StopFire);
				TF2_IgnitePlayer(target, client);
			}
		}
	}
}

public Fire_Prethink(client)
{
	FireTick(client, GetEngineTime());
}

public FireTick(client, Float:gameTime)
{
	if(gameTime>=EndFire)
	{
		for(new i = 1; i <= MaxClients; i++ )
		{
			if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!= FF2_GetBossTeam() && TF2_IsPlayerInCondition(i, TFCond_OnFire))
			{
				TF2_RemoveCondition(i, TFCond_OnFire);
			}
		}
		SDKUnhook(client, SDKHook_PreThink, Fire_Prethink);
	}
}
public Action:StopFire(Handle:timer)
{
	FireEnabled = true;
	return Plugin_Continue;
}


public bool:SMO_CanInvoke(client)
{
	return true;
}

public SMO_Invoke(client)
{
	new Boss=FF2_GetBossIndex(client);
	
	if(Slay_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_slay", sound, sizeof(sound), Boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	CreateTimer(FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, SLAY, 1, 5.0), Timer_StopMinions);
}

public Action:Timer_StopMinions(Handle:timer)
{
	for(new target = 1; target <= MaxClients; target++)
	{
		if (IsValidClient(target) && GetClientTeam(target)==FF2_GetBossTeam() && FF2_GetBossIndex(target)==-1)
		{
			ForcePlayerSuicide(target);
		}
	}
	return Plugin_Continue;
}


public bool:SAS_CanInvoke(client)
{
	return true; // no special conditions will prevent this ability
}

public SAS_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	new Float:bossPosition[3], Float:targetPosition[3], Float:sentryPosition[3];
	new Float:Stunduration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, AMSSTUN, 1, 5.0);
	new Float:Stundistance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, AMSSTUN, 2, FF2_GetRageDist(boss, this_plugin_name, AMSSTUN));
	new Float:Sentryduration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, AMSSTUN, 3, 7.0);
	new Float:Sentrydistance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, AMSSTUN, 4, FF2_GetRageDist(boss, this_plugin_name, AMSSTUN));
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	
	new String:sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_ams_stun", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}

	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			if(!TF2_IsPlayerInCondition(target, TFCond_Ubercharged) && (GetVectorDistance(bossPosition, targetPosition)<=Stundistance))
			{
				TF2_StunPlayer(target, Stunduration, 0.0, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_NOSOUNDOREFFECT, client);
				CreateTimer(Stunduration, Timer_RemoveEntity, EntIndexToEntRef(AttachParticle(target, "yikes_fx", 75.0)), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	new sentry;
	while((sentry=FindEntityByClassname(sentry, "obj_sentrygun"))!=-1)
	{
		GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentryPosition);
		if(GetVectorDistance(bossPosition, sentryPosition)<=Sentrydistance)
		{
			SetEntProp(sentry, Prop_Send, "m_bDisabled", 1);
			CreateTimer(Sentryduration, Timer_RemoveEntity, EntIndexToEntRef(AttachParticle(sentry, "yikes_fx", 75.0)), TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(Sentryduration, Timer_EnableSentry, EntIndexToEntRef(sentry), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}


public bool REVI_CanInvoke(int client)
{
	if(!(GetEntityFlags(client) & FL_ONGROUND))
		return false;
		
	return DeadCompanions(client) ? true : false;
}

public void REVI_Invoke(int client)
{
	int boss=FF2_GetBossIndex(client);
	
	if(ReviveBosses_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_revive_bosses", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	new quantity=FF2_GetAbilityArgument(boss, this_plugin_name, REVIVE_BOSSES, 1);
	new Float:revivedhealth=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, REVIVE_BOSSES, 2);

	new revivedboss;
	for(new target=0; target<=quantity; target++)
	{
		revivedboss = GetRandomDeadBoss();
		new bossIndex=FF2_GetBossIndex(revivedboss);
		if(revivedboss!=-1 && bossIndex!=-1)
		{
			FF2_SetFF2flags(revivedboss,FF2_GetFF2flags(revivedboss)|FF2FLAG_ALLOWSPAWNINBOSSTEAM);
			ChangeClientTeam(revivedboss,FF2_GetBossTeam());
			TF2_RespawnPlayer(revivedboss);
			
			new health;
			new maxhealth = FF2_GetBossMaxHealth(bossIndex);

			health = RoundToCeil(maxhealth * revivedhealth);
				
			FF2_SetBossHealth(bossIndex, health);
		}
	}
}


public bool HEAL_CanInvoke(int client)
{
	return true;
}

public void HEAL_Invoke(int client)
{
	int boss=FF2_GetBossIndex(client);
	new Float:pos[3], Float:pos2[3], Float:dist;
	new Float:distance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HEAL_BOSSES, 1);
	new Float:healing=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, HEAL_BOSSES, 2);
	new bool:selfheal=bool:FF2_GetAbilityArgument(boss, this_plugin_name, HEAL_BOSSES, 3);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	
	if(HealBosses_TriggerAMS[client])
	{
		new String:sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_healing_bosses", sound, sizeof(sound), boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	if(selfheal)
	{
		new Selfhealth = FF2_GetBossHealth(boss);
		new Selfmaxhealth = FF2_GetBossMaxHealth(boss);
				
		Selfhealth = RoundToCeil(Selfhealth + (Selfmaxhealth * healing));
		if(Selfhealth > Selfmaxhealth)
		{
			Selfhealth = Selfmaxhealth;
		}
				
		FF2_SetBossHealth(boss, Selfhealth);
	}
	
	for(new companion=1; companion<=MaxClients; companion++)
	{
		if(IsValidClient(companion) && GetClientTeam(companion) == FF2_GetBossTeam())
		{
			int companionIndex=FF2_GetBossIndex(companion);
			GetEntPropVector(companion, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance(pos,pos2);
			if(dist<distance && companionIndex>0)
			{
				new health = FF2_GetBossHealth(companionIndex);
				new maxhealth = FF2_GetBossMaxHealth(companionIndex);
				
				health = RoundToCeil(health + (maxhealth * healing));
				if(health > maxhealth)
				{
					health = maxhealth;
				}
				
				FF2_SetBossHealth(companionIndex, health);
			}
		}
	}
}


public Action:FF2_OnLoseLife(index)
{		
	new userid = FF2_GetBossUserId(index);
	new client=GetClientOfUserId(userid);
	if(index==-1 || !IsValidEdict(client) || !FF2_HasAbility(index, this_plugin_name, TRANSFORMATION))
		return Plugin_Continue;
	
	FF2_GetAbilityArgumentString(index, this_plugin_name, TRANSFORMATION, 1, lifelose_model, sizeof(lifelose_model));
	lifelose_playerclass = FF2_GetAbilityArgument(index, this_plugin_name, TRANSFORMATION, 2, 8);
	FF2_GetAbilityArgumentString(index, this_plugin_name, TRANSFORMATION, 3, lifelose_weapon_classname, sizeof(lifelose_weapon_classname));
	lifelose_weapon_defindex = FF2_GetAbilityArgument(index, this_plugin_name, TRANSFORMATION, 4, 4);
	FF2_GetAbilityArgumentString(index, this_plugin_name, TRANSFORMATION, 5, lifelose_weapon_attributes, sizeof(lifelose_weapon_attributes));
		
	TF2_SetPlayerClass(client, TFClassType:lifelose_playerclass);
		
	TF2_RemoveAllWeapons(client);
	SpawnWeapon(client, lifelose_weapon_classname, lifelose_weapon_defindex, 101, 9, lifelose_weapon_attributes, true, false);
		
	PrecacheModel(lifelose_model);
	SetVariantString(lifelose_model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	
	if(FF2_HasAbility(index, this_plugin_name, LIFELOSTHEMECHANGE))
	{
		FF2_GetAbilityArgumentString(index, this_plugin_name, LIFELOSTHEMECHANGE, 1, LIFELOSETHEME, sizeof(LIFELOSETHEME));
		
		FF2_StopMusic(0);
	
		StopMusic_LifeLoseVersion++;
		
		if(LIFELOSETHEME[0] != '\0')
		{
			PrecacheSound(LIFELOSETHEME, true);
			EmitSoundToAll(LIFELOSETHEME);
		}
		else
		{
			if(FF2_RandomSound("sound_lifelose_theme", LIFELOSETHEME, sizeof(LIFELOSETHEME), index))
			{
				EmitSoundToAll(LIFELOSETHEME);
			}		
		}
	}
	
	return Plugin_Continue;
}

public Action:FF2_OnMusic(String:path[], &Float:time)
{
	if (StopMusic_RageVersion || StopMusic_LifeLoseVersion || StopMusic_FewPlayerVersion)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}


Charge_New_Salmon(const String:ability_name[],boss,client,slot,action)
{
	new weapon;
	char hudstatus[256], hudstatus2[256], hudstatus3[256], hudstatus4[256], summonertext[256], summonedtext[256], HP[768];
	new Float:charge=FF2_GetBossCharge(boss,slot);
	
	Sound=FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, 3);	//sound
	Minions=FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, 4);	// How many Minions?
	UberchargeDuration=FF2_GetAbilityArgumentFloat(boss,this_plugin_name,ability_name, 5); // Spawn Protection
	Notify=FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, 6);	// notification alert
	ModelMode=FF2_GetAbilityArgument(boss,this_plugin_name,ability_name, 7);	// Model mode (Human/Custom model or bot models)
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 8, SalmonModel, sizeof(SalmonModel)); // Human or custom model?
	Class=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 9); // class name, if changing
	Wearables=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 10); // wearable
	WeaponMode=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 11); // weapon mode
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 12, Classname, sizeof(Classname));
	WeaponIndex=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 13);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 14, Attributes, sizeof(Attributes));
	Accessoires=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 15);
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 16, HP, sizeof(HP));
	Ammo=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 17); // Ammo
	Clip=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 18); // Clip
	VO = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 19);	 // Voice lines
	PickupMode = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 20); // PickupMode?
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 21, Condition, sizeof(Condition)); // Conditions
	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 22, hudstatus, sizeof(hudstatus));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 23, hudstatus2, sizeof(hudstatus2));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 24, hudstatus3, sizeof(hudstatus3));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 25, hudstatus4, sizeof(hudstatus4));
	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 26, summonertext, sizeof(summonertext));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 27, summonedtext, sizeof(summonedtext));
	
	if(!hudstatus[0])
	{
		Format(hudstatus, sizeof(hudstatus), "%t", "summon_status");
	}
	if(!hudstatus2[0])
	{
		Format(hudstatus2, sizeof(hudstatus2), "%t", "summon_status_2");
	}
	if(!hudstatus3[0])
	{
		Format(hudstatus3, sizeof(hudstatus3), "%t", "super_duper_jump");
	}
	if(!hudstatus4[0])
	{
		Format(hudstatus4, sizeof(hudstatus4), "%t", "summon_ready");
	}

	switch (action)
	{
		case 1:
		{
			SetHudTextParams(-1.0, slot==1 ? 0.88 : 0.93, 0.15, 255, 255, 255, 255);
			ShowSyncHudText(client, jumpHUD, hudstatus2, -RoundFloat(charge));
		}	
		case 2:
		{
			SetHudTextParams(-1.0, slot==1 ? 0.88 : 0.93, 0.15, 255, bEnableSuperDuperJump[client] && slot == 1 ? 64 : 255, bEnableSuperDuperJump[client] && slot == 1 ? 64 : 255, 255);
			if (bEnableSuperDuperJump[client] && slot == 1)
			{
				ShowSyncHudText(client, jumpHUD, hudstatus3);
			}	
			else
			{	
				ShowSyncHudText(client, jumpHUD, hudstatus, RoundFloat(charge));
			}
		}
		case 3:
		{
			decl Float:pos[3];
			if (bEnableSuperDuperJump[client] && slot == 1)
			{
				float vel[3];
				float rot[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
				GetClientEyeAngles(client, rot);
				vel[2]=750.0+500.0*charge/70+2000;
				vel[0]+=Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*500;
				vel[1]+=Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*500;
				bEnableSuperDuperJump[client]=false;
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
			}
			else
			{
				if(charge<100)
				{
					CreateTimer(0.1, ResetCharge, boss*10000+slot);
					return;					
				}
				
				new ii;
				
				if(Sound!=0)
					EmitSoundToAll(ZEPH_SND);
					
				for (new i=0; i<Minions; i++)
				{
					ii = GetRandomDeadPlayer();
					if(ii != -1)
					{
						FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOWSPAWNINBOSSTEAM);
						if(PickupMode)
						{
							if(PickupMode==1 || PickupMode==3)
								FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOW_HEALTH_PICKUPS); // HP Pickup
							if(PickupMode==2 || PickupMode==3)
								FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOW_AMMO_PICKUPS); // Ammo Pickup
						}
						ChangeClientTeam(ii,FF2_GetBossTeam());
						TF2_RespawnPlayer(ii);
						SummonerIndex[ii]=boss;
					
						switch(WeaponMode)
						{
							case 2: // No weapons
								TF2_RemoveAllWeapons(ii);
							case 1: // User-Specified
							{
								TF2_RemoveAllWeapons(ii);
					
								if(Attributes[0]!='\0')
									Format(Attributes, sizeof(Attributes), TF2_GetPlayerClass(ii)==TFClass_Scout ? "68 ; -2 ; 259 ; 1.0 ; %s" : "68 ; -1 ; 259 ; 1.0 ; %s", Attributes);
								else
									Attributes="68 ; -1 ; 259 ; 1.0";
					
								weapon=SpawnWeapon(ii, Classname, WeaponIndex, 101, 0, Attributes);
								if(Ammo)
									SetAmmo(ii, weapon, Ammo);
								if(Clip)
									SetEntProp(weapon, Prop_Send, "m_iClip1", Clip);
								if(Accessoires!=0)
								{
									switch(TF2_GetPlayerClass(ii))
									{
										case TFClass_Engineer:
										{
											SpawnWeapon(ii, "tf_weapon_pda_engineer_build", 25, 101, 5, "292 ; 3 ; 293 ; 59 ; 391 ; 2 ; 495 ; 60"); // Build PDA
											SpawnWeapon(ii, "tf_weapon_pda_engineer_destroy", 26, 101, 5, "391 ; 2"); // Destroy PDA
											weapon = SpawnWeapon(ii, "tf_weapon_builder", 28, 101, 5, "391 ; 2"); // Builder
											SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
											SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
											SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
											SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
										}
										case TFClass_Spy:
										{
											if(Accessoires==4 || Accessoires==6 || Accessoires==8 || Accessoires==11) // Dead Ringer
												SpawnWeapon(ii, "tf_weapon_invis", 59, 1, 0, "33 ; 1 ; 34 ; 1.6 ; 35 ; 1.8 ; 292 ; 9 ; 391 ; 2");
											if(Accessoires==3 || Accessoires==5 || Accessoires==7 || Accessoires==10) // Invis Watch
												SpawnWeapon(ii, "tf_weapon_invis", 30, 1, 0, "391 ; 2");
											if(Accessoires==2|| Accessoires==5 || Accessoires == 6 || Accessoires>=9) // Disguise kit
												SpawnWeapon(ii, "tf_weapon_pda_spy", 27, 1, 0, "391 ; 2");
											if(Accessoires==1 || Accessoires==7 || Accessoires>=7) // Sapper
											{
												weapon = SpawnWeapon(ii, "tf_weapon_builder", 735, 101, 5, "391 ; 2");
												SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
												SetEntProp(weapon, Prop_Data, "m_iSubType", 3);
												SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 0);
												SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 1);
												SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 0, _, 2);
												SetEntProp(weapon, Prop_Send, "m_aBuildableObjectTypes", 1, _, 3);
											}
										}
									}
								}
							}
						}
			
						if(Condition[0]!='\0')
							SetCondition(ii, Condition);
						if(Wearables)
						{
							new owner, entity;
							while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
								if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
									TF2_RemoveWearable(owner, entity);
							while((entity=FindEntityByClassname(entity, "tf_wearable_demoshield"))!=-1)
								if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
									TF2_RemoveWearable(owner, entity);
							while((entity=FindEntityByClassname(entity, "tf_powerup_bottle"))!=-1)
								if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==FF2_GetBossTeam())
									TF2_RemoveWearable(owner, entity);
						}
			
						switch(ModelMode)
						{
							case 1:	// robots
							{
								char pclassname[10];
								TF2_GetNameOfClass(TF2_GetPlayerClass(ii), pclassname, sizeof(pclassname));
								Format(SalmonModel, PLATFORM_MAX_PATH, "models/bots/%s/bot_%s.mdl", pclassname, pclassname);
								ReplaceString(SalmonModel, PLATFORM_MAX_PATH, "demoman", "demo", false);
								SetPlayerModel(ii, SalmonModel);
								TF2_SetPlayerClass(ii, TFClassType:Class, _, false);
								VOMode[ii]=VoiceMode_Robot;
								if(UberchargeDuration)
								{
									TF2_AddCondition(ii, TFCond_UberchargedHidden, UberchargeDuration);
								}
							}
							case 2: // clone of boss
							{
								char taunt[PLATFORM_MAX_PATH];
								Handle curBossKV=FF2_GetSpecialKV(boss, false);
								TF2_SetPlayerClass(ii, TFClassType:KvGetNum(curBossKV, "class", 0), _, false);
								KvGetString(curBossKV, "model", SalmonModel, PLATFORM_MAX_PATH);	
								if(KvGetNum(curBossKV, "sound_block_vo", 0))
								{
									VOMode[ii]=((!FF2_RandomSound("catch_phrase", taunt, sizeof(taunt), boss)) ? VoiceMode_None : VoiceMode_BossCatchPhrase);
								}
								else
								{
									VOMode[ii]=((!FF2_RandomSound("catch_phrase", taunt, sizeof(taunt), boss)) ? VoiceMode_Normal : VoiceMode_BossCatchPhrase);
								}
								SetPlayerModel(ii, SalmonModel);
							}
							default:
							{
								if(UberchargeDuration)
									TF2_AddCondition(ii, TFCond_Ubercharged, UberchargeDuration);
					
								TF2_SetPlayerClass(ii, TFClassType:Class, _, false);
					
								SetPlayerModel(ii, SalmonModel);
					
								if(VO)
								{
									VOMode[ii]=VoiceMode:VO;
								}
							}
						
						}
						if(Notify!=0)
						{
							PrintHintText(client, "%s", summonertext);
							PrintHintText(ii, "%s", summonedtext);
						}
						
						new playing=0;
						for(new player=1;player<=MaxClients;player++)
						{
							if(!IsValidClient(player))
								continue;
							if(GetClientTeam(player)!= FF2_GetBossTeam())
							{
								playing++;
							}
						}
			
						new health=ParseFormula(boss, HP, GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, ii), playing);
						if(health)
						{
							SetEntityHealth(ii, health);
						}
					}
				}
			}
			decl String:s[PLATFORM_MAX_PATH];
			if (FF2_RandomSound("sound_ability",s,PLATFORM_MAX_PATH,boss,slot))
			{
				EmitSoundToAll(s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
				EmitSoundToAll(s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
					
				for (new i=1; i<=MaxClients; i++)
				{
					if (IsClientInGame(i) && i!=client)
					{
						EmitSoundToClient(i,s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
						EmitSoundToClient(i,s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
					}
				}
			}
		}
		default:
		{
			if(charge<=0.2 && !bEnableSuperDuperJump[client])
			{
				SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
				ShowSyncHudText(client, jumpHUD, hudstatus4);
			}
		}
	}
}

stock void SetPlayerModel(client, char[] model)
{	
	if(!IsModelPrecached(model))
	{
		PrecacheModel(model);
	}
	
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}

public Action:ResetCharge(Handle:timer, any:index)
{
	new slot=index%10000;
	index/=1000;
	FF2_SetBossCharge(index,slot,0.0);
}

public Action:FF2_OnTriggerHurt(index,triggerhurt,&Float:damage)
{
	bEnableSuperDuperJump[index]=true;
	if (FF2_GetBossCharge(index,1)<0)
		FF2_SetBossCharge(index,1,0.0);
	return Plugin_Continue;
}


/*
	Health Parser
 */
stock Operate(Handle:sumArray, &bracket, Float:value, Handle:_operator)
{
	new Float:sum=GetArrayCell(sumArray, bracket);
	switch(GetArrayCell(_operator, bracket))
	{
		case Operator_Add:
		{
			SetArrayCell(sumArray, bracket, sum+value);
		}
		case Operator_Subtract:
		{
			SetArrayCell(sumArray, bracket, sum-value);
		}
		case Operator_Multiply:
		{
			SetArrayCell(sumArray, bracket, sum*value);
		}
		case Operator_Divide:
		{
			if(!value)
			{
				LogError("[SHADoW93 Minions] Detected a divide by 0!");
				bracket=0;
				return;
			}
			SetArrayCell(sumArray, bracket, sum/value);
		}
		case Operator_Exponent:
		{
			SetArrayCell(sumArray, bracket, Pow(sum, value));
		}
		default:
		{
			SetArrayCell(sumArray, bracket, value);  //This means we're dealing with a constant
		}
	}
	SetArrayCell(_operator, bracket, Operator_None);
}

stock OperateString(Handle:sumArray, &bracket, String:value[], size, Handle:_operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

public ParseFormula(boss, const String:key[], defaultValue, playing)
{
	decl String:formula[1024], String:bossName[64];
	FF2_GetBossSpecial(boss, bossName, sizeof(bossName));
	strcopy(formula, sizeof(formula), key);
	new size=1;
	new matchingBrackets;
	for(new i; i<=strlen(formula); i++)  //Resize the arrays once so we don't have to worry about it later on
	{
		if(formula[i]=='(')
		{
			if(!matchingBrackets)
			{
				size++;
			}
			else
			{
				matchingBrackets--;
			}
		}
		else if(formula[i]==')')
		{
			matchingBrackets++;
		}
	}

	new Handle:sumArray=CreateArray(_, size), Handle:_operator=CreateArray(_, size);
	new bracket;  //Each bracket denotes a separate sum (within parentheses).  At the end, they're all added together to achieve the actual sum
	SetArrayCell(sumArray, 0, 0.0);  //TODO:  See if these can be placed naturally in the loop
	SetArrayCell(_operator, bracket, Operator_None);

	new String:character[2], String:value[16];  //We don't decl value because we directly append characters to it and there's no point in decl'ing character
	for(new i; i<=strlen(formula); i++)
	{
		character[0]=formula[i];  //Find out what the next char in the formula is
		switch(character[0])
		{
			case ' ', '\t':  //Ignore whitespace
			{
				continue;
			}
			case '(':
			{
				bracket++;  //We've just entered a new parentheses so increment the bracket value
				SetArrayCell(sumArray, bracket, 0.0);
				SetArrayCell(_operator, bracket, Operator_None);
			}
			case ')':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				if(GetArrayCell(_operator, bracket)!=Operator_None)  //Something like (5*)
				{
					LogError("[M7 Minions] %s's %s formula has an invalid operator at character %i", bossName, key, i+1);
					CloseHandle(sumArray);
					CloseHandle(_operator);
					return defaultValue;
				}

				if(--bracket<0)  //Something like (5))
				{
					LogError("[M7 Minions] %s's %s formula has an unbalanced parentheses at character %i", bossName, key, i+1);
					CloseHandle(sumArray);
					CloseHandle(_operator);
					return defaultValue;
				}

				Operate(sumArray, bracket, GetArrayCell(sumArray, bracket+1), _operator);
			}
			case '\0':  //End of formula
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
			}
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
			{
				StrCat(value, sizeof(value), character);  //Constant?  Just add it to the current value
			}
			case 'n', 'x':  //n and x denote player variables
			{
				Operate(sumArray, bracket, float(playing), _operator);
			}
			case '+', '-', '*', '/', '^':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				switch(character[0])
				{
					case '+':
					{
						SetArrayCell(_operator, bracket, Operator_Add);
					}
					case '-':
					{
						SetArrayCell(_operator, bracket, Operator_Subtract);
					}
					case '*':
					{
						SetArrayCell(_operator, bracket, Operator_Multiply);
					}
					case '/':
					{
						SetArrayCell(_operator, bracket, Operator_Divide);
					}
					case '^':
					{
						SetArrayCell(_operator, bracket, Operator_Exponent);
					}
				}
			}
		}
	}

	new result=RoundFloat(GetArrayCell(sumArray, 0));
	CloseHandle(sumArray);
	CloseHandle(_operator);
	if(result<=0)
	{
		LogError("[M7 Minions] %s has an invalid %s formula for minions, using default health!", bossName, key);
		return defaultValue;
	}
	return result;
}

#if SOURCEMOD_V_MAJOR==1 && SOURCEMOD_V_MINOR<=7
public Action:SoundHook(clients[64], &numClients, String:vl[PLATFORM_MAX_PATH], &client, &channel, &Float:volume, &level, &pitch, &flags)
#else
public Action:SoundHook(clients[64], &numClients, String:vl[PLATFORM_MAX_PATH], &client, &channel, &Float:volume, &level, &pitch, &flags, String:soundEntry[PLATFORM_MAX_PATH], &seed)
#endif
{
	if(!IsValidClient(client) || channel<1)
	{
		return Plugin_Continue;
	}

	switch(VOMode[client])
	{
		case VoiceMode_None: // NO Voicelines!
		{
			if(channel==SNDCHAN_VOICE)
			{
				return Plugin_Stop;
			}
		}
		case VoiceMode_Robot:	// Robot VO
		{
			if(!TF2_IsPlayerInCondition(client, TFCond_Disguised)) // Robot voice lines & footsteps
			{
				if (StrContains(vl, "player/footsteps/", false) != -1 && TF2_GetPlayerClass(client) != TFClass_Medic)
				{
					new rand = GetRandomInt(1,18);
					Format(vl, sizeof(vl), "mvm/player/footsteps/robostep_%s%i.wav", (rand < 10) ? "0" : "", rand);
					pitch = GetRandomInt(95, 100);
					EmitSoundToAll(vl, client, _, _, _, 0.25, pitch);
				}
				
				if(channel==SNDCHAN_VOICE)
				{
					if (volume == 0.99997) return Plugin_Continue;
					ReplaceString(vl, sizeof(vl), "vo/", "vo/mvm/norm/", false);
					ReplaceString(vl, sizeof(vl), ".wav", ".mp3", false);
					new String:classname[10], String:classname_mvm[15];
					TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
					Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
					ReplaceString(vl, sizeof(vl), classname, classname_mvm, false);
					new String:nSnd[PLATFORM_MAX_PATH];
					Format(nSnd, sizeof(nSnd), "sound/%s", vl);
					PrecacheSound(vl);
				}
				return Plugin_Changed;
			}
		}
		case VoiceMode_BossCatchPhrase: // Minions use boss's catchphrases
		{
			char taunt[PLATFORM_MAX_PATH];
			if(channel==SNDCHAN_VOICE && FF2_RandomSound("catch_phrase", taunt, sizeof(taunt), SummonerIndex[client]))
			{
				strcopy(vl, PLATFORM_MAX_PATH, taunt);
				return Plugin_Changed;
			}
		}
		case VoiceMode_CatchPhrase: // Minions have their own catchphrase lines
		{
			char taunt[PLATFORM_MAX_PATH];
			if(channel==SNDCHAN_VOICE && FF2_RandomSound("sound_minion_catchphrase", taunt, sizeof(taunt), SummonerIndex[client]))
			{
				strcopy(vl, PLATFORM_MAX_PATH, taunt);
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

#if !defined _FF2_Extras_included
stock int SpawnWeapon(int client, char[] name, int index, int level, int quality, char[] attribute, int visible = 1, bool preserve = false)
{
	if(StrEqual(name,"saxxy", false)) // if "saxxy" is specified as the name, replace with appropiate name
	{ 
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: ReplaceString(name, 64, "saxxy", "tf_weapon_bat", false);
			case TFClass_Soldier: ReplaceString(name, 64, "saxxy", "tf_weapon_shovel", false);
			case TFClass_Pyro: ReplaceString(name, 64, "saxxy", "tf_weapon_fireaxe", false);
			case TFClass_DemoMan: ReplaceString(name, 64, "saxxy", "tf_weapon_bottle", false);
			case TFClass_Heavy: ReplaceString(name, 64, "saxxy", "tf_weapon_fists", false);
			case TFClass_Engineer: ReplaceString(name, 64, "saxxy", "tf_weapon_wrench", false);
			case TFClass_Medic: ReplaceString(name, 64, "saxxy", "tf_weapon_bonesaw", false);
			case TFClass_Sniper: ReplaceString(name, 64, "saxxy", "tf_weapon_club", false);
			case TFClass_Spy: ReplaceString(name, 64, "saxxy", "tf_weapon_knife", false);
		}
	}
	
	if(StrEqual(name, "tf_weapon_shotgun", false)) // If using tf_weapon_shotgun for Soldier/Pyro/Heavy/Engineer
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Soldier:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_soldier", false);
			case TFClass_Pyro:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_pyro", false);
			case TFClass_Heavy:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_hwg", false);
			case TFClass_Engineer:	ReplaceString(name, 64, "tf_weapon_shotgun", "tf_weapon_shotgun_primary", false);
		}
	}

	Handle weapon = TF2Items_CreateItem((preserve ? PRESERVE_ATTRIBUTES : OVERRIDE_ALL) | FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		int i2 = 0;
		for(int i = 0; i < count; i += 2)
		{
			int attrib = StringToInt(attributes[i]);
			if (attrib == 0)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				return -1;
			}
			TF2Items_SetAttribute(weapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(weapon, 0);
	}

	if (weapon == INVALID_HANDLE)
	{
		PrintToServer("[SpawnWeapon] Error: Invalid weapon spawned. client=%d name=%s idx=%d attr=%s", client, name, index, attribute);
		return -1;
	}

	int entity = TF2Items_GiveNamedItem(client, weapon);
	delete weapon;
	
	if(!visible)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	
	if (StrContains(name, "tf_wearable")==-1)
	{
		EquipPlayerWeapon(client, entity);
	}
	else
	{
		Wearable_EquipWearable(client, entity);
	}
	
	return entity;
}

Handle S93SF_equipWearable = INVALID_HANDLE;
stock void Wearable_EquipWearable(client, wearable)
{
	if(S93SF_equipWearable==INVALID_HANDLE)
	{
		Handle config=LoadGameConfigFile("equipwearable");
		if(config==INVALID_HANDLE)
		{
			LogError("[FF2] EquipWearable gamedata could not be found; make sure /gamedata/equipwearable.txt exists.");
			return;
		}

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "EquipWearable");
		CloseHandle(config);
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		if((S93SF_equipWearable=EndPrepSDKCall())==INVALID_HANDLE)
		{
			LogError("[FF2] Couldn't load SDK function (CTFPlayer::EquipWearable). SDK call failed.");
			return;
		}
	}
	SDKCall(S93SF_equipWearable, client, wearable);
}
#endif

stock SetAmmo(client, slot, ammo)
{
	new weapon2 = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon2))
	{
		new iOffset = GetEntProp(weapon2, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}

stock SetCondition(client, String:cond[]) // Sets multi TFConds to a client
{
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (new i = 0; i < count; i+=2)
		{
			TF2_AddCondition(client, TFCond:StringToInt(conds[i]), StringToFloat(conds[i+1]));
		}
	}
}

stock GetRandomDeadPlayer()
{
	new clients[MaxClients+1], clientCount;
	for(new i=1;i<=MaxClients;i++)
	{
		if (IsValidEdict(i) && IsClientConnected(i) && IsClientInGame(i) && !IsPlayerAlive(i) && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

stock bool:IsValidMinion(client)
{
	if (GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	if (FF2_GetBossIndex(client) != -1) return false;
	if (SummonerIndex[client] == -1) return false;
	return true;
}

stock TF2_GetNameOfClass(TFClassType:class, String:name[], maxlen) // Retrieves player class name
{
	switch (class)
	{
		case TFClass_Scout: Format(name, maxlen, "scout");
		case TFClass_Soldier: Format(name, maxlen, "soldier");
		case TFClass_Pyro: Format(name, maxlen, "pyro");
		case TFClass_DemoMan: Format(name, maxlen, "demoman");
		case TFClass_Heavy: Format(name, maxlen, "heavy");
		case TFClass_Engineer: Format(name, maxlen, "engineer");
		case TFClass_Medic: Format(name, maxlen, "medic");
		case TFClass_Sniper: Format(name, maxlen, "sniper");
		case TFClass_Spy: Format(name, maxlen, "spy");
	}
}

stock AttachParticle(entity, String:particleType[], Float:offset=0.0, bool:attach=true)
{
	new particle=CreateEntityByName("info_particle_system");

	decl String:targetName[128];
	new Float:position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2]+=offset;
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
public Action:Timer_RemoveEntity(Handle:timer, any:entid)
{
	new entity=EntRefToEntIndex(entid);
	if(IsValidEntity(entity) && entity>MaxClients)
	{
		AcceptEntityInput(entity, "Kill");
	}
}
public Action:Timer_EnableSentry(Handle:timer, any:sentryid)
{
	new sentry=EntRefToEntIndex(sentryid);
	if(FF2_GetRoundState()==1 && sentry>MaxClients)
	{
		SetEntProp(sentry, Prop_Send, "m_bDisabled", 0);
	}
	return Plugin_Continue;
}

// need to briefly stun the target if they have continuous or other special weapons out
// these weapons can do so much as crash the user's client if they're quick switched
// the stun-unstun will prevent this from happening, but it may or may not stop the target's motion if on ground
stock PrepareForWeaponSwitch(clientIdx, bool:isBoss)
{
	new primary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
	if (!IsValidEntity(primary) || primary != GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon"))
		return;
	
	new bool:shouldStun = false;
	static String:restoreClassname[MAX_ENTITY_CLASSNAME_LENGTH];
	new itemDefinitionIndex = -1;
	if (EntityStartsWith(primary, "tf_weapon_minigun") || EntityStartsWith(primary, "tf_weapon_compound_bow"))
	{
		if (!isBoss)
		{
			GetEntityClassname(primary, restoreClassname, MAX_ENTITY_CLASSNAME_LENGTH);
			itemDefinitionIndex = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
			TF2_RemoveWeaponSlot(clientIdx, TFWeaponSlot_Primary);
		}
		shouldStun = true;
	}
	else if (EntityStartsWith(primary, "tf_weapon_sniperrifle") || EntityStartsWith(primary, "tf_weapon_flamethrower"))
		shouldStun = true;

	if (shouldStun)
	{
		TF2_StunPlayer(clientIdx, 0.1, 0.0, TF_STUNFLAG_BONKSTUCK | TF_STUNFLAG_NOSOUNDOREFFECT);
		TF2_RemoveCondition(clientIdx, TFCond_Dazed);
	}
	
	if (itemDefinitionIndex != -1)
	{
		if (!strcmp(restoreClassname, "tf_weapon_compound_bow"))
		{
			SpawnWeapon(clientIdx, restoreClassname, itemDefinitionIndex, 5, 10, "2 ; 1.5", 1, true);
		}
		else
		{
			switch (itemDefinitionIndex)
			{
				default:
					SpawnWeapon(clientIdx, restoreClassname, itemDefinitionIndex, 5, 10, "", 1, true);
			}
		}
	}
}

stock bool:EntityStartsWith(entity, const String:desiredPrefix[])
{
	static String:classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return StrContains(classname, desiredPrefix) == 0;
}

stock min(n1, n2)
{
	return n1 < n2 ? n1 : n2;
}

stock Float:fmin(Float:n1, Float:n2)
{
	return n1 < n2 ? n1 : n2;
}

stock max(n1, n2)
{
	return n1 > n2 ? n1 : n2;
}

stock Float:fmax(Float:n1, Float:n2)
{
	return n1 > n2 ? n1 : n2;
}

stock bool DeadCompanions(int clientIdx)
{
	int dead;
	for(int playing=1;playing<=MaxClients;playing++)
	{
		if(!IsValidClient(playing))
			continue;
		if(FF2_GetBossIndex(playing)>=0 && !IsPlayerAlive(playing) && playing!=clientIdx)
		{
			dead++;
		}
	}
	return !dead ? false : true;
}
stock int GetRandomDeadBoss()
{
	int[] clients = new int[MaxClients+1];
	int clientCount;
	for(int i=1;i<=MaxClients;i++)
	{
		if(IsValidEdict(i) && IsValidClient(i) && !IsPlayerAlive(i) && FF2_GetBossIndex(i)>=0 && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}
