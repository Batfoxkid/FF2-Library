 /*

	Are you ready to MANN UP, LADIES?
	
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <morecolors>
#include <ff2_ams>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#tryinclude <goomba>
#define REQUIRE_PLUGIN

// Version Number
#define MAJOR_REVISION "1"
#define MINOR_REVISION "0"
//#define PATCH_REVISION "0"

#if !defined PATCH_REVISION
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION
#else
	#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...PATCH_REVISION
#endif

public Plugin:myinfo = {
	name = "Freak Fortress 2: Gray Mann",
	author = "SHADoW NiNE TR3S",
	description="Get ready to MANN UP!",
	version=PLUGIN_VERSION,
};

enum GMBossType
{
	// Non-boss
	GBossType_None=-1,
	
	// Gray Mann
	GBossType_GrayMann=1,
	
	// Scout Bosses
	GBossType_SuperScout,
	GBossType_FaNSuperScout,
	GBossType_JumpingSandmanScout,
	GBossType_MajorLeagueScout,
	GBossType_GiantBonkScout,
	GBossType_ArmoredGiantSandmanScout,
	
	// Soldier Bosses
	GBossType_GiantSoldier,
	GBossType_GiantBuffBannerSoldier,
	GBossType_GiantBattalionSoldier,
	GBossType_GiantConcherorSoldier,
	GBossType_GiantRapidFireSoldier,
	GBossType_GiantBurstFireSoldier,
	GBossType_GiantChargedSoldier,
	GBossType_GiantBlastSoldier,
	GBossType_ColonelBarrageSoldier,
	GBossType_GiantBlackBoxSoldier,
	GBossType_SergeantCrits,
	GBossType_MajorCrits,
	GBossType_ChiefBlastSoldier,
	
	// Pyro Bosses
	GBossType_GiantPyro,
	GBossType_GiantFlarePyro,

	// Demoman Bosses
	GBossType_GiantRapidFireDemo,
	GBossType_GiantBurstFireDemo,
	GBossType_GiantDemoKnight,
	GBossType_MajorBomber,
	GBossType_SirNukesalot,
	GBossType_SentryBuster,
	
	// Heavy Bosses
	GBossType_GiantHeavy,
	GBossType_GiantShotgunHeavy,
	GBossType_GiantDeflectorHeavy,
	GBossType_GiantHeaterHeavy,
	GBossType_CaptainPunch,
	GBossType_GiantHealOnKillHeavy,
	
	// Medic Minion
	GBossType_GiantMedic,
}

new bossID;
new ClassCount, AlivePlayerCount;
new GMBossType:Special[MAXPLAYERS+1];
new SpecialIndex[MAXPLAYERS+1];

new bool:IsMiniBoss[MAXPLAYERS+1]=false;
new bool:IsMechaBoss[MAXPLAYERS+1]=false;
new bool:IsRoundActive=false;
new bool:IsPlayerSapEnabled=false;
new bkStabMode;

new limit[MAXPLAYERS+1];
new limit2[MAXPLAYERS+1];

new bkstabDiv;
new bkstabDiv2;

new Float:sapDur;
new Float:sapDur2;
new Float:sapDist;

new buildpage[MAXPLAYERS+1];

new bool:hooked=false;

#define SentryBusterTick "mvm/sentrybuster/mvm_sentrybuster_loop.wav"
#define SentryBusterSpawn "mvm/sentrybuster/mvm_sentrybuster_intro.wav"
#define SentryBusterModel "models/bots/demo/bot_sentry_buster.mdl"
#define SentryBusterExplode "mvm/sentrybuster/mvm_sentrybuster_explode.wav"

static const String:SentryBusterAlert[][] = {
	"vo/mvm_sentry_buster_alerts01.mp3",
	"vo/mvm_sentry_buster_alerts02.mp3",
	"vo/mvm_sentry_buster_alerts03.mp3",
	"vo/mvm_sentry_buster_alerts04.mp3",
	"vo/mvm_sentry_buster_alerts05.mp3",
	"vo/mvm_sentry_buster_alerts06.mp3",
	"vo/mvm_sentry_buster_alerts07.mp3"
};

static const String:SpyAlert[][] = {
	"vo/mvm_spy_spawn01.mp3",
	"vo/mvm_spy_spawn02.mp3",
	"vo/mvm_spy_spawn03.mp3",
	"vo/mvm_spy_spawn04.mp3"
};

static const String:EngyAlert[][] = {
	"vo/announcer_mvm_engbot_arrive01.mp3",
	"vo/announcer_mvm_engbot_arrive02.mp3",
	"vo/announcer_mvm_engbot_arrive03.mp3",
	"vo/announcer_mvm_engbot_another01.mp3",
	"vo/announcer_mvm_engbot_another02.mp3"
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart);
	HookEvent("arena_win_panel", Event_RoundEnd);
	
	for (new i = 0; i < sizeof(SentryBusterAlert); i++)
	{
		PrecacheSound(SentryBusterAlert[i], true);
	}
	for (new i = 0; i < sizeof(SpyAlert); i++)
	{
		PrecacheSound(SpyAlert[i], true);
	}
	for (new i = 0; i < sizeof(EngyAlert); i++)
	{
		PrecacheSound(EngyAlert[i], true);
	}
	
	PrecacheSound(SentryBusterTick, true);
	PrecacheSound(SentryBusterSpawn, true);
	PrecacheSound(SentryBusterExplode, true);

}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (!FF2_IsFF2Enabled() || !IsRoundActive || !IsPlayerSapEnabled)
		return Plugin_Continue;
	
	new index=-1;
	new wepEntity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(wepEntity) || IsValidEdict(wepEntity))
	{
		new String:classname[64];
		GetEdictClassname(wepEntity, classname, sizeof(classname));
		index=GetEntProp(wepEntity, Prop_Send, "m_iItemDefinitionIndex");
	
		if(GetClientTeam(client)!=FF2_GetBossTeam() && (buttons & IN_ATTACK))
		{
			if(!strcmp(classname, "tf_weapon_sapper") || !strcmp(classname, "tf_weapon_builder") && (index==735 || index==736))
			{
				if(TF2_IsPlayerInCondition(client, TFCond_Cloaked) || GetEntProp(client, Prop_Send, "m_bFeignDeathReady"))
					return Plugin_Continue;
		
				new Float:pos[3], Float:pos2[3], Float:dist;
	
				GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
				for(new target=1; target<=MaxClients; target++)
				{
					if(IsValidClient(target) && IsPlayerAlive(target) && GetClientTeam(target)==FF2_GetBossTeam() && (IsMiniBoss[target]||IsMechaBoss[target]))
					{
						GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
						dist = GetVectorDistance(pos, pos2);
						if(dist < sapDist && (!TF2_IsPlayerInCondition(target, TFCond_Dazed) || !TF2_IsPlayerInCondition(target, TFCond_Sapped) || !TF2_IsPlayerInCondition(target, TFCond_UberchargedHidden) || !TF2_IsPlayerInCondition(target, TFCond_Ubercharged)) && target!=client)
						{
							TF2_StunPlayer(target, IsMechaBoss[target] ? sapDur2 : sapDur, 0.0, TF_STUNFLAGS_NORMALBONK|TF_STUNFLAG_NOSOUNDOREFFECT, client);
							TF2_AddCondition(target, TFCond_Sapped, IsMechaBoss[target] ? sapDur2 : sapDur);
						
							SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
							Debug("Sapping %N for %i seconds (was within range of %i)", target, RoundFloat(IsMechaBoss[target] ? sapDur2 : sapDur), RoundFloat(sapDist));
							return Plugin_Handled;
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String: name[], bool:dontBroadcast)
{
	if (!FF2_IsFF2Enabled())
		return;

	bossID = GetClientOfUserId(FF2_GetBossUserId(0));
	IsRoundActive=true;
	
	for(new client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
			
		limit[client]=0;
		limit2[client]=0;
		IsMiniBoss[client]=false;
		IsMechaBoss[client]=false;
		Special[client]=GBossType_None;
		SpecialIndex[client]=_:GBossType_None;
			
		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			if(FF2_HasAbility(boss, this_plugin_name, "graymann_config"))
			{
				new String:duration[32][32], String:divider[32][32], count;
		
				Special[bossID] = GBossType_GrayMann;
				SetEntData(bossID, FindDataMapOffs(bossID, "m_iAmmo") + (3 * 4), 9999, 4);
			
				MVM_AddHooks();
			
				new String:sapConfig[64];
				if(sapConfig[0]=='\0')
				{
					sapConfig="5 ; 10";
				}
				FF2_GetAbilityArgumentString(0, this_plugin_name, "graymann_config", 1, sapConfig, sizeof(sapConfig));
		
				count = ExplodeString(sapConfig, " ; ", duration, sizeof(duration), sizeof(duration));
				if (count > 0)
				{
					for (new i = 0; i < count; i+=2)
					{
						sapDur=StringToFloat(duration[i]);
						sapDur2=StringToFloat(duration[i+1]);
					}
				}

				sapDist=FF2_GetAbilityArgumentFloat(0, this_plugin_name, "graymann_config", 2, 120.0);		
			
				if(sapDist)
				{
					IsPlayerSapEnabled=true;
				}
			
				bkStabMode=FF2_GetAbilityArgument(0, this_plugin_name, "graymann_config", 3);
			
				new String:stabConfig[64];
				if(stabConfig[0]=='\0')
				{
					stabConfig="4 ; 6";
				}
				FF2_GetAbilityArgumentString(0, this_plugin_name, "graymann_config", 4, stabConfig, sizeof(stabConfig));
		
				count = ExplodeString(stabConfig, " ; ", divider, sizeof(divider), sizeof(divider));
				if (count > 0)
				{
					for (new i = 0; i < count; i+=2)
					{
						bkstabDiv=StringToInt(divider[i]);
						bkstabDiv2=StringToInt(divider[i+1]);
					}
				}
				
				AMS_InitSubability(boss, client, this_plugin_name, "graymann_pda1", "GM1"); // Scout
				AMS_InitSubability(boss, client, this_plugin_name, "graymann_pda2", "GM2"); // Soldier
				AMS_InitSubability(boss, client, this_plugin_name, "graymann_pda3", "GM3"); // Pyro
				AMS_InitSubability(boss, client, this_plugin_name, "graymann_pda4", "GM4"); // Demoman
				AMS_InitSubability(boss, client, this_plugin_name, "graymann_pda5", "GM5"); // Heavy
				AMS_InitSubability(boss, client, this_plugin_name, "graymann_pda6", "GM6"); // Medic
				AMS_InitSubability(boss, client, this_plugin_name, "graymann_pda7", "GM7"); // MegaBoss
				AMS_InitSubability(boss, client, this_plugin_name, "graymann_pda8", "GM8"); // Sentry Buster
			
			}		
		}
	}
}

public Action:Event_RoundEnd(Handle:event, const String: name[], bool:dontBroadcast)
{
	IsRoundActive=false;
	IsPlayerSapEnabled=false;
	if(IsValidClient(bossID) && IsPlayerAlive(bossID) && Special[bossID] == GBossType_GrayMann)
	{
		SetEntPropEnt(bossID, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(bossID, TFWeaponSlot_Melee));
		TF2_RemoveWeaponSlot(bossID, 3); // No point in keeping this on an inactive round
		TF2_RemoveWeaponSlot(bossID, 5); // No point in keeping this on an inactive round
	} 
	
	for(new client=1;client<=MaxClients;client++)
	{
		if(IsValidClient(client))
		{
			limit[client]=0;
			limit2[client]=0;
			IsMiniBoss[client]=false;
			IsMechaBoss[client]=false;
			Special[client]=GBossType_None;
			SpecialIndex[client]=_:GBossType_None;
		}
	}
	
	MVM_RemoveHooks();
}

public Action:Event_PlayerDeath(Handle:event, const String: name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new boss = FF2_GetBossIndex(client);

	if(!IsValidClient(client) || !FF2_IsFF2Enabled() || FF2_GetRoundState()!=1 || !IsRoundActive || (GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
		return Plugin_Continue;
	
	if(boss>=0)
	{
		for(new target=1;target<=MaxClients;target++)
		{
			if(IsValidClient(target) && (IsMiniBoss[target]||IsMechaBoss[target]) && IsPlayerAlive(target))
			{
				if(Special[target]==GBossType_SentryBuster)
				{
					StopSound(target, SNDCHAN_AUTO, SentryBusterTick);
				}			

				SpecialIndex[target]=_:GBossType_None;
				Special[target]=GBossType_None;
				IsMiniBoss[target]=false;
				IsMechaBoss[target]=false;
				ChangeClientTeam(target, (FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue));
				SDKUnhook(target, SDKHook_OnTakeDamage, OnTakeDamage);
			}
		}
	}
	
	if(IsMiniBoss[client] || IsMechaBoss[client])
	{
		StopSound(client, SNDCHAN_AUTO, SentryBusterTick);
		SpecialIndex[client]=_:GBossType_None;
		Special[client]=GBossType_None;
		IsMiniBoss[client]=false;
		IsMechaBoss[client]=false;
		ChangeClientTeam(client, (FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue));
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	
	return Plugin_Continue;
}

public Action:Event_PlayerInventory(Handle:event, const String: name[], bool:dontBroadcast)
{
	new String:Alert[PLATFORM_MAX_PATH];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1 || !IsRoundActive)
		return Plugin_Continue;
		
	if(GetClientTeam(client) != FF2_GetBossTeam() || FF2_GetBossIndex(client)>=0)
		return Plugin_Continue;
		
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Spy:
		{
			strcopy(Alert, sizeof(Alert), SpyAlert[GetRandomInt(0, sizeof(SpyAlert)-1)]);	
			ShowTFMessage("Spy bots have spawned!");
		}
		case TFClass_Engineer:
		{
			strcopy(Alert, sizeof(Alert), EngyAlert[GetRandomInt(0, sizeof(EngyAlert)-1)]);
			ShowTFMessage("Engineer bots have spawned! Destroy them and their teleporters!");
		}
		case TFClass_DemoMan:
		{
			if(Special[client]==GBossType_SentryBuster)
			{
				EmitSoundToAll(SentryBusterSpawn);
				strcopy(Alert, sizeof(Alert), SentryBusterAlert[GetRandomInt(0, sizeof(SentryBusterAlert)-1)]);
				EmitSoundToAll(SentryBusterTick, client);
				ShowTFMessage("Engineers! Watch out for sentry busters!");
			}
		}
	}
	if(Alert[0]!='\0')
		EmitSoundToAll(Alert);
	return Plugin_Continue;
}

public Action:FF2_OnAbility2(boss,const String:plugin_name[],const String:ability_name[],action) // Not used by abilities
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1 || !IsRoundActive)
		return Plugin_Continue;
	return Plugin_Continue;
}

public bool:GM1_CanInvoke(client)
{
	return true;
}

public GM1_Invoke(client)
{		
	new boss=FF2_GetBossIndex(client);
	decl String:activator_string[768], String:boss_spawn_rate[64];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 5, activator_string, sizeof(activator_string));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 6, boss_spawn_rate, sizeof(boss_spawn_rate));
	MvM_GivePDA(client, 1, activator_string, boss_spawn_rate);
}

public bool:GM2_CanInvoke(client)
{
	return true;
}

public GM2_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:activator_string[768], String:boss_spawn_rate[64];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 7, activator_string, sizeof(activator_string));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 8, boss_spawn_rate, sizeof(boss_spawn_rate));
	MvM_GivePDA(client, 2, activator_string, boss_spawn_rate);
}

public bool:GM3_CanInvoke(client)
{
	return true;
}

public GM3_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:activator_string[768], String:boss_spawn_rate[64];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 9, activator_string, sizeof(activator_string));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 10, boss_spawn_rate, sizeof(boss_spawn_rate));
	MvM_GivePDA(client, 3, activator_string, boss_spawn_rate);
}

public bool:GM4_CanInvoke(client)
{
	return true;
}

public GM4_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:activator_string[768], String:boss_spawn_rate[64];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 11, activator_string, sizeof(activator_string));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 12, boss_spawn_rate, sizeof(boss_spawn_rate));
	MvM_GivePDA(client, 4, activator_string, boss_spawn_rate);
}

public bool:GM5_CanInvoke(client)
{
	return true;
}

public GM5_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:activator_string[768], String:boss_spawn_rate[64];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 13, activator_string, sizeof(activator_string));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 14, boss_spawn_rate, sizeof(boss_spawn_rate));
	MvM_GivePDA(client, 5, activator_string, boss_spawn_rate);
}

public bool:GM6_CanInvoke(client)
{
	return true;
}

public GM6_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:activator_string[768], String:boss_spawn_rate[64];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 15, activator_string, sizeof(activator_string));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 16, boss_spawn_rate, sizeof(boss_spawn_rate));
	MvM_GivePDA(client, 6, activator_string, boss_spawn_rate);
}

public bool:GM7_CanInvoke(client)
{
	return true;
}

public GM7_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:activator_string[768], String:boss_spawn_rate[64];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 17, activator_string, sizeof(activator_string));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 18, boss_spawn_rate, sizeof(boss_spawn_rate));
	MvM_GivePDA(client, 7, activator_string, boss_spawn_rate);
}

public bool:GM8_CanInvoke(client)
{
	return true;
}

public GM8_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:activator_string[768], String:boss_spawn_rate[64];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 19, activator_string, sizeof(activator_string));	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, "graymann_config", 20, boss_spawn_rate, sizeof(boss_spawn_rate));
	MvM_GivePDA(client, 8, activator_string, boss_spawn_rate);
}


public MvM_GivePDA(client, type, String:activator_string[768], String:boss_spawn_rate[64])
{
	new boss=FF2_GetBossIndex(client);
	if(IsValidClient(client) && boss>=0)
	{	
		// Hint text to tell boss to switch to PDA
		new String:rate[32][32];
		new count = ExplodeString(boss_spawn_rate, " ; ", rate, sizeof(rate), sizeof(rate));
		if (count > 0)
		{
			for (new i = 0; i < count; i+=2)
			{
				limit[boss]=StringToInt(rate[i]);
				limit[boss]=StringToInt(rate[i+1]);
			}
		}
		
		if(!IsFakeClient(client))
		{
			SetHudTextParams(-1.0, 0.30, 7.0, 255, 255, 255, 255, 2);
			Format(activator_string, sizeof(activator_string), "%s", activator_string);
			ShowHudText(client, -1, activator_string);		
		}
		
		// Modified PDA for use as miniboss spawner
		new entity = SpawnWeapon(client, "tf_weapon_builder", 28, 101, 5, "391 ; 2"); // Builder
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 0);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 1);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 1, _, 2);
		SetEntProp(entity, Prop_Send, "m_aBuildableObjectTypes", 0, _, 3);
		
		// PDA Boss Spawner
		new remote = SpawnWeapon(client, "tf_weapon_pda_engineer_build", 26, 101, 5, "292 ; 3 ; 293 ; 59 ; 391 ; 2 ; 495 ; 60");
		
		buildpage[client]=type;
		
		if(IsFakeClient(client))
		{
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", remote);
			FakeClientCommand(client, "build");
		}
	}
}

public Action:GrayMann_PDA(client, const String:command[], argc)
{	
	if(Special[client]!=GBossType_GrayMann)
	{
		return Plugin_Continue;
	}	
	
	new boss=FF2_GetBossIndex(client);
	switch(buildpage[client])
	{
		case 1: // Scouts
		{
			switch(GetRandomInt(0,5)) // Scouts
			{
				case 0: SetMiniBoss(boss, GBossType_SuperScout, 1200, "tf_weapon_bat_fish", 221, "107 ; 2 ; 252 ; 0.7", limit[boss], false);
				case 1: SetMiniBoss(boss, GBossType_MajorLeagueScout, 1600, "tf_weapon_bat_wood", 44, "252 ; 0.7 ; 38 ; 1 ; 278 ; 0.1", limit[boss], false);
				case 2: SetMiniBoss(boss, GBossType_ArmoredGiantSandmanScout, 3000, "tf_weapon_bat_wood", 44, "252 ; 0.7 ; 38 ; 1 ; 278 ; 0.05 ; 54 ; 0.75", limit[boss], false);
				case 3: SetMiniBoss(boss, GBossType_GiantBonkScout, 1600, "tf_weapon_lunchbox_drink", 46, "278 ; 0.55", limit[boss], false);
				case 4: SetMiniBoss(boss, GBossType_FaNSuperScout, 1200, "tf_weapon_scattergun", 45, "3 ; 0.33 ; 1 ; 0.35 ; 6 ; 0.5 ; 97 ; 0.3 ; 45 ; 2 ; 106 ; 1.6 ; 252 ; 0.7 ; 44 ; 1 ; 112 ; 2 ; 323 ; 100", limit[boss], false);
				case 5: SetMiniBoss(boss, GBossType_JumpingSandmanScout, 1200, "tf_weapon_bat_wood", 44, "2 ; 2 ; 326 ; 2 ; 252 ; 0.7 ; 38 ; 1 ; 278 ; 0.1", limit[boss], false);							
			}
		}
		case 2: // Soldiers
		{
			switch(GetRandomInt(0,7)) // Soldiers
			{
				case 0: SetMiniBoss(boss, GBossType_GiantSoldier, 3800, "tf_weapon_rocketlauncher", 18, "54 ; 0.5 ; 97 ; -4.0 ; 104 ; 0.65 ; 4 ; 0 ; 252 ; 0.4 ; 413 ; 1 ; 112 ; 2", limit[boss], false);
				case 1: SetMiniBoss(boss, GBossType_GiantBurstFireSoldier, 4200, "tf_weapon_rocketlauncher", 18, "54 ; 0.5 ; 252 ; 0.4 ; 2 ; 2 ; 4 ; 2.25 ; 97 ; 0.4 ; 4 ; 0.2 ; 104 ; 0.9 ; 413 ; 1 ; 112 ; 2", limit[boss], false);
				case 2: SetMiniBoss(boss, GBossType_GiantBuffBannerSoldier, 3800, "tf_weapon_buff_item", 129, "116 ; 1 ; 292 ; 51 ; 319 ; 9 ; 112 ; 2", limit[boss], false);
				case 3: SetMiniBoss(boss, GBossType_GiantBattalionSoldier, 3800, "tf_weapon_buff_item", 226, "116 ; 2 ; 292 ; 51 ; 319 ; 9 ; 112 ; 2", limit[boss], false);
				case 4: SetMiniBoss(boss, GBossType_GiantConcherorSoldier, 3800, "tf_weapon_buff_item", 354, "116 ; 3 ; 292 ; 51 ; 319 ; 9 ; 112 ; 2", limit[boss], false);
				case 5: SetMiniBoss(boss, GBossType_GiantChargedSoldier, 3800, "tf_weapon_rocketlauncher", 513, "252 ; 0.4 ; 104 ; 0.5 ; 5 ; 1.50 ; 54 ; 0.5 ; 97 ; 0.2", limit[boss], false);
				case 6: SetMiniBoss(boss, GBossType_GiantBlackBoxSoldier, 4200, "tf_weapon_rocketlauncher", 228, "16 ; 1000 ; 112 ; 2 ; 252 ; 0.4 ; 104 ; 0.9 ; 5 ; 1.60 ; 99 ; 1.25 ; 96 ; 1.6 ; 54 ; 0.5 ; 1 ; 0.45 ; 413 ; 1 ; 411 ; 4 ; 6 ; 0.0 ; 3 ; 0.75", limit[boss], false);
				case 7: SetMiniBoss(boss, GBossType_GiantBlastSoldier, 3800, "tf_weapon_rocketlauncher", 414, "252 ; 0.4 ; 4 ; 1.25 ; 97 ; 0.2 ; 6 ; 0.25 ; 99 ; 1.20 ; 54 ; 0.5 ; 413 ; 1 ; 411 ; 4 ; 112 ; 2 ; 103 ; 1.4", limit[boss], false);
			}		
		}
		case 3: // Pyros
		{
			switch(GetRandomInt(0,1)) // Pyros
			{
				case 0: SetMiniBoss(boss, GBossType_GiantPyro, 3000, "tf_weapon_flamethrower", 21, "252 ; 0.6 ; 54 ; 0.5 ; 112 ; 2", limit[boss], false);
				case 1: SetMiniBoss(boss, GBossType_GiantFlarePyro, 3000, "tf_weapon_flaregun", 351, "207 ; 0.75 ; 252 ; 0.6 ; 6 ; 0.3 ; 54 ; 0.5 ; 112 ; 2", limit[boss], false);
			}
		}
		case 4: // Demomen
		{
			switch(GetRandomInt(0,2))
			{
				case 0: SetMiniBoss(boss, GBossType_GiantRapidFireDemo, 3000, "tf_weapon_grenadelauncher", 19, "252 ; 0.7 ; 6 ; 0.75 ; 97 ; 0.4 ; 413 ; 1 ; 112 ; 2", limit[boss], false);
				case 1: SetMiniBoss(boss, GBossType_GiantBurstFireDemo, 3300, "tf_weaapon_grenadelauncher", 19, "252 ; 0.4 ; 6 ; 0.1 ; 4 ; 2.75 ; 103 ; 1.1 ; 413 ; 1 ; 54 ; 0.5 ; 411 ; 5", limit[boss], false);
				case 2: SetMiniBoss(boss, GBossType_GiantDemoKnight, 3300, "tf_weapon_sword", 132, "252 ; 0.5 ; 54 ; 0.5 ; 31 ; 3", limit[boss], false);
			}		
		}
		case 5: // Heavy
		{
			switch(GetRandomInt(0,4)) // Heavy
			{
				case 0: SetMiniBoss(boss, GBossType_GiantHeavy, 5000, "tf_weapon_minigun", 15, "252 ; 0.3 ; 2 ; 1.5 ; 54 ; 0.5 ; 112 ; 2", limit[boss], false);
				case 1: SetMiniBoss(boss, GBossType_GiantDeflectorHeavy, 5000, "tf_weapon_minigun", 15, "252 ; 0.3 ; 2 ; 1.5 ; 54 ; 0.5 ; 112 ; 2 ; 323 ; 100", limit[boss], false);
				case 2: SetMiniBoss(boss, GBossType_GiantHealOnKillHeavy, 5500, "tf_weapon_minigun", 15, "180 ; 5000 ; 252 ; 0.3 ; 2 ; 1.2 ; 54 ; 0.4 ; 112 ; 2 ; 323 ; 100", limit[boss], false);
				case 3: SetMiniBoss(boss, GBossType_GiantHeaterHeavy, 5000, "tf_weapon_minigun", 811, "430 ; 1 ; 431 ; 6 ;  252 ; 0.3 ; 54 ; 0.5 ; 112 ; 2", limit[boss], false);
				case 4: SetMiniBoss(boss, GBossType_GiantShotgunHeavy, 5000, "tf_weapon_shotgun_hwg", 11, "1 ; 0.75 ; 5 ; 2.5 ; 97 ; 0.1 ; 252 ; 0.3 ; 54 ; 0.7 ; 112 ; 2 ; 323 ; 100", limit[boss], false);									
			}
		}
		case 6: // Medic
		{
			SetMiniBoss(boss, GBossType_GiantMedic, 4500, "tf_weapon_medigun", 411, "231 ; 1 ; 8 ; 202", limit[boss]); // Medic
		}
		case 7: // Sentry Busters
		{
			switch(GetClassCount(_:TFClass_Engineer, ((FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue)))) // Sentry Buster
			{
				case 0: // No engies :(
				{
					SetHudTextParams(-1.0, 0.45, 4.0, 255, 255, 255, 255, 2);
					ShowHudText(client, -1, "There are no alive engineers to be able to spawn a sentry buster!");	
					return Plugin_Handled;
				}
				default: // Sentry Buster
				{
					SetMiniBoss(boss, GBossType_SentryBuster, 2500, "tf_weapon_stickbomb", 307, "107 ; 2 ; 252 ; 0.5 ; 329 ; 0.5 ; 329 ; 0.5 ; 330 ; 7 ; 402 ; 1 ; 326 ; 0 ; 138 ; 0 ; 137 ; 38.461540 ; 275 ; 1", GetClassCount(_:TFClass_Engineer, ((FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue))));	
				}
			}
		}
		case 8: // MEGA Boss
		{
			SpawnMegaBoss(boss, limit2[boss]); // MegaBoss
		}
	}

	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
	TF2_RemoveWeaponSlot(client, 3); // Remove once boss has picked a miniboss to spawn.
	TF2_RemoveWeaponSlot(client, 5); // Remove once boss has picked a miniboss to spawn.
	return Plugin_Handled;
}



public MVM_AddHooks()
{	
	if(!hooked)
	{
		hooked=true;
	}
	AddNormalSoundHook(SoundHook);
	
	AddCommandListener(GrayMann_PDA, "build");
	AddCommandListener(SentryBuster_Detonate, "taunt");
	AddCommandListener(SentryBuster_Detonate, "+taunt");

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_PlayerInventory, EventHookMode_Pre);	
}

public MVM_RemoveHooks()
{	
	if(hooked)
	{
		RemoveNormalSoundHook(SoundHook);
		RemoveCommandListener(GrayMann_PDA, "build");
		RemoveCommandListener(SentryBuster_Detonate, "taunt");
		RemoveCommandListener(SentryBuster_Detonate, "+taunt");
		
		UnhookEvent("post_inventory_application", Event_PlayerInventory, EventHookMode_Pre);	
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		hooked=false;
	}
}

public Action:SentryBuster_Detonate(client, const String:command[], argc)
{
	if(IsValidClient(client) && Special[client]==GBossType_SentryBuster)
	{
		CreateTimer(2.1, SentryBusting, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}


/* 
	Miniboss Spawner
*/

