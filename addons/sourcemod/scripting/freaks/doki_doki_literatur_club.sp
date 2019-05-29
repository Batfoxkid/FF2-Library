#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <ff2_ams>
#include <ff2_dynamic_defaults>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define INACTIVE 100000000.0

// There you are! (Stun + Overlay)
#define STUNOVERLAY "there_you_are"
#define STUNOVERLAYALIAS "TYA"
new bool:ThereYouAre_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

// Data Mining (Speedchange + Disguise)
#define DATAMINING "data_mining"
#define DATAMININGALIAS "DAMI"
new Float:NewSpeedData[MAXPLAYERS+1];
new Float:NewSpeedDurationData[MAXPLAYERS+1];
new bool:DataMining_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS

// Data corruption (Lag + Drug + sound + Speedchange)
#define CORRUPTION "data_corruption"
#define CORRUPTIONALIAS "DACO"
new Float:NewSpeedCorruption[MAXPLAYERS+1];
new Float:NewSpeedDurationCorruption[MAXPLAYERS+1];
new bool:Corruption_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
new Float:CorruptionUnscramble=INACTIVE;
new bool:Corruptionscramble[MAXPLAYERS+1]=false;
new Float:g_DrugAngles[56] = {0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0, 27.0, 30.0, 33.0, 36.0, 39.0, 42.0, 39.0, 36.0, 33.0, 30.0, 27.0, 24.0, 21.0, 18.0, 15.0, 12.0, 9.0, 6.0, 3.0, 0.0, -3.0, -6.0, -9.0, -12.0, -15.0, -18.0, -21.0, -24.0, -27.0, -30.0, -33.0, -36.0, -39.0, -42.0, -39.0, -36.0, -33.0, -30.0, -27.0, -24.0, -21.0, -18.0, -15.0, -12.0, -9.0, -6.0, -3.0 };
new Handle:specialDrugTimers[MAXPLAYERS+1];
new fov_offset;
new zoom_offset;
new gLaser1;
new gHalo1;
#define FFADE_OUT	0x0002        // Fade out

// Class Reaction Lines
static const String:ScoutReact[][] = {
	"vo/scout_sf13_magic_reac03.mp3",
	"vo/scout_sf13_magic_reac07.mp3",
	"vo/scout_sf12_badmagic04.mp3"
};

static const String:SoldierReact[][] = {
	"vo/soldier_sf13_magic_reac03.mp3",
	"vo/soldier_sf12_badmagic07.mp3",
	"vo/soldier_sf12_badmagic13.mp3"
};

static const String:PyroReact[][] = {
	"vo/pyro_autodejectedtie01.mp3",
	"vo/pyro_painsevere02.mp3",
	"vo/pyro_painsevere04.mp3"
};

static const String:DemoReact[][] = {
	"vo/demoman_sf13_magic_reac05.mp3",
	"vo/demoman_sf13_bosses02.mp3",
	"vo/demoman_sf13_bosses03.mp3",
	"vo/demoman_sf13_bosses04.mp3",
	"vo/demoman_sf13_bosses05.mp3",
	"vo/demoman_sf13_bosses06.mp3"
};

static const String:HeavyReact[][] = {
	"vo/heavy_sf13_magic_reac01.mp3",
	"vo/heavy_sf13_magic_reac03.mp3",
	"vo/heavy_cartgoingbackoffense02.mp3",
	"vo/heavy_negativevocalization02.mp3",
	"vo/heavy_negativevocalization06.mp3"
};

static const String:EngyReact[][] = {
	"vo/engineer_sf13_magic_reac01.mp3",
	"vo/engineer_sf13_magic_reac02.mp3",
	"vo/engineer_specialcompleted04.mp3",
	"vo/engineer_painsevere05.mp3",
	"vo/engineer_negativevocalization12.mp3"
};

static const String:MedicReact[][] = {
	"vo/medic_sf13_magic_reac01.mp3",
	"vo/medic_sf13_magic_reac02.mp3",
	"vo/medic_sf13_magic_reac03.mp3",
	"vo/medic_sf13_magic_reac04.mp3",
	"vo/medic_sf13_magic_reac07.mp3"
};

