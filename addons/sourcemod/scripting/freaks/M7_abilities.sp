#include <sdkhooks>
#include <tf2_stocks>
#include <ff2_ams2>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define MAJOR_REVISION "2"
#define MINOR_REVISION "0"
#define PATCH_REVISION "0"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

public Plugin myinfo = {
	name = "Freak Fortress 2: int Abilities",
	author = "M7",
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

//Charge_New_Salmon
#define SALMON_NEW "charge_new_salmon"
#define ZEPH_SND "ambient/siren.wav"
Handle jumpHUD;
int bEnableSuperDuperJump[MAXPLAYERS+1];
GlobalForward OnHaleJump;
int SummonerIndex[MAXPLAYERS+1];
char SalmonModel[PLATFORM_MAX_PATH], Classname[64], Attributes[248], Condition[248];
int Sound, Minions, Notify, ModelMode, Class, Wearables, WeaponMode, WeaponIndex, Accessoires, HP, Ammo, Clip, VO, PickupMode;
float UberchargeDuration;
VoiceMode VOMode[MAXPLAYERS+1];

//Rage_Outline
#define OUTLINE "rage_outline"
#define OUTLINEALIAS "ROL"
bool Outline_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Rage_Outline)
float EndOutline;
float Outlinedistance;

//rage_buffs
#define BUFFS "rage_buffs"
#define BUFFSALIAS "RBF"
bool Buffs_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Rage_Buffs)
int Buffmode;

//Slay_Minions
#define SLAY "slay_minions"
#define SLAYALIAS "SMO"
bool Slay_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Rage_Buffs)

//special_fire
#define FIRE "special_fire"
#define FIREALIAS "SPF"
bool Fire_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS (for Rage_Buffs)
bool FireEnabled = true;
float EndFire;
float FireEnabledAgain;
float FireRange;

//special_multimelee
#define MULTIWEAPONS "special_multimelee"
#define MWS_MAX_WEAPONS 10
int MWS_WeaponCount[MAXPLAYERS+1]; // arg2
int MWS_Slot[MAXPLAYERS+1][MWS_MAX_WEAPONS]; // argX6 (16, 26, 36...106)


#define SPECIALOUTLINE "special_outline"
#define AMSSTUN "special_ams_stun"
#define AMSSTUNALIAS "SAS"
#define MADMILKSTUN "special_stun"

public void OnMapStart()
{
	PrecacheSound(ZEPH_SND,true);
}

public void OnPluginStart2()
{
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", event_player_death);
	AddNormalSoundHook(SoundHook);
	jumpHUD = CreateHudSynchronizer();
	LoadTranslations("ff2_newsalmon.charge");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	OnHaleJump = new GlobalForward("VSH_OnDoJump", ET_Hook, Param_CellByRef);
}


public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
		
	PrepareAbilities();
}

public void PrepareAbilities()
{
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			//For Charge_New_Salmon
			bEnableSuperDuperJump[client]=false;
			SummonerIndex[client]=-1;
			
			//for Rage_Outline
			EndOutline = INACTIVE;
			
			//for Special_Fire
			EndFire = INACTIVE;
			FireEnabledAgain = INACTIVE;
			
			VOMode[client]=VoiceMode_Normal;
			
			int boss=FF2_GetBossIndex(client);
			if(boss>=0)
			{
				
				if(FF2_HasAbility(boss, this_plugin_name, SPECIALOUTLINE))
				{
					for(int player=1; player<=MaxClients; player++)
					{
						if(IsClientInGame(player) && IsPlayerAlive(player) && GetClientTeam(player)!= FF2_GetBossTeam())
						{
							SetEntProp(player, Prop_Send, "m_bGlowEnabled", 1);
						}
					}
				} 
				
			}
		}
	}
}