public SpawnMegaBoss(boss, quantity)
{
	switch(GetRandomInt(1,4))
	{
		case 1: SetMiniBoss(boss, GBossType_MajorBomber, 40000, "tf_weaapon_grenadelauncher", 19, "252 ; 0.7 ; 6 ; 0.2 ; 97 ; 0.3 ; 4 ; 3 ; 103 ; 1.5 ; 413 ; 1 ; 54 ; 0.32 ; 57 ; 200", quantity, true);
		case 2: SetMiniBoss(boss, GBossType_SirNukesalot, 50000, "tf_weapon_cannon", 996, "467 ; 1 ; 252 ; 0.4 ; 2 ; 8 ; 99 ; 1.2 ; 54 ; 35 ; 104 ; 0.8 ; 3 ; 0.5 ; 96 ; 1.8 ; 5 ; 3 ; 511 ; 5 ; 413 ; 1", quantity, true);
		case 3: SetMiniBoss(boss, GBossType_GiantHealOnKillHeavy, 60000, "tf_weapon_minigun", 15, "180 ; 8000 ; 252 ; 0.3 ; 2 ; 1.2 ; 54 ; 0.4 ; 112 ; 2 ; 323 ; 100", quantity, true);
		case 4: SetMiniBoss(boss, GBossType_CaptainPunch, 60000, "tf_weapon_fists", 331, "6 ; 0.6 ; 57 ; 250 ; 2 ; 6 ; 252 ; 0.4 ; 54 ; 0.5", quantity, true);
	}
}