static const String:SniperReact[][] = {
	"vo/sniper_sf13_magic_reac01.mp3",
	"vo/sniper_sf13_magic_reac02.mp3",
	"vo/sniper_sf13_magic_reac04.mp3"
};

static const String:SpyReact[][] = {
	"vo/Spy_sf13_magic_reac01.mp3",
	"vo/Spy_sf13_magic_reac02.mp3",
	"vo/Spy_sf13_magic_reac03.mp3",
	"vo/Spy_sf13_magic_reac04.mp3",
	"vo/Spy_sf13_magic_reac05.mp3",
	"vo/Spy_sf13_magic_reac06.mp3"
};

#define MULTIKILLOVERLAY "special_multi_killoverlay"

public Plugin:myinfo = {
	name	= "FF2: Abilities for Monika",
	author	= "M7",
	version = "1.0",
};

public OnPluginStart2()
{
	HookEvent("arena_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", event_round_end, EventHookMode_PostNoCopy);
	
	HookEvent("player_death", event_player_death);
	
	fov_offset = FindSendPropOffs("CBasePlayer", "m_iFOV");
	zoom_offset = FindSendPropOffs("CBasePlayer", "m_iDefaultFOV");
}

public OnMapStart()
{
	gLaser1 = PrecacheModel("materials/sprites/laser.vmt");
	gHalo1 = PrecacheModel("materials/sprites/halo01.vmt");
	PrecacheSound("ambient/halloween/mysterious_perc_01.wav",true);
	
	// Class Voice Reaction Lines
	for (new i = 0; i < sizeof(ScoutReact); i++)
	{
		PrecacheSound(ScoutReact[i], true);
	}
	for (new i = 0; i < sizeof(SoldierReact); i++)
	{
		PrecacheSound(SoldierReact[i], true);
	}
	for (new i = 0; i < sizeof(PyroReact); i++)
	{
		PrecacheSound(PyroReact[i], true);
	}
	for (new i = 0; i < sizeof(DemoReact); i++)
	{
		PrecacheSound(DemoReact[i], true);
	}
	for (new i = 0; i < sizeof(HeavyReact); i++)
	{
		PrecacheSound(HeavyReact[i], true);
	}
	for (new i = 0; i < sizeof(EngyReact); i++)
	{
		PrecacheSound(EngyReact[i], true);
	}
	for (new i = 0; i < sizeof(MedicReact); i++)
	{
		PrecacheSound(MedicReact[i], true);
	}
	for (new i = 0; i < sizeof(SniperReact); i++)
	{
		PrecacheSound(SniperReact[i], true);
	}
	for (new i = 0; i < sizeof(SpyReact); i++)
	{
		PrecacheSound(SpyReact[i], true);
	}
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			ThereYouAre_TriggerAMS[client]=false;
			DataMining_TriggerAMS[client]=false;
			Corruption_TriggerAMS[client]=false;
			
			NewSpeedData[client]=NewSpeedCorruption[client]=0.0;
			NewSpeedDurationData[client]=NewSpeedDurationCorruption[client]=INACTIVE;
			
			CorruptionUnscramble=INACTIVE;
			Corruptionscramble[client]=false;
			
			new boss=FF2_GetBossIndex(client);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, this_plugin_name, STUNOVERLAY))
				{
					ThereYouAre_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, STUNOVERLAY);
					if(ThereYouAre_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, STUNOVERLAY, STUNOVERLAYALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, DATAMINING))
				{
					DataMining_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, DATAMINING);
					if(DataMining_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, DATAMINING, DATAMININGALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, CORRUPTION))
				{
					Corruption_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, CORRUPTION);
					if(Corruption_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, CORRUPTION, CORRUPTIONALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
			}
		}
	}
}

public PlayerSpawnEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	SetEntData(client, fov_offset, 90, 4, true);
	SetEntData(client, zoom_offset, 90, 4, true);
	ClientCommand(client, "r_screenoverlay 0");
}