public void FF2AMS_PreRoundStart(int client)
{
	int boss = FF2_GetBossIndex(client);
	if(FF2_HasAbility(boss, this_plugin_name, OUTLINE))
	{
		Outline_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, OUTLINE, OUTLINEALIAS);
	}
	if(FF2_HasAbility(boss, this_plugin_name, BUFFS))
	{
		Buffs_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, BUFFS, BUFFSALIAS);
	}
	if(FF2_HasAbility(boss, this_plugin_name, SLAY))
	{
		Slay_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, SLAY, SLAYALIAS);
	}
	if(FF2_HasAbility(boss, this_plugin_name, FIRE))
	{
		Fire_TriggerAMS[client] = FF2AMS_PushToAMS(client, this_plugin_name, FIRE, FIREALIAS);
	}
	if(FF2_HasAbility(boss, this_plugin_name, AMSSTUN))
	{
		FF2AMS_PushToAMS(client, this_plugin_name, AMSSTUN, AMSSTUNALIAS);
	}
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	for(int client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			//for Rage_Outline
			EndOutline = INACTIVE;
			Outline_TriggerAMS[client] = false;
			SDKUnhook(client, SDKHook_PreThink, Outline_Prethink);
			
			//for Rage_Buffs
			Buffs_TriggerAMS[client] = false;
			
			//for Slay_Minions
			Slay_TriggerAMS[client] = false;
			
			//for Special_Fire
			EndFire = INACTIVE;
			FireEnabledAgain = INACTIVE;
			Fire_TriggerAMS[client] = false;
			SDKUnhook(client, SDKHook_PreThink, Fire_Prethink);
		}
	}
}

public Action event_player_death(Event event, const char[] name, bool dontBroadcast)
{
	if(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return Plugin_Continue;
	}
	
	int attacker=GetClientOfUserId(event.GetInt("attacker"));
	int client=GetClientOfUserId(event.GetInt("userid"));
	
	int boss=FF2_GetBossIndex(attacker); // Boss is an attacker
	if(boss!=-1)
	{
		if(FF2_HasAbility(boss, this_plugin_name, MULTIWEAPONS))
		{
			static char weaponName[MAX_WEAPON_NAME_LENGTH];
			static char weaponArgs[MAX_WEAPON_ARG_LENGTH];
			
			int rand = GetRandomInt(0, MWS_WeaponCount[attacker] - 1);
			int argOffset = (rand + 1) * 10;
			
			MWS_WeaponCount[attacker] = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, 1);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, MULTIWEAPONS, argOffset + 1, weaponName, MAX_WEAPON_NAME_LENGTH);
			int weaponIdx = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 2);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, MULTIWEAPONS, argOffset + 3, weaponArgs, MAX_WEAPON_ARG_LENGTH);
			int weaponVisibility = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 4);
			int alpha = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 5);
			int clip = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 7);
			int ammo = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, argOffset + 8);
			
			MWS_WeaponCount[attacker] = min(MWS_WeaponCount[attacker], MWS_MAX_WEAPONS);
			for (int i = 0; i < MWS_WeaponCount[attacker]; i++)
			{
				int offset = (10 * (i + 1));
				// a couple need to be stored as they're needed often
				MWS_Slot[attacker][i] = FF2_GetAbilityArgument(boss, this_plugin_name, MULTIWEAPONS, 6 + offset);
			}
	
			PrepareForWeaponSwitch(attacker, true);
			TF2_RemoveWeaponSlot(attacker, MWS_Slot[attacker][rand]);
			int weapon = SpawnWeapon(attacker, weaponName, weaponIdx, 101, 5, weaponArgs, weaponVisibility);
	
			// alpha transparency, best if the viewmodel doesn't hold it well
			if (alpha != 255)
			{
				SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
				SetEntityRenderColor(weapon, 255, 255, 255, alpha);
			}
		
			// set clip and ammo last
			int offset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1);
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
	}
	
	boss=FF2_GetBossIndex(client);	// Boss is the victim
	if(boss!=-1 && FF2_HasAbility(boss, this_plugin_name, SALMON_NEW) && !(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		for(int clone=1; clone<=MaxClients; clone++)
		{
			if(SummonerIndex[clone]==boss && IsValidClient(clone) && IsValidMinion(clone) && IsPlayerAlive(clone))
			{
				SummonerIndex[clone]=-1;
				ChangeClientTeam(clone, FF2_GetBossTeam()==view_as<int>(TFTeam_Blue) ? (view_as<int>(TFTeam_Red)) : (view_as<int>(TFTeam_Blue)));
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
public Action OnTakeDamage(int client, int& attacker, int& inflictor, 
							float& damage, int& damagetype, int& weapon,
							float damageForce[3], float damagePosition[3], int damagecustom)
{	
	if (attacker<1 || attacker>MaxClients || !IsValidClient(attacker))
		return Plugin_Continue;	
	int index = FF2_GetBossIndex(attacker);
	if (index!=-1 && client!=attacker && FF2_HasAbility(index, this_plugin_name, MADMILKSTUN) && GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon")!=GetPlayerWeaponSlot(attacker, TFWeaponSlot_Melee))
	{
		float duration=FF2_GetAbilityArgumentFloat(index, this_plugin_name, MADMILKSTUN, 1, 3.0);
		if (duration>0.25)
			TF2_StunPlayer(client, duration, 0.0, TF_STUNFLAGS_NORMALBONK, attacker);	
	}
	return Plugin_Continue;
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int action)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	int client=GetClientOfUserId(FF2_GetBossUserId(boss));
	int slot=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 0);
	if(!strcmp(ability_name,BUFFS))	// Defenses
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			Buffs_TriggerAMS[client]=false;
		}
		
		if(!Buffs_TriggerAMS[client])
			RBF_Invoke(client, -1);
	}
	else if (!strcmp(ability_name,OUTLINE))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			Outline_TriggerAMS[client]=false;
		}
		
		if(!Outline_TriggerAMS[client])
			ROL_Invoke(client, -1);
	}
	else if (!strcmp(ability_name,FIRE))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			Fire_TriggerAMS[client]=false;
		}
		
		if(!Fire_TriggerAMS[client])
			SPF_Invoke(client, -1);
	}
	else if (!strcmp(ability_name,SLAY))
	{
		if(!LibraryExists("FF2AMS")) // Fail state?
		{
			Slay_TriggerAMS[client]=false;
		}
		
		if(!Slay_TriggerAMS[client])
			SMO_Invoke(client, -1);
	}
	
	else if (!strcmp(ability_name,SALMON_NEW))
		Charge_New_Salmon(ability_name,boss,client,slot,action);
	
	return Plugin_Continue;
}