/*
	All essential stocks
*/

stock SetMiniBoss(boss, GMBossType:GBossType, health, String:name[], index, String:attributes[], quantity, bool:megaboss=false)
{
	new client;
	for (new miniboss=0; miniboss<quantity; miniboss++)
	{
		client = GetRandomDeadPlayer();
		if(client != -1)
		{
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)|FF2FLAG_ALLOWSPAWNINBOSSTEAM); // Spawn in Boss team
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)|FF2FLAG_ALLOW_AMMO_PICKUPS); // Ammo Pickup
			FF2_SetFF2flags(client,FF2_GetFF2flags(client)|~FF2FLAG_ALLOW_HEALTH_PICKUPS); // NO HP Pickups!
			
			ChangeClientTeam(client,FF2_GetBossTeam());
			TF2_RespawnPlayer(client);
			Special[client]=GBossType;
			SpecialIndex[client]=boss;
			
			switch(GBossType)
			{
				case GBossType_SuperScout, GBossType_FaNSuperScout, GBossType_JumpingSandmanScout, GBossType_MajorLeagueScout, GBossType_GiantBonkScout, GBossType_ArmoredGiantSandmanScout:
					TF2_SetPlayerClass(client, TFClass_Scout, _, false);
				case GBossType_GiantSoldier, GBossType_GiantBuffBannerSoldier, GBossType_GiantBattalionSoldier, GBossType_GiantConcherorSoldier, GBossType_GiantRapidFireSoldier, GBossType_GiantBurstFireSoldier, GBossType_GiantChargedSoldier, GBossType_GiantBlastSoldier, GBossType_ColonelBarrageSoldier, GBossType_GiantBlackBoxSoldier, GBossType_SergeantCrits, GBossType_MajorCrits, GBossType_ChiefBlastSoldier:
					TF2_SetPlayerClass(client, TFClass_Soldier, _, false);
				case GBossType_GiantPyro, GBossType_GiantFlarePyro:
					TF2_SetPlayerClass(client, TFClass_Pyro, _, false);
				case GBossType_GiantRapidFireDemo, GBossType_GiantBurstFireDemo, GBossType_GiantDemoKnight, GBossType_MajorBomber, GBossType_SirNukesalot, GBossType_SentryBuster:
					TF2_SetPlayerClass(client, TFClass_DemoMan, _, false);
				case GBossType_GiantHeavy, GBossType_GiantShotgunHeavy, GBossType_GiantDeflectorHeavy, GBossType_GiantHeaterHeavy, GBossType_CaptainPunch, GBossType_GiantHealOnKillHeavy:
					TF2_SetPlayerClass(client, TFClass_Heavy, _, false);
				case GBossType_GiantMedic:
					TF2_SetPlayerClass(client, TFClass_Medic, _, false);
			}
			
			TF2_RemoveAllWeapons(client);
			RemoveAllWearables();
			
			new String:classname[10], String:model[PLATFORM_MAX_PATH];
			TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
			Format(model, sizeof(model), TF2_GetPlayerClass(client)==TFClass_Medic ? "models/bots/%s/bot_%s.mdl" : "models/bots/%s_boss/bot_%s_boss.mdl", classname, classname);
			ReplaceString(model, sizeof(model), "demoman", "demo", false);
			PrecacheModel(Special[client]==GBossType_SentryBuster ? SentryBusterModel : model);
			SetVariantString(Special[client]==GBossType_SentryBuster ? SentryBusterModel : model);
			megaboss==true ? (IsMechaBoss[client]=true) : (IsMiniBoss[client]=true);
			
			new pCount=GetAlivePlayerCount(((FF2_GetBossTeam()==_:TFTeam_Blue) ? (_:TFTeam_Red) : (_:TFTeam_Blue)));
			health=(!megaboss ? (pCount>=12 ? health : pCount>=6 ? RoundFloat(float(health)/1.5) : RoundFloat(float(health)/2.0)) : (pCount>=12 ? health : pCount>=6 ? RoundFloat(float(health)/2.5) : RoundFloat(float(health)/4.0)));
			
			if(megaboss)
			{
				new String:bname[128], String:btype[512];
				switch(Special[client])
				{
					case GBossType_MajorCrits: bname="Major Crits";
					case GBossType_ChiefBlastSoldier: bname="Chief Blast Soldier";
					case GBossType_SergeantCrits: bname="Sergeant Crits";
					case GBossType_MajorBomber: bname="Major Bomber";
					case GBossType_SirNukesalot: bname="Sir Nukes-a-Lot";
					case GBossType_GiantHealOnKillHeavy: bname="Giant heal-on-kill Heavy";
					case GBossType_CaptainPunch: bname="Captain Punch";
				}
				Format(btype, sizeof(btype), "%N has become %s with %i HP!", client, bname, health);
				ShowTFMessage(btype);
			}
			TF2_AddCondition(client, TFCond_UberchargedHidden, 5.0);
			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
			
			new String:atts[1024];
			Format(atts, sizeof(atts), "26 ; %i ; %s", health, attributes);
			
			new wepEnt = SpawnWeapon(client, name, index, 100, 5, atts);
			
			switch(Special[client])
			{
				case GBossType_MajorCrits, GBossType_SergeantCrits, GBossType_MajorBomber, GBossType_SirNukesalot, GBossType_CaptainPunch: TF2_AddCondition(client, TFCond_CritCanteen, TFCondDuration_Infinite); // 100% Crits
				case GBossType_GiantBattalionSoldier, GBossType_GiantBuffBannerSoldier, GBossType_GiantConcherorSoldier: SpawnWeapon(client, "tf_weapon_rocketlauncher", 17, 100 , 5, "413 ; 1 ; 112 ; 2 ; 190 ; 40 ; 252 ; 0.4 ; 54 ; 0.5"), SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0); // Rocket Launcher & Full RAGE
				case GBossType_SentryBuster: EmitSoundToAll(SentryBusterTick, client), SetEntProp(wepEnt, Prop_Send, "m_iDetonated", 1); // No Surprise Kabooms pls
				case GBossType_GiantBonkScout: SpawnWeapon(client, "tf_weapon_bat", 0, 100 , 5, " 252 ; 0.7"); // Bat for melee
				case GBossType_GiantMedic: SpawnWeapon(client, "tf_weapon_syringegun_medic", 17, 100 , 5, "252 ; 0.6 ; 112 ; 2 ; 190 ; 40 ; 54 ; 0.5"), SetEntPropFloat(wepEnt, Prop_Send, "m_flChargeLevel", GetEntPropFloat(wepEnt, Prop_Send, "m_flChargeLevel")+1.00); // Type 2 with syringe gun 
			}

			SetEntityHealth(client, health);
			SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