public Action:event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			ThereYouAre_TriggerAMS[client]=false;
			DataMining_TriggerAMS[client]=false;
			Corruption_TriggerAMS[client]=false;
			
			NewSpeedData[client]=NewSpeedCorruption[client]=0.0;
			NewSpeedDurationData[client]=NewSpeedDurationCorruption[client]=INACTIVE;
			
			CorruptionUnscramble=INACTIVE;
			Corruptionscramble[client]=false;
			
			SDKUnhook(client, SDKHook_PreThink, DataMining_Prethink);
			SDKUnhook(client, SDKHook_PreThink, Corruption_Prethink);
			SDKUnhook(client, SDKHook_PreThink, Corruption2_Prethink);
		}
	}
	CreateTimer(0.1, EndCorruption);
}

public Action:event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new boss=FF2_GetBossIndex(attacker); // Boss is an attacker
	if(boss>=0)
	{
		new String:overlay[PLATFORM_MAX_PATH];
		new String:buffer[PLATFORM_MAX_PATH];
	
		new number=FF2_GetAbilityArgument(boss, this_plugin_name, MULTIKILLOVERLAY, 1);
		new random=2*GetRandomInt(1, number); // Only even numbers
		FF2_GetAbilityArgumentString(boss, this_plugin_name, MULTIKILLOVERLAY, random , buffer, sizeof(buffer));
	
		Format(overlay, sizeof(overlay), "r_screenoverlay \"%s\"", buffer);
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
		if(IsValidClient(client) && GetClientTeam(client)!=FF2_GetBossTeam())
		{
			ClientCommand(client, overlay);
		}

		CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, MULTIKILLOVERLAY, random+1, 6.0), remove_overlay, _, TIMER_FLAG_NO_MAPCHANGE);
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
	}
	return Plugin_Continue;
}

public Action:remove_overlay(Handle:timer)
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			ClientCommand(target, "r_screenoverlay \"\"");
		}
	}
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
	return Plugin_Continue;
}

public Action:FF2_OnAbility2(boss, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!strcmp(ability_name,STUNOVERLAY))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			ThereYouAre_TriggerAMS[client]=false;
		}
		
		if(!ThereYouAre_TriggerAMS[client])
			TYA_Invoke(client);
	}
	else if(!strcmp(ability_name,DATAMINING))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			DataMining_TriggerAMS[client]=false;
		}
		
		if(!DataMining_TriggerAMS[client])
			DAMI_Invoke(client);
	}
	else if(!strcmp(ability_name,CORRUPTION))	// Defenses
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			Corruption_TriggerAMS[client]=false;
		}
		
		if(!Corruption_TriggerAMS[client])
			DACO_Invoke(client);
	}
	
	return Plugin_Continue;
}


public bool:TYA_CanInvoke(client)
{
	return true;
}