public AMSResult RBF_CanInvoke(int client, int index)
{
	if(TF2_IsPlayerInCondition(client, TFCond_Buffed)) return AMS_Deny;
	if(TF2_IsPlayerInCondition(client, TFCond_DefenseBuffed)) return AMS_Deny;
	if(TF2_IsPlayerInCondition(client, TFCond_RegenBuffed)) return AMS_Deny;
	return AMS_Accept;
}

public void RBF_Invoke(int client, int index)
{
	int Boss=FF2_GetBossIndex(client);
	Buffmode = FF2_GetAbilityArgument(Boss, this_plugin_name, BUFFS, 1); // Buff type
	
	if(Buffs_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
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
		TF2_AddCondition(client, TFCond_Buffed, FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,BUFFS,2,5.0)); // Minicrits
	}
	else if(Buffmode == 0 || Buffmode == 2 || Buffmode == 4 || Buffmode == 6)
	{
		TF2_AddCondition(client, TFCond_DefenseBuffed, FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,BUFFS,2,5.0)); //Defense Buff
	}
	else if(Buffmode == 0 || Buffmode == 3 || Buffmode == 5 || Buffmode == 6)
	{
		TF2_AddCondition(client, TFCond_RegenBuffed, FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,BUFFS,2,5.0)); //Speed boost and regen
	}
}


public AMSResult ROL_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void ROL_Invoke(int client, int index)
{
	int Boss=FF2_GetBossIndex(client);
	float bossPosition[3], targetPosition[3];
	Outlinedistance=FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, OUTLINE, 2, FF2_GetRageDist(Boss, this_plugin_name, OUTLINE));
	
	if(Outline_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_outline", sound, sizeof(sound), Boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	
	for(int i = 1; i <= MaxClients; i++ )
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!= FF2_GetBossTeam())
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", targetPosition);
			if(GetVectorDistance(bossPosition, targetPosition)<=Outlinedistance)
			{
				SDKHook(i, SDKHook_PreThink, Outline_Prethink);
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1);
				if(EndOutline!=INACTIVE)
				{
					EndOutline+=FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,OUTLINE,1,5.0); // Add time if rage is active?
				}
				else
				{
					EndOutline=GetEngineTime()+FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,OUTLINE,1,5.0); // Victim Move Speed Duration
				}
			}
		}
	}
}

public void Outline_Prethink(int client)
{
	OutlineTick(client, GetEngineTime());
}

public void OutlineTick(int client, float gameTime)
{
	if(gameTime>=EndOutline)
	{
		for(int i = 1; i <= MaxClients; i++ )
		{
			if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!= FF2_GetBossTeam())
			{
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0);
			}
		}
		SDKUnhook(client, SDKHook_PreThink, Outline_Prethink);
	}
}