stock ShowTFMessage(String:strMessage[]) 
{
    new iEntity = CreateEntityByName("game_text_tf");
    DispatchKeyValue(iEntity,"message", strMessage);
    DispatchKeyValue(iEntity,"display_to_team", "0");
    DispatchKeyValue(iEntity,"icon", "ico_notify_on_fire");
    DispatchKeyValue(iEntity,"targetname", "game_text1");
    DispatchKeyValue(iEntity,"background", "0");
    DispatchSpawn(iEntity);
    AcceptEntityInput(iEntity, "Display", iEntity, iEntity);
    CreateTimer(2.5, KillGameText, EntIndexToEntRef(iEntity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action:KillGameText(Handle:hTimer, any:iEntityRef) 
{
	new iEntity = EntRefToEntIndex(iEntityRef);
	if ((iEntity > 0) && IsValidEntity(iEntity))
		AcceptEntityInput(iEntity, "kill"); 
	return Plugin_Stop;
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(!FF2_IsFF2Enabled() || !IsRoundActive|| FF2_GetRoundState()!=1 || !IsValidEdict(attacker))
		return Plugin_Continue;
	
	if(!IsMiniBoss[client] || !IsMechaBoss[client] || FF2_GetBossIndex(client)>-1)
		return Plugin_Continue;
		
	if(IsMiniBoss[client]||IsMechaBoss[client])
	{
		if(damagetype & DMG_FALL)
		{
			return Plugin_Handled;
		}
		
		if(damagecustom==TF_CUSTOM_BACKSTAB && IsValidEntity(weapon) && weapon>MaxClients && attacker<=MaxClients)
		{
			new index=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			
			damage=(bkStabMode ? float(IsMiniBoss[client] ? bkstabDiv : bkstabDiv2) : float(GetClientHealth(client)/(IsMiniBoss[client] ? bkstabDiv : bkstabDiv2)));
			damagetype|=DMG_CRIT;
			damagecustom=0;
			
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+2.0);
			SetEntPropFloat(attacker, Prop_Send, "m_flNextAttack", GetGameTime()+2.0);
			SetEntPropFloat(attacker, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+2.0);

			new viewmodel=GetEntPropEnt(attacker, Prop_Send, "m_hViewModel");
			if(viewmodel>MaxClients && IsValidEntity(viewmodel) && TF2_GetPlayerClass(attacker)==TFClass_Spy)
			{
				new melee=GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Melee);
				new animation=15;
				switch(melee)
				{
					case 727:  //Black Rose
					{
						animation=41;
					}
					case 4, 194, 665, 794, 803, 883, 892, 901, 910:  //Knife, Strange Knife, Festive Knife, Botkiller Knifes
					{
						animation=10;
					}
					case 638:  //Sharp Dresser
					{
						animation=31;
					}
				}
				SetEntProp(viewmodel, Prop_Send, "m_nSequence", animation);
			}
			
			switch(index)
			{
				case 225, 574: RandomlyDisguise(client); // Eternal Reward, Wanga Prick
				case 356:  //Conniver's Kunai
				{
					new health=GetClientHealth(attacker)+200;
					if(health>500)
					{
						health=500;
					}
					SetEntProp(attacker, Prop_Data, "m_iHealth", health);
					SetEntProp(attacker, Prop_Send, "m_iHealth", health);
				}
				case 461: SetEntPropFloat(attacker, Prop_Send, "m_flCloakMeter", 100.0);  //Full cloak for Big Earner
			}
			
			if(GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary)==525)  //Diamondback
			{
				SetEntProp(attacker, Prop_Send, "m_iRevengeCrits", GetEntProp(attacker, Prop_Send, "m_iRevengeCrits")+2);
			}
			
			return Plugin_Changed;	
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

stock GetIndexOfWeaponSlot(client, slot)
{
	new weapon=GetPlayerWeaponSlot(client, slot);
	return (weapon>MaxClients && IsValidEntity(weapon) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1);
}

stock RandomlyDisguise(client)	// From FF2's built-in random disguise
{
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		new disguiseTarget=-1;
		new team=GetClientTeam(client);

		new Handle:disguiseArray=CreateArray();
		for(new clientcheck; clientcheck<=MaxClients; clientcheck++)
		{
			if(IsValidClient(clientcheck) && GetClientTeam(clientcheck)==team && clientcheck!=client)
			{
				PushArrayCell(disguiseArray, clientcheck);
			}
		}

		if(GetArraySize(disguiseArray)<=0)
		{
			disguiseTarget=client;
		}
		else
		{
			disguiseTarget=GetArrayCell(disguiseArray, GetRandomInt(0, GetArraySize(disguiseArray)-1));
			if(!IsValidClient(disguiseTarget))
			{
				disguiseTarget=client;
			}
		}

		new class=GetRandomInt(0, 4);
		new TFClassType:classArray[]={TFClass_Scout, TFClass_Pyro, TFClass_Medic, TFClass_Engineer, TFClass_Sniper};
		CloseHandle(disguiseArray);

		if(TF2_GetPlayerClass(client)==TFClass_Spy)
		{
			TF2_DisguisePlayer(client, TFTeam:team, classArray[class], disguiseTarget);
		}
		else
		{
			TF2_AddCondition(client, TFCond_Disguised, -1.0);
			SetEntProp(client, Prop_Send, "m_nDisguiseTeam", team);
			SetEntProp(client, Prop_Send, "m_nDisguiseClass", classArray[class]);
			SetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex", disguiseTarget);
			SetEntProp(client, Prop_Send, "m_iDisguiseHealth", 200);
		}
	}
}

public Action:SoundHook(clients[64], &numClients, String:vl[PLATFORM_MAX_PATH], &Ent, &channel, &Float:volume, &level, &pitch, &flags)
{
	new client = Ent;
	if(client <=  MAXPLAYERS && client > 0)
	{
		if (StrContains(vl, "announcer")!=-1) return Plugin_Continue;
		if (StrContains(vl, "norm")!=-1) return Plugin_Continue;
		if (StrContains(vl, "mght")!=-1) return Plugin_Continue;
		if (StrContains(vl, "vo/", false)==-1) return Plugin_Continue;
	
		if(Special[client]==GBossType_GrayMann)
		{
			decl String:taunt[PLATFORM_MAX_PATH];
			new boss=FF2_GetBossIndex(client);
			if(StrContains(vl, "engineer_laughlong01", false)!=-1 && boss>=0)
			{
				if(FF2_RandomSound("sound_graymann_wrenchtaunt", taunt, sizeof(taunt), boss))
				{
					strcopy(vl, PLATFORM_MAX_PATH, taunt);
					return Plugin_Changed;
				}
				return Plugin_Stop;
			}
			else if(StrContains(vl, "engineer_laughlong02", false)!=-1 && boss>=0)
			{
				if(FF2_RandomSound("sound_graymann_schadenfreude", taunt, sizeof(taunt), boss))
				{
					strcopy(vl, PLATFORM_MAX_PATH, taunt);
					return Plugin_Changed;
				}
				return Plugin_Stop;
			}
			else if((StrContains(vl, "engineer_laugh", false)!=-1 || StrContains(vl, "engineer_domination", false)!=-1) && boss>=0)
			{
				if(FF2_RandomSound("sound_graymann_laugh", taunt, sizeof(taunt), boss))
				{
					strcopy(vl, PLATFORM_MAX_PATH, taunt);
					return Plugin_Changed;
				}
				return Plugin_Stop;
			}
			return Plugin_Stop;
		}

		if((IsMiniBoss[client] || IsMechaBoss[client]) && !TF2_IsPlayerInCondition(client, TFCond_Disguised)) // Robot voice lines & footsteps
		{
			if (StrContains(vl, "player/footsteps/", false) != -1)
			{	
				if(TF2_GetPlayerClass(client) == TFClass_Medic)
					return Plugin_Stop;
				Format(vl, sizeof(vl), "mvm/giant_common/giant_common_step_0%i.wav", GetRandomInt(1,8));
				pitch = GetRandomInt(95, 100);
				EmitSoundToAll(vl, client, _, _, _, 0.25, pitch);
				return Plugin_Changed;
			}
			
			if(Special[client]>GBossType_GrayMann && Special[client]!=GBossType_SentryBuster)
			{
				if (volume == 0.99997) return Plugin_Continue;
				ReplaceString(vl, sizeof(vl), "vo/", TF2_GetPlayerClass(client) == TFClass_Medic ? "vo/mvm/norm/" : "vo/mvm/mght/", false);
				new String:classname[10], String:classname_mvm[20];
				TF2_GetNameOfClass(TF2_GetPlayerClass(client), classname, sizeof(classname));
				Format(classname_mvm, sizeof(classname_mvm), TF2_GetPlayerClass(client) == TFClass_Medic ? "%s_mvm" : "%s_mvm_m", classname);
				ReplaceString(vl, sizeof(vl), classname, classname_mvm, false);
				new String:gSnd[PLATFORM_MAX_PATH];
				Format(gSnd, sizeof(gSnd), "sound/%s", vl);
				PrecacheSound(vl);
				return Plugin_Changed;
			}
			
			if(Special[client]==GBossType_SentryBuster) // Block voice lines.
			{
				if (StrContains(vl, "demo", false) != -1) 
					return Plugin_Stop;
			}
			return Plugin_Continue;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action:SentryBusting(Handle:timer, any:client)
{
	if (!IsValidClient(client)) return Plugin_Handled;
	if (!IsPlayerAlive(client)) return Plugin_Handled;
	new explosion = CreateEntityByName("env_explosion");
	new Float:clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	if (explosion)
	{
		DispatchSpawn(explosion);
		TeleportEntity(explosion, clientPos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(explosion, "Explode", -1, -1, 0);
		RemoveEdict(explosion);
	}
	for (new i = 1; i <= MaxClients; i++)
	{
		if(!IsValidClient(i) || !IsPlayerAlive(i)) continue;
		new Float:zPos[3];
		GetClientAbsOrigin(i, zPos);
		new Float:Dist = GetVectorDistance(clientPos, zPos);
		if (Dist > 300.0) continue;
		DoDamage(client, i, 2500);
	}
	for (new i = MaxClients + 1; i <= 2048; i++)
	{
		if (!IsValidEntity(i)) continue;
		decl String:cls[20];
		GetEntityClassname(i, cls, sizeof(cls));
		if (!StrEqual(cls, "obj_sentrygun", false) &&
		!StrEqual(cls, "obj_dispenser", false) &&
		!StrEqual(cls, "obj_teleporter", false)) continue;
		new Float:zPos[3];
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", zPos);
		new Float:Dist = GetVectorDistance(clientPos, zPos);
		if (Dist > 300.0) continue;
		SetVariantInt(2500);
		AcceptEntityInput(i, "RemoveHealth");
	}
	EmitSoundToAll(SentryBusterExplode, client);
	AttachParticle(client, "fluidSmokeExpl_ring_mvm");
	DoDamage(client, client, 2500);
	CreateTimer(0.0, Timer_RemoveRagdoll, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action:Timer_RemoveRagdoll(Handle:timer, any:uid)
{
	new client = GetClientOfUserId(uid);
	if (!IsValidClient(client)) return;
	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (!IsValidEntity(ragdoll) || ragdoll <= MaxClients) return;
	AcceptEntityInput(ragdoll, "Kill");
}

stock DoDamage(client, target, amount) // from Goomba Stomp.
{
	new pointHurt = CreateEntityByName("point_hurt");
	if (pointHurt)
	{
		DispatchKeyValue(target, "targetname", "explodeme");
		DispatchKeyValue(pointHurt, "DamageTarget", "explodeme");
		new String:dmg[15];
		Format(dmg, 15, "%i", amount);
		DispatchKeyValue(pointHurt, "Damage", dmg);
		DispatchKeyValue(pointHurt, "DamageType", "0");

		DispatchSpawn(pointHurt);
		AcceptEntityInput(pointHurt, "Hurt", client);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(target, "targetname", "");
		RemoveEdict(pointHurt);
	}
}

stock bool:AttachParticle(Ent, String:particleType[], bool:cache=false) // from L4D Achievement Trophy
{
	new particle = CreateEntityByName("info_particle_system");
	if (!IsValidEdict(particle)) return false;
	new String:tName[128];
	new Float:f_pos[3];
	if (cache) f_pos[2] -= 3000;
	else
	{
		GetEntPropVector(Ent, Prop_Send, "m_vecOrigin", f_pos);
		f_pos[2] += 60;
	}
	TeleportEntity(particle, f_pos, NULL_VECTOR, NULL_VECTOR);
	Format(tName, sizeof(tName), "target%i", Ent);
	DispatchKeyValue(Ent, "targetname", tName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(tName);
	AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(10.0, DeleteParticle, particle);
	return true;
}

public Action:DeleteParticle(Handle:timer, any:Ent)
{
	if (!IsValidEntity(Ent)) return;
	new String:cls[25];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "info_particle_system", false)) AcceptEntityInput(Ent, "Kill");
	return;
}

public RemoveAllWearables()
{
	new entity, owner;
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

stock GetRandomDeadPlayer()
{
	new clients[MaxClients+1], clientCount;
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsValidEdict(i) && IsValidClient(i) && !IsPlayerAlive(i) && !IsValidBoss(i) && (GetClientTeam(i) > 1))
		{
			clients[clientCount++] = i;
		}
	}
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}

stock TF2_GetNameOfClass(TFClassType:class, String:name[], maxlen)
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

stock SpawnWeapon(client,String:name[],index,level,qual,String:att[])
{
	new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	new String:atts[32][32];
	new count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		new i2 = 0;
		for (new i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==null)
		return -1;
	new entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock SetAmmo(client, slot, ammo)
{
	new weapon = GetPlayerWeaponSlot(client, slot);
	if (IsValidEntity(weapon))
	{
		new iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(client, iAmmoTable+iOffset, ammo, 4, true);
	}
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client) || !IsClientConnected(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

stock bool:IsValidBoss(client)
{
	if (FF2_GetBossIndex(client) == -1) return false;
	return true;
}

stock bool:IsValidMinion(client)
{
	if (GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	if (FF2_GetBossIndex(client) >= 0) return false;
	if (SpecialIndex[client] == -1) return false;
	return true;
}

stock FF2_PrintGlobalText(String:text[])
{
	CPrintToChatAll("{olive}[FF2]{default} %s", text);
}

stock FF2_PrintClientText(client, String:text[])
{
	CPrintToChat(client, "{olive}[FF2]{default} %s", text);
}

stock GetClassCount(classtype, teamnum)
{
	ClassCount=0;
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsPlayerAlive(client) && TF2_GetPlayerClass(client) == TFClassType:classtype && GetClientTeam(client) == teamnum)
		{
			ClassCount++;
			Debug("Class Count for class %i, team %i: %i", classtype, teamnum, ClassCount);
		}
	}
	return ClassCount;
}

stock GetAlivePlayerCount(team)
{
	AlivePlayerCount=0;
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == team)
		{
			AlivePlayerCount++;
			Debug("Alive Player Count for Team %i: %i", team, AlivePlayerCount);
		}
	}
	return AlivePlayerCount;
}