public TYA_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	new Float:bossPosition[3], Float:targetPosition[3], Float:sentryPosition[3];
	new String:TYA_overlay[PLATFORM_MAX_PATH];
	new String:TYA_buffer[PLATFORM_MAX_PATH];
	
	new Float:TYA_Stunduration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STUNOVERLAY, 1, 5.0);
	new Float:TYA_Stundistance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STUNOVERLAY, 2, FF2_GetRageDist(boss, this_plugin_name, STUNOVERLAY));
	new Float:TYA_Sentryduration=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STUNOVERLAY, 3, 7.0);
	new Float:TYA_Sentrydistance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STUNOVERLAY, 4, FF2_GetRageDist(boss, this_plugin_name, STUNOVERLAY));
	new bool:TeleportOnTop = bool:FF2_GetAbilityArgument(boss, this_plugin_name, STUNOVERLAY, 5);
	new bool:TeleportAtSide = bool:FF2_GetAbilityArgument(boss, this_plugin_name, STUNOVERLAY, 6);
	new Float:SelfStunDuration = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STUNOVERLAY, 7);
	new numberofoverlays=FF2_GetAbilityArgument(boss, this_plugin_name, STUNOVERLAY, 8, -1);
	
	if(ThereYouAre_TriggerAMS[client])
	{
		new String:snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_there_you_are", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
	
	DD_PerformTeleport(client, SelfStunDuration, TeleportOnTop, TeleportAtSide, false, false);
	
	new random=2*GetRandomInt(1, numberofoverlays); // Only even numbers
	FF2_GetAbilityArgumentString(boss, this_plugin_name, STUNOVERLAY, random, TYA_buffer, sizeof(TYA_buffer));
	
	Format(TYA_overlay, sizeof(TYA_overlay), "r_screenoverlay \"%s\"", TYA_buffer);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", bossPosition);
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			if(!TF2_IsPlayerInCondition(target, TFCond_Ubercharged) && (GetVectorDistance(bossPosition, targetPosition)<=TYA_Stundistance))
			{
				TF2_StunPlayer(target, TYA_Stunduration, 0.0, TF_STUNFLAGS_GHOSTSCARE, client);
				CreateTimer(TYA_Stunduration, Timer_RemoveEntity, EntIndexToEntRef(AttachParticle(target, "yikes_fx", 75.0)), TIMER_FLAG_NO_MAPCHANGE);
			}
			ClientCommand(target, TYA_overlay);
		}
	}
	CreateTimer(FF2_GetAbilityArgumentFloat(boss, this_plugin_name, STUNOVERLAY, random+1, 6.0), timer_no_monika, _, TIMER_FLAG_NO_MAPCHANGE);
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
	
	new sentry;
	while((sentry=FindEntityByClassname(sentry, "obj_sentrygun"))!=-1)
	{
		GetEntPropVector(sentry, Prop_Send, "m_vecOrigin", sentryPosition);
		if(GetVectorDistance(bossPosition, sentryPosition)<=TYA_Sentrydistance)
		{
			SetEntProp(sentry, Prop_Send, "m_bDisabled", 1);
			CreateTimer(TYA_Sentryduration, Timer_RemoveEntity, EntIndexToEntRef(AttachParticle(sentry, "yikes_fx", 75.0)), TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(TYA_Sentryduration, Timer_EnableSentry, EntIndexToEntRef(sentry), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:timer_no_monika(Handle:timer)
{
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & ~FCVAR_CHEAT);
	for(new target=1; target<=MaxClients; target++)
	{
		if(IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
		{
			ClientCommand(target, "r_screenoverlay \"\"");
		}
	}
	SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & FCVAR_CHEAT);
	return Plugin_Continue;
}


public bool:DAMI_CanInvoke(client)
{
	return true;
}

public DAMI_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	
	decl String:MiningSpeed[10], String:MiningDuration[10]; // Foolproof way so that args always return floats instead of ints
	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, DATAMINING, 1, MiningSpeed, sizeof(MiningSpeed));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, DATAMINING, 2, MiningDuration, sizeof(MiningDuration));
	
	if(DataMining_TriggerAMS[client])
	{
		new String:snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_data_mining_start", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
	
	if(IsValidClient(client, true))
	{
		TF2_DisguisePlayer(client, (FF2_GetBossTeam()==view_as<int>(TFTeam_Blue)) ? (TFTeam_Red) : (TFTeam_Blue), view_as<TFClassType>(GetRandomInt(1,9)));
	}
	
	if(MiningSpeed[0]!='\0' || MiningDuration[0]!='\0')
	{
		if(MiningSpeed[0]!='\0')
		{
			NewSpeedData[client]=StringToFloat(MiningSpeed); // Boss Move Speed
		}
		if(MiningDuration[0]!='\0')
		{
			NewSpeedDurationData[client]=GetEngineTime()+StringToFloat(MiningDuration); // Boss Move Speed Duration
		}
		SDKHook(client, SDKHook_PreThink, DataMining_Prethink);
	}
	
	new Float:dist2=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, DATAMINING, 3);
	if(dist2)
	{
		if(dist2==-1)
		{
			dist2=FF2_GetRageDist(boss, this_plugin_name, DATAMINING);
		}
		
		FF2_GetAbilityArgumentString(boss, this_plugin_name, DATAMINING, 4, MiningSpeed, sizeof(MiningSpeed));
		FF2_GetAbilityArgumentString(boss, this_plugin_name, DATAMINING, 5, MiningDuration, sizeof(MiningDuration));
		
		new Float:pos[3], Float:pos2[3], Float:dist;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		for(new target=1;target<=MaxClients;target++)
		{
			if(!IsValidClient(target))
				continue;
		
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance( pos, pos2 );
			if (dist<dist2 && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
			{
				SDKHook(target, SDKHook_PreThink, DataMining_Prethink);
				NewSpeedData[target]=StringToFloat(MiningSpeed); // Victim Move Speed
				NewSpeedDurationData[target]=GetEngineTime()+StringToFloat(MiningDuration); // Victim Move Speed Duration
			}
		}
	}
}

public DataMining_Prethink(client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", NewSpeedData[client]);
	Datamining(client, GetEngineTime());
}

public Datamining(client, Float:gameTime)
{
	// Move Speed
	if(gameTime>=NewSpeedDurationData[client])
	{
		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			new String:snd[PLATFORM_MAX_PATH];
			if(FF2_RandomSound("sound_data_mining_finish", snd, sizeof(snd), boss))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
	
		NewSpeedData[client]=0.0;
		NewSpeedDurationData[client]=INACTIVE;
		SDKUnhook(client, SDKHook_PreThink, DataMining_Prethink);
	}
}


public bool:DACO_CanInvoke(client)
{
	return true;
}

public DACO_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	
	decl String:CorruptionSpeed[10], String:CorruptionDuration[10]; // Foolproof way so that args always return floats instead of ints
	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, CORRUPTION, 1, CorruptionSpeed, sizeof(CorruptionSpeed));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, CORRUPTION, 2, CorruptionDuration, sizeof(CorruptionDuration));
	new bool:reactionvoicelines = bool:FF2_GetAbilityArgument(boss, this_plugin_name, CORRUPTION, 5);
	
	if(CorruptionSpeed[0]!='\0' || CorruptionDuration[0]!='\0')
	{
		if(CorruptionSpeed[0]!='\0')
		{
			NewSpeedCorruption[client]=StringToFloat(CorruptionSpeed); // Boss Move Speed
		}
		if(CorruptionDuration[0]!='\0')
		{
			NewSpeedDurationCorruption[client]=GetEngineTime()+StringToFloat(CorruptionDuration); // Boss Move Speed Duration
		}
		SDKHook(client, SDKHook_PreThink, Corruption_Prethink);
	}
	
	new Float:pos[3], Float:pos2[3], Float:dist;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	new Float:dist2=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, CORRUPTION, 3);
	if(dist2)
	{
		if(dist2==-1)
		{
			dist2=FF2_GetRageDist(boss, this_plugin_name, CORRUPTION);
		}
		
		for(new target=1;target<=MaxClients;target++)
		{
			if(!IsValidClient(target))
				continue;
				
			if(reactionvoicelines)
				Responses(target);
		
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", pos2);
			dist=GetVectorDistance( pos, pos2 );
			if (dist<dist2 && IsPlayerAlive(target) && GetClientTeam(target)!=FF2_GetBossTeam())
			{
				SetVariantInt(0);
				AcceptEntityInput(target, "SetForcedTauntCam");
				Corruption_Create(target);
				Corruptionscramble[target]=true;
				CorruptionUnscramble=GetEngineTime()+FF2_GetAbilityArgumentFloat(boss, this_plugin_name, CORRUPTION, 4);
				SDKHook(target, SDKHook_PreThink, Corruption2_Prethink);
			}
		}
	}
		
	new Float:vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;
			
	TE_SetupBeamRingPoint(vec, 10.0, dist2/2, gLaser1, gHalo1, 0, 15, 0.5, 10.0, 0.0, { 128, 128, 128, 255 }, 10, 0);
	TE_SendToAll();
	TE_SetupBeamRingPoint(vec, 10.0, dist2/2, gLaser1, gHalo1, 0, 10, 0.6, 20.0, 0.5, { 75, 75, 255, 255 }, 10, 0);
	TE_SendToAll();
	TE_SetupBeamRingPoint(vec, 0.0, dist2, gLaser1, gHalo1, 0, 0, 0.5, 100.0, 5.0, {255, 255, 255, 255}, 0, 0);
	TE_SendToAll();
	TE_SetupBeamRingPoint(vec, 0.0, dist2, gLaser1, gHalo1, 0, 0, 5.0, 100.0, 5.0, {64, 64, 128, 255}, 0, 0);
	TE_SendToAll();
	TE_SetupBeamRingPoint(vec, 0.0, dist2, gLaser1, gHalo1, 0, 0, 2.5, 100.0, 5.0, {32, 32, 64, 255}, 0, 0);
	TE_SendToAll();
	TE_SetupBeamRingPoint(vec, 0.0, dist2, gLaser1, gHalo1, 0, 0, 6.0, 100.0, 5.0, {16, 16, 32, 255}, 0, 0);
	TE_SendToAll();
	
	if(DataMining_TriggerAMS[client])
	{
		new String:snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_date_corruption_effect", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}
		
		if(FF2_RandomSound("sound_data_corruption_voice", snd, PLATFORM_MAX_PATH, boss))
		{
			EmitSoundToAll(snd, client, _, _, _, _, _, client, pos);
			EmitSoundToAll(snd, client, _, _, _, _, _, client, pos);

			for(new victim=1; victim<=MaxClients; victim++)
			{
				if(IsClientInGame(victim) && victim!=client)
				{
					EmitSoundToClient(victim, snd, client, _, _, _, _, _, client, pos);
					EmitSoundToClient(victim, snd, client, _, _, _, _, _, client, pos);
				}
			}
		}
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:velocity[3], Float:angles[3], &weapon)
{
	new boss=FF2_GetBossIndex(client);
	if(boss==-1)
	{
		return Plugin_Continue;
	}

	// Keyboard scramble 
	if(IsValidClient(client, true) && Corruptionscramble[client]) // Only affect raged players...
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

public Corruption_Prethink(client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", NewSpeedData[client]);
	DataCorruption(client, GetEngineTime());
}
public DataCorruption(client, Float:gameTime)
{
	// Move Speed
	if(gameTime>=NewSpeedDurationCorruption[client])
	{
		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			new String:snd[PLATFORM_MAX_PATH];
			if(FF2_RandomSound("sound_date_corruption_finish", snd, sizeof(snd), boss))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
	
		NewSpeedCorruption[client]=0.0;
		NewSpeedDurationCorruption[client]=INACTIVE;
		SDKUnhook(client, SDKHook_PreThink, Corruption_Prethink);
	}
}
public Corruption2_Prethink(client)
{
	Datacorrupted(client, GetEngineTime());
}

public Datacorrupted(client, Float:gameTime)
{
	if(gameTime>=CorruptionUnscramble)
	{
		for(new i = 1; i <= MaxClients; i++ )
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				Corruption_Kill(i);
				Corruptionscramble[i]=false;
				CorruptionUnscramble=INACTIVE;
				SDKUnhook(i, SDKHook_PreThink, Corruption2_Prethink);
			}
		}
	}
}
public Action:EndCorruption(Handle:timer)
{
	for(new i = 1; i <= MaxClients; i++ )
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			Corruption_Kill(i);
			SDKUnhook(i, SDKHook_PreThink, Corruption2_Prethink);
		}
	}
	return Plugin_Stop;
}