public AMSResult SPF_CanInvoke(int client, int index)
{
	if(!FireEnabled) return AMS_Deny;
	return AMS_Accept;
}

public void SPF_Invoke(int client, int index)
{
	int Boss=FF2_GetBossIndex(client);
	float bossPosition[3], targetPosition[3];
	FireRange=FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, FIRE, 3, 5.0);
	
	if(Fire_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_fire", sound, sizeof(sound), Boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);	
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			if(!TF2_IsPlayerInCondition(target, TFCond_Ubercharged) && (GetVectorDistance(bossPosition, targetPosition)<=FireRange) && FireEnabled)
			{
				SDKHook(target, SDKHook_PreThink, Fire_Prethink);
				FireEnabled = false;
				EndFire=GetEngineTime()+FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,FIRE,1,5.0);
				TF2_IgnitePlayer(target, client);
			}
		}
	}
	FireEnabledAgain=GetEngineTime()+FF2_GetAbilityArgumentFloat(Boss,this_plugin_name,FIRE,2,5.0);
}

public void Fire_Prethink(int client)
{
	FireTick(client, GetEngineTime());
}

public void FireTick(int client, float gameTime)
{
	if(gameTime>=EndFire)
	{
		for(int i = 1; i <= MaxClients; i++ )
		{
			if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!= FF2_GetBossTeam() && TF2_IsPlayerInCondition(i, TFCond_OnFire))
			{
				TF2_RemoveCondition(i, TFCond_OnFire);
			}
		}
		SDKUnhook(client, SDKHook_PreThink, Fire_Prethink);
	}
	if(gameTime>=FireEnabledAgain)
	{
		FireEnabled = true;
	}
}



public AMSResult SMO_CanInvoke(int client, int index)
{
	return AMS_Accept;
}

public void SMO_Invoke(int client, int index)
{
	int Boss=FF2_GetBossIndex(client);
	
	if(Slay_TriggerAMS[client])
	{
		char sound[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_ams_slay", sound, sizeof(sound), Boss))
		{
			EmitSoundToAll(sound, client);
			EmitSoundToAll(sound, client);
		}
	}
	
	CreateTimer(FF2_GetAbilityArgumentFloat(Boss, this_plugin_name, SLAY, 1, 5.0), Timer_StopMinions);
}

public Action Timer_StopMinions(Handle timer)
{
	for(int target = 1; target <= MaxClients; target++)
	{
		if (IsValidClient(target) && IsValidMinion(target))
		{
			ForcePlayerSuicide(target);
		}
	}
	return Plugin_Continue;
}


public AMSResult SAS_CanInvoke(int client, int index)
{
	return AMS_Accept; // no special conditions will prevent this ability
}

public void SAS_Invoke(int client, int index)
{
	int boss=FF2_GetBossIndex(client);
	float bossPosition[3], targetPosition[3], sentryPosition[3];
	float Stunduration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, AMSSTUN, 1, 5.0);
	float Stundistance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, AMSSTUN, 2, FF2_GetRageDist(boss, this_plugin_name, AMSSTUN));
	float Sentryduration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, AMSSTUN, 3, 7.0);
	float Sentrydistance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, AMSSTUN, 4, FF2_GetRageDist(boss, this_plugin_name, AMSSTUN));
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	
	char sound[PLATFORM_MAX_PATH];
	if(FF2_RandomSound("sound_ams_stun", sound, sizeof(sound), boss))
	{
		EmitSoundToAll(sound, client);
		EmitSoundToAll(sound, client);
	}

	for(int target=1; target<=MaxClients; target++)
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
	
	int sentry;
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


void Charge_New_Salmon(const char[] ability_name, int boss, int client, int slot, int action)
{
	int weapon;
	float charge=FF2_GetBossCharge(boss,slot);
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
	HP=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 16, 0); // HP
	Ammo=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 17); // Ammo
	Clip=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 18); // Clip
	VO = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 19);	 // Voice lines
	PickupMode = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 20); // PickupMode?
	FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 21, Condition, sizeof(Condition)); // Conditions

	switch (action)
	{
		case 1:
		{
			switch(slot)
			{
				case 1:
					SetHudTextParams(-1.0, 0.88, 0.15, 255, 64, 64, 255);
				case 2:
					SetHudTextParams(-1.0, 0.93, 0.15, 255, 64, 64, 255);
			}
			ShowSyncHudText(client, jumpHUD, "%t","salmon_status_2",-RoundFloat(charge));
		}
		case 2:
		{
			switch(slot)
			{
				case 1:
					SetHudTextParams(-1.0, 0.88, 0.15, 255, 64, 64, 255);
				case 2:
					SetHudTextParams(-1.0, 0.93, 0.15, 255, 64, 64, 255);
			}
			if (bEnableSuperDuperJump[boss])
			{
				switch(slot)
				{
					case 1:
						SetHudTextParams(-1.0, 0.88, 0.15, 255, 64, 64, 255);
					case 2:
						SetHudTextParams(-1.0, 0.93, 0.15, 255, 64, 64, 255);
				}
				ShowSyncHudText(client, jumpHUD,"%t","super_duper_jump");
			}	
			else
				ShowSyncHudText(client, jumpHUD, "%t","salmon_status",RoundFloat(charge));
		}
		case 3:
		{
			Action act = Plugin_Continue;
			int super = bEnableSuperDuperJump[boss];
			Call_StartForward(OnHaleJump);
			Call_PushCellRef(super);
			Call_Finish(act);
			if (act != Plugin_Continue && act != Plugin_Changed)
				return;
			if (act == Plugin_Changed) bEnableSuperDuperJump[boss] = super;
			
			static float pos[3];
			if (bEnableSuperDuperJump[boss])
			{
				static float vel[3];
				static float rot[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
				GetClientEyeAngles(client, rot);
				vel[2]=750.0+500.0*charge/70+2000;
				vel[0]+=Cosine(DegToRad(rot[0]))*Cosine(DegToRad(rot[1]))*500;
				vel[1]+=Cosine(DegToRad(rot[0]))*Sine(DegToRad(rot[1]))*500;
				bEnableSuperDuperJump[boss]=false;
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
			}
			else
			{
				if(charge<100)
				{
					CreateTimer(0.1, Timer_ResetCharge, boss*10000+slot);
					return;					
				}
				
				int ii;
				
				if(Sound!=0)
					EmitSoundToAll(ZEPH_SND);
					
				for (int i=0; i<Minions; i++)
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
							int owner, entity;
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
								TF2_SetPlayerClass(ii, view_as<TFClassType>(KvGetNum(curBossKV, "class", 0)), _, false);
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
					
								if(Class)
								{
									TF2_SetPlayerClass(ii, view_as<TFClassType>(Class), _, false);
								}
					
								SetPlayerModel(ii, SalmonModel);
					
								if(VO)
								{
									VOMode[ii]=view_as<VoiceMode>(VO);
								}
							}
						
						}
						if(Notify!=0)
						{
							char spcl[768];
							FF2_GetBossSpecial(boss, spcl, sizeof(spcl));
							PrintHintText(client, "%t", "minion_summoner");
							PrintHintText(ii, "%t", "minion_summoned", spcl);
						}
			
						if(HP)
						{
							SetEntProp(ii, Prop_Data, "m_iMaxHealth", HP);
							SetEntProp(ii, Prop_Data, "m_iHealth", HP);
							SetEntProp(ii, Prop_Send, "m_iHealth", HP);
						}
					}
				}
			}
			static char s[PLATFORM_MAX_PATH];
			if (FF2_RandomSound("sound_ability",s,PLATFORM_MAX_PATH,boss,slot))
			{
				EmitSoundToAll(s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
				EmitSoundToAll(s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
					
				for (int i=1; i<=MaxClients; i++)
				{
					if (IsClientInGame(i) && i!=client)
					{
						EmitSoundToClient(i,s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
						EmitSoundToClient(i,s, client, _, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
					}
				}
			}
		}
	}
}

stock void SetPlayerModel(int client, char[] model)
{	
	if(!IsModelPrecached(model))
	{
		PrecacheModel(model);
	}
	
	SetVariantString(model);
	AcceptEntityInput(client, "SetCustomModel");
	SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
}

public Action Timer_ResetCharge(Handle timer, any index)
{
	int slot=index%10000;
	index/=1000;
	FF2_SetBossCharge(index,slot,0.0);
}

public Action FF2_OnTriggerHurt(int index, int triggerhurt,float& damage)
{
	bEnableSuperDuperJump[index]=true;
	if (FF2_GetBossCharge(index,1)<0)
		FF2_SetBossCharge(index,1,0.0);
	return Plugin_Continue;
}


public Action SoundHook(int clients[MAXPLAYERS], int& numClients, char vl[PLATFORM_MAX_PATH],
					  int& client, int& channel, float& volume, int& level, int& pitch, int& flags,
					  char soundEntry[PLATFORM_MAX_PATH], int& seed)
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
					int rand = GetRandomInt(1,18);
					Format(vl, sizeof(vl), "mvm/player/footsteps/robostep_%s%i.wav", (rand < 10) ? "0" : "", rand);
					pitch = GetRandomInt(95, 100);
					EmitSoundToAll(vl, client, _, _, _, 0.25, pitch);
				}
				
				if(channel==SNDCHAN_VOICE)
				{
					if (volume == 0.99997) return Plugin_Continue;
					ReplaceString(vl, sizeof(vl), "vo/", "vo/mvm/norm/", false);
					ReplaceString(vl, sizeof(vl), ".wav", ".mp3", false);
					char classname[10], classname_mvm[15];
					TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
					Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
					ReplaceString(vl, sizeof(vl), classname, classname_mvm, false);
					char nSnd[PLATFORM_MAX_PATH];
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
stock void Wearable_EquipWearable(int client, int wearable)
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

stock void SetAmmo(int client, int slot, int ammo)
{
	int weapon2 = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon2))
	{
		int iOffset = GetEntProp(weapon2, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}

stock void SetCondition(int client, const char[] cond) // Sets multi TFConds to a client
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		for (int i = 0; i < count; i+=2)
		{
			TF2_AddCondition(client, view_as<TFCond>(StringToInt(conds[i])), StringToFloat(conds[i+1]));
		}
	}
}