/* 
* Create colorfull drug on client
*/
stock Corruption_Create(client)
{
	specialDrugTimers[ client ] = CreateTimer(0.1, Corruption_Timer, client, TIMER_REPEAT);	
}

/* 
* Kill drug on selected client
*/
stock Corruption_Kill(client)
{
	if ( IsClientInGame( client ) && IsClientConnected( client ) )
	{
		specialDrugTimers[ client ] = INVALID_HANDLE;	
		
		new Float:angs[3];
		GetClientEyeAngles(client, angs);
			
		angs[2] = 0.0;
			
		TeleportEntity(client, NULL_VECTOR, angs, NULL_VECTOR);	
		
		ClientCommand(client, "r_screenoverlay 0");
		
		SetEntData(client, fov_offset, 90, 4, true);
		SetEntData(client, zoom_offset, 90, 4, true);
	}
}

/*
* Run drug timer
*/
public Action:Corruption_Timer(Handle:timer, any:client)
{
	static Repeat = 0;
	
	if ( !IsClientInGame( client ) )
	{
		Corruption_Kill( client );
		return Plugin_Stop;
	}
	
	if ( !IsPlayerAlive( client ) )
	{
		Corruption_Kill( client );
		return Plugin_Stop;
	}
	
	if( specialDrugTimers[ client ] == INVALID_HANDLE )
	{
		Corruption_Kill( client );
		return Plugin_Stop;
	}
	
	SetVariantInt(0);
	AcceptEntityInput(client, "SetForcedTauntCam");
	
	new Float:angs[3];
	GetClientEyeAngles(client, angs);

	angs[2] = g_DrugAngles[Repeat % 56];
	angs[1] = g_DrugAngles[(Repeat+14) % 56];
	angs[0] = g_DrugAngles[(Repeat+21) % 56];

	TeleportEntity(client, NULL_VECTOR, angs, NULL_VECTOR);
	
	SetEntData(client, fov_offset, 160, 4, true);
	SetEntData(client, zoom_offset, 160, 4, true);
	
	if (Repeat == 0) {
		EmitSoundToClient(client, "ambient/halloween/mysterious_perc_01.wav");
	} else if ((Repeat%15) == 0) {
		EmitSoundToClient(client, "ambient/halloween/mysterious_perc_01.wav");
	}
	
	ClientCommand(client, "r_screenoverlay effects/tp_eyefx/tpeye.vmt"); // rainbow flashes
	
	Repeat++;
	
	new clients[2];
	clients[0] = client;	
	
	sendfademsg(client, 255, 255, FFADE_OUT, GetRandomInt(0,255), GetRandomInt(0,255), GetRandomInt(0,255), 150);
	
	return Plugin_Handled;

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

stock sendfademsg(client, duration, holdtime, fadeflag, r, g, b, a)
{
	new Handle:fademsg;
	
	if (client == 0)
		fademsg = StartMessageAll("Fade");
	else
		fademsg = StartMessageOne("Fade", client);
	
	BfWriteShort(fademsg, duration);
	BfWriteShort(fademsg, holdtime);
	BfWriteShort(fademsg, fadeflag);
	BfWriteByte(fademsg, r);
	BfWriteByte(fademsg, g);
	BfWriteByte(fademsg, b);
	BfWriteByte(fademsg, a);
	EndMessage();
}

stock Responses(client) // Simple Class responses
{
	if(IsValidClient(client, true) && GetClientTeam(client)!=FF2_GetBossTeam())
	{
		new String:Reaction[PLATFORM_MAX_PATH];
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: // Scout
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, ScoutReact[GetRandomInt(0, sizeof(ScoutReact)-1)]);
			}
			case TFClass_Soldier: // Soldier
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SoldierReact[GetRandomInt(0, sizeof(SoldierReact)-1)]);
			}
			case TFClass_Pyro: // Pyro
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, PyroReact[GetRandomInt(0, sizeof(PyroReact)-1)]);
			}
			case TFClass_DemoMan: // DemoMan
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, DemoReact[GetRandomInt(0, sizeof(DemoReact)-1)]);
			}
			case TFClass_Heavy: // Heavy
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, HeavyReact[GetRandomInt(0, sizeof(HeavyReact)-1)]);
			}
			case TFClass_Engineer: // Engineer
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, EngyReact[GetRandomInt(0, sizeof(EngyReact)-1)]);
			}	
			case TFClass_Medic: // Medic
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, MedicReact[GetRandomInt(0, sizeof(MedicReact)-1)]);
			}
			case TFClass_Sniper: // Sniper
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SniperReact[GetRandomInt(0, sizeof(SniperReact)-1)]);
			}
			case TFClass_Spy: // Spy
			{
				strcopy(Reaction, PLATFORM_MAX_PATH, SpyReact[GetRandomInt(0, sizeof(SpyReact)-1)]);
			}
		}
		EmitSoundToAll(Reaction, client);
	}
}

stock bool:IsBoss(client)
{
	if(FF2_GetBossIndex(client)==-1) return false;
	if(GetClientTeam(client)!=FF2_GetBossTeam()) return false;
	return true;
}

stock bool:IsValidClient(client, bool:isPlayerAlive=false)
{
	if (client <= 0 || client > MaxClients) return false;
	if(isPlayerAlive) return IsClientInGame(client) && IsPlayerAlive(client);
	return IsClientInGame(client);
}