stock int GetRandomDeadPlayer()
{
	int clientCount;
	int[] clients = new int[MaxClients + 1];
	for(int i=1;i<=MaxClients;i++)
	{
		if (IsValidEdict(i) && IsClientConnected(i) && IsClientInGame(i) && !IsPlayerAlive(i) && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

stock bool IsValidBoss(int client)
{
	if (FF2_GetBossIndex(client) == -1) return false;
	return true;
}

stock bool IsValidMinion(int client)
{
	if (GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	if (FF2_GetBossIndex(client) != -1) return false;
	if (SummonerIndex[client] == -1) return false;
	return true;
}

stock void TF2_GetNameOfClass(TFClassType class, char[] name, int maxlen) // Retrieves player class name
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

stock int AttachParticle(int entity, char[] particleType, float offset=0.0, bool attach=true)
{
	int particle=CreateEntityByName("info_particle_system");

	static char targetName[128];
	float position[3];
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
public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity=EntRefToEntIndex(entid);
	if(IsValidEntity(entity) && entity>MaxClients)
		RemoveEntity(entity);
}
public Action Timer_EnableSentry(Handle timer, any sentryid)
{
	int sentry=EntRefToEntIndex(sentryid);
	if(FF2_GetRoundState()==1 && sentry>MaxClients)
	{
		SetEntProp(sentry, Prop_Send, "m_bDisabled", 0);
	}
	return Plugin_Continue;
}

// need to briefly stun the target if they have continuous or other special weapons out
// these weapons can do so much as crash the user's client if they're quick switched
// the stun-unstun will prevent this from happening, but it may or may not stop the target's motion if on ground
stock void PrepareForWeaponSwitch(int clientIdx, bool isBoss)
{
	int primary = GetPlayerWeaponSlot(clientIdx, TFWeaponSlot_Primary);
	if (!IsValidEntity(primary) || primary != GetEntPropEnt(clientIdx, Prop_Send, "m_hActiveWeapon"))
		return;
	
	bool shouldStun = false;
	static char restoreClassname[MAX_ENTITY_CLASSNAME_LENGTH];
	int itemDefinitionIndex = -1;
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

stock bool EntityStartsWith(int entity, const char[] desiredPrefix)
{
	static char classname[MAX_ENTITY_CLASSNAME_LENGTH];
	GetEntityClassname(entity, classname, MAX_ENTITY_CLASSNAME_LENGTH);
	return StrContains(classname, desiredPrefix) == 0;
}

stock int min(int n1, int n2)
{
	return n1 < n2 ? n1 : n2;
}
