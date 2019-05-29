#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <tf2items_giveweapon>
#include <morecolors>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#define PLUGIN_VERSION "0.1"

#define TF_OBJECT_TELEPORTER	1

#define TF_TELEPORTER_ENTR	0


new BossTeam=_:TFTeam_Blue;
new bool:gb_roboticsoldier;
new bool:teleportercheck;
new bool:AnnouncerQuiet;

new var1;	//Activation Key
new countcharge;
new g_iMaxEntities;
new BossTeleporter;

#define SCOUT_ROBOT					"models/bots/scout/bot_scout.mdl"
#define SOLDIER_ROBOT				"models/bots/soldier/bot_soldier.mdl"
#define PYRO_ROBOT					"models/bots/pyro/bot_pyro.mdl"
#define DEMOMAN_ROBOT				"models/bots/demo/bot_demo.mdl"
#define HEAVY_ROBOT					"models/bots/heavy/bot_heavy.mdl"
#define MEDIC_ROBOT					"models/bots/medic/bot_medic.mdl"
#define	SPY_ROBOT					"models/bots/spy/bot_spy.mdl"
#define ENGINEER_ROBOT				"models/bots/engineer/bot_engineer.mdl"
#define SNIPER_ROBOT				"models/bots/sniper/bot_sniper.mdl"

#define ENGIE_SPAWN_SOUND		"vo/announcer_mvm_engbot_arrive02.wav"
#define ENGIE_SPAWN_SOUND2		"vo/announcer_mvm_engbot_arrive03.wav"

#define TELEPORTER_ACTIVATE1	"vo/announcer_mvm_eng_tele_activated01.wav"
#define TELEPORTER_ACTIVATE2	"vo/announcer_mvm_eng_tele_activated02.wav"
#define TELEPORTER_ACTIVATE3	"vo/announcer_mvm_eng_tele_activated03.wav"
#define TELEPORTER_ACTIVATE4	"vo/announcer_mvm_eng_tele_activated04.wav"
#define TELEPORTER_ACTIVATE5	"vo/announcer_mvm_eng_tele_activated05.wav"

#define TELEPORTER_SPAWN		"mvm/mvm_tele_deliver.wav"


public Plugin:myinfo=
{
	name="Freak Fortress 2: Robotic Soldier Abilittypack",
	author="Benoist3012",
	description="FF2: Robotic Soldier",
	version=PLUGIN_VERSION
};
public OnPluginStart2()
{
	HookEvent("teamplay_round_active", event_round_active, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", event_round_active, EventHookMode_PostNoCopy); 
	HookEvent("teamplay_round_win", event_round_end);
	AddCommandListener(CommandListener_Build, "build");
	g_iMaxEntities = GetMaxEntities();
	AddNormalSoundHook(SoundHook);
	//HookEvent("player_death", event_player_death, EventHookMode_Pre);
}
public OnMapStart()
{
	countcharge = 0;
	gb_roboticsoldier = false;
	PrecacheModel(SCOUT_ROBOT, true);
	PrecacheModel(SOLDIER_ROBOT, true);
	PrecacheModel(PYRO_ROBOT, true);
	PrecacheModel(DEMOMAN_ROBOT, true);
	PrecacheModel(HEAVY_ROBOT, true);
	PrecacheModel(MEDIC_ROBOT, true);
	PrecacheModel(SPY_ROBOT, true);
	PrecacheModel(ENGINEER_ROBOT, true);
	PrecacheModel(SNIPER_ROBOT, true);
	PrecacheSound(ENGIE_SPAWN_SOUND, true);
	PrecacheSound(ENGIE_SPAWN_SOUND2, true);
	PrecacheSound(TELEPORTER_ACTIVATE1, true);
	PrecacheSound(TELEPORTER_ACTIVATE2, true);
	PrecacheSound(TELEPORTER_ACTIVATE3, true);
	PrecacheSound(TELEPORTER_ACTIVATE4, true);
	PrecacheSound(TELEPORTER_ACTIVATE5, true);
	PrecacheSound(TELEPORTER_SPAWN, true);
}
public event_round_active(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.3, Timer_GetBossTeam);
	countcharge = 0;
	gb_roboticsoldier = false;
	teleportercheck = false;
	AnnouncerQuiet = false;
	BossTeleporter = -1;
	if(FF2_HasAbility( 0, this_plugin_name, "rage_robotic_soldier"))
	{
		new client = GetClientOfUserId(FF2_GetBossUserId(0));
		if(client && IsClientInGame(client) && IsPlayerAlive(client))
		{
			gb_roboticsoldier = true;
			//Fake teleporter
			CreateTimer(0.4, Particle_Teleporter);
			CreateTimer(0.5, CheckTeleporter);
			CreateTimer(0.6, SpawnDeadPlayer);
		}
	}
}
public event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	countcharge = 0;
	gb_roboticsoldier = false;
	teleportercheck = false;
	AnnouncerQuiet = false;
	BossTeleporter = -1;
}
public Action:Timer_GetBossTeam(Handle:hTimer)
{
	BossTeam=FF2_GetBossTeam();
	return Plugin_Continue;
}
public Action:CheckTeleporter(Handle:hTimer)
{
	if(gb_roboticsoldier)
	{
		CreateTimer(0.0, CheckTeleporter);
		new TeleporterExit = -1;	
		if((TeleporterExit = FindEntityByClassname(TeleporterExit,"obj_teleporter")) != -1 && GetEntProp(TeleporterExit, Prop_Send, "m_iTeamNum") == BossTeam)
		{
			new String:modelname[128];
			GetEntPropString(TeleporterExit, Prop_Data, "m_ModelName", modelname, 128);
			if(StrContains(modelname, "light") != -1)
			{
				teleportercheck = true;
				BossTeleporter = TeleporterExit;
			}
			else
			{
				teleportercheck = false;
				BossTeleporter = -1;
			}
		}
		else
		{
			AnnouncerQuiet = false;
			if(teleportercheck)
			{
				teleportercheck = false;
			}
		}
	}
}
public Action:Particle_Teleporter(Handle:hTimer)
{
	if(gb_roboticsoldier)
	{
		CreateTimer(3.0, Particle_Teleporter);
		new TeleporterExit = -1;	
		if((TeleporterExit = FindEntityByClassname(TeleporterExit,"obj_teleporter")) != -1)
		{
			if(GetEntProp(TeleporterExit, Prop_Send, "m_iTeamNum") == BossTeam)
			{
				new String:modelname[128];
				GetEntPropString(TeleporterExit, Prop_Data, "m_ModelName", modelname, 128);
				if(StrContains(modelname, "light") != -1)
				{
					new Float:position[3];
					GetEntPropVector(TeleporterExit,Prop_Send, "m_vecOrigin",position);
					new attach = CreateEntityByName("trigger_push");
					CreateTimer(3.0, DeleteTrigger, attach);
					TeleportEntity(attach, position, NULL_VECTOR, NULL_VECTOR);
					AttachParticle(attach,"teleporter_mvm_bot_persist");
					AttachParticle(attach,"teleporter_blue_floorglow");
					AttachParticle(attach,"teleporter_blue_entrance_disc");
					AttachParticle(attach,"teleporter_blue_exit_level3");
					AttachParticle(attach,"teleporter_blue_charged_wisps");
					AttachParticle(attach,"teleporter_blue_charged");
					if(!AnnouncerQuiet)
					{
						new soundswitch;
						soundswitch = GetRandomInt(1, 5);
						switch(soundswitch)
						{
							case 1:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE1);
							}
							case 2:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE2);
							}
							case 3:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE3);
							}
							case 4:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE4);
							}
							case 5:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE5);
							}
						}
						AnnouncerQuiet = true;
					}
				}
			}
		}
	}
}
public Action:SpawnDeadPlayer(Handle:hTimer)
{
	if(gb_roboticsoldier)
	{
		CreateTimer(1.0, SpawnDeadPlayer);
	}
	new random;
	random = GetRandomInt(1, 100);
	switch(random)
	{
		case 1,25,31,48,54,68,71,87,57,35,97,24,58,16,19:
		{
			if(teleportercheck && gb_roboticsoldier)
			{
				SpawnRobot();
			}
		}
	}
}
SpawnRobot()
{
	new ii;
	ii = GetRandomDeadPlayer();
	new playerinBossTeam = GetTeamPlayerCount(BossTeam);
	if(ii != -1 && playerinBossTeam < 6)
	{
		FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOWSPAWNINBOSSTEAM);
		ChangeClientTeam(ii,BossTeam);
		TF2_RespawnPlayer(ii);
		if (TF2_GetPlayerClass(ii) == TFClass_Engineer && playerinBossTeam < 6 && GetEntPropEnt(BossTeleporter,Prop_Send,"m_hBuilder") == ii)
		{
			new classrandom;
			classrandom = GetRandomInt(1, 8);
			switch(classrandom)
			{
				case 1:
				{
					TF2_SetPlayerClass(ii, TFClass_DemoMan);
				}
				case 2:
				{
					TF2_SetPlayerClass(ii, TFClass_Medic);	
				}
				case 3:
				{
					TF2_SetPlayerClass(ii, TFClass_Soldier);
				}
				case 4:
				{
					TF2_SetPlayerClass(ii, TFClass_Pyro);
				}
				case 5:
				{
					TF2_SetPlayerClass(ii, TFClass_Spy);
				}
				case 6:
				{
					TF2_SetPlayerClass(ii, TFClass_Heavy);
				}
				case 7:
				{
					TF2_SetPlayerClass(ii, TFClass_Scout);
				}
				case 8:
				{
					TF2_SetPlayerClass(ii, TFClass_Sniper);
				}
			}
		}
		EmitSoundToAll(TELEPORTER_SPAWN);
		TF2_RegeneratePlayer(ii);
		TF2_AddCondition(ii, TFCond:TFCond_UberchargedCanteen, 3.0);
		CreateTimer(0.1, Timer_SetRobotModel, ii, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		new Float:position[3];
		GetEntPropVector(BossTeleporter,Prop_Send, "m_vecOrigin",position);
		position[2] += 50;
		TeleportEntity(ii, position, NULL_VECTOR, NULL_VECTOR);
		new entity, owner;
		while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
		{
			if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
			{
				TF2_RemoveWearable(owner, entity);
			}
		}

		while((entity=FindEntityByClassname(entity, "tf_wearable_demoshield"))!=-1)
		{
			if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
			{
				TF2_RemoveWearable(owner, entity);
			}
		}

		while((entity=FindEntityByClassname(entity, "tf_powerup_bottle"))!=-1)
		{
			if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
			{
				TF2_RemoveWearable(owner, entity);
			}
		}
	}
}
public Action:FF2_OnAbility2(index, const String:plugin_name[], const String:ability_name[], status)
{
	if(!strcmp(ability_name, "summon_engie"))
		Engie(ability_name, index);
	else if(!strcmp(ability_name, "rage_robotic_soldier"))
		Rage_Soldier(ability_name,index);		
	return Plugin_Continue;
}
Rage_Soldier(const String:ability_name[],index)
{
	new Boss = GetClientOfUserId(FF2_GetBossUserId(index));
	new Float:duration=FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name,1,2.0);
	TF2_AddCondition(Boss, TFCond_UberchargedCanteen, duration);
	var1=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 2);	//Activation Key
	countcharge=FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 3);	//No of times skill can be used per rage
	SetKeysBits(var1);
	PrintCenterText(Boss,"Number of charge for summon a engineer bot: %i",countcharge);
}
Engie(const String:ability_name[],index)
{	
	new Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	if(countcharge > 0)
	{
		PrintCenterText(Boss,"Number of charge for summon a engineer bot: %i",countcharge);
		if (GetClientButtons(Boss) & var1)
		{
			new Float:duration = FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name, 1);
			new String:attributes[64]="68 ; -1";
			FF2_GetAbilityArgumentString(index, this_plugin_name, ability_name, 2, attributes, sizeof(attributes));
			new health=FF2_GetAbilityArgument(index, this_plugin_name, ability_name, 3, 0);
			
			new engineer = 0;
			for( new i = 1; i <= MaxClients; i++ )
			{
				if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == BossTeam && TF2_GetPlayerClass(i) == TFClass_Engineer)
				{
					engineer = 1;
					break;
				}
			}
			new ii;
			ii = GetRandomDeadPlayer();
			if(ii != -1 && engineer < 1)
			{
				DestroyBuildings();
				FF2_SetFF2flags(ii,FF2_GetFF2flags(ii)|FF2FLAG_ALLOWSPAWNINBOSSTEAM);
				ChangeClientTeam(ii,BossTeam);
				TF2_RespawnPlayer(ii);
				if (TF2_GetPlayerClass(ii) != TFClass_Engineer) TF2_SetPlayerClass(ii, TFClass_Engineer);
				SetVariantString(ENGINEER_ROBOT);
				AcceptEntityInput(ii, "SetCustomModel");
				SetEntProp(ii, Prop_Send, "m_bUseClassAnimations", 1);
				TF2_RemoveAllWeapons(ii);
				TF2_AddCondition(ii, TFCond_UberchargedCanteen, duration);
				if(attributes[0]=='\0')
				{
					attributes="68 ; -1";
				}
				new weapon;
				TF2Items_GiveWeapon(ii, 737);
				TF2Items_GiveWeapon(ii, 26);    
				TF2Items_GiveWeapon(ii, 28);
				SpawnWeapon(ii, "tf_weapon_shotgun_primary", 199, 101, 0, "");
				SpawnWeapon(ii, "tf_weapon_pistol", 209, 101, 0, attributes);
				weapon = SpawnWeapon(ii, "tf_weapon_wrench", 197, 101, 0, "");
				SetEntPropEnt(ii, Prop_Send, "m_hActiveWeapon", weapon);
				SetEntProp(ii, Prop_Data, "m_iMaxHealth", health);
				SetEntProp(ii, Prop_Data, "m_iHealth", health);
				SetEntProp(ii, Prop_Send, "m_iHealth", health);
				new Float:position[3];
				GetEntPropVector(Boss, Prop_Data, "m_vecOrigin", position);
				TeleportEntity(ii, position, NULL_VECTOR, NULL_VECTOR);
				new attach = CreateEntityByName("trigger_push");
				CreateTimer(10.0, DeleteTrigger, attach);
				TeleportEntity(attach, position, NULL_VECTOR, NULL_VECTOR);
				TE_Particle("teleported_mvm_bot", position, _, _, attach, 1,0);
				//CreateTimer(0.0, Timer_CheckBuilding, ii, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				new soundswitch;
				soundswitch = GetRandomInt(1, 2);
				switch(soundswitch)
				{
					case 1:
					{
						EmitSoundToAll(ENGIE_SPAWN_SOUND2);
					}
					case 2:
					{
						EmitSoundToAll(ENGIE_SPAWN_SOUND);
					}
				}
				countcharge = countcharge-1;
				PrintCenterText(Boss,"Number of charge for summon a engineer bot: %i",countcharge);
				new entity, owner;
				while((entity=FindEntityByClassname(entity, "tf_wearable"))!=-1)
				{
					if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
					{
						TF2_RemoveWearable(owner, entity);
					}
				}

				while((entity=FindEntityByClassname(entity, "tf_wearable_demoshield"))!=-1)
				{
					if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
					{
						TF2_RemoveWearable(owner, entity);
					}
				}

				while((entity=FindEntityByClassname(entity, "tf_powerup_bottle"))!=-1)
				{
					if((owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))<=MaxClients && owner>0 && GetClientTeam(owner)==BossTeam)
					{
						TF2_RemoveWearable(owner, entity);
					}
				}
			}
		}
	}
}
public Action:CommandListener_Build(client, const String:command[], argc)
{
	decl String:sObjectMode[256], String:sObjectType[256];
	GetCmdArg(1, sObjectType, sizeof(sObjectType));
	GetCmdArg(2, sObjectMode, sizeof(sObjectMode));
	new iObjectMode = StringToInt(sObjectMode);
	new iObjectType = StringToInt(sObjectType);
	new iTeam = GetClientTeam(client);
	decl String:sClassName[32];
	for(new i = MaxClients + 1; i < g_iMaxEntities; i++)
	{
		if(!IsValidEntity(i))
			continue;
		GetEntityNetClass(i, sClassName, sizeof(sClassName));
		if(iObjectType == TF_OBJECT_TELEPORTER && iObjectMode == TF_TELEPORTER_ENTR && gb_roboticsoldier && iTeam == BossTeam)
		{
			PrintCenterText(client,"You can't build enter teleporter you can only build a exit teleporter!");
			PrintToChat(client,"You can't build enter teleporter you can only build a exit teleporter!");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
public SetKeysBits(keys)
{
	if(keys==2)			//IN_ATTACK2
		var1 = 2048;
	else if(keys==3)	//IN_RELOAD
		var1 = 8192;
	else				//IN_ATTACK
		var1 = 1;
}
stock SpawnWeapon(client, String:name[], index, level, quality, String:attribute[])
{
	new Handle:weapon=TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	TF2Items_SetClassname(weapon, name);
	TF2Items_SetItemIndex(weapon, index);
	TF2Items_SetLevel(weapon, level);
	TF2Items_SetQuality(weapon, quality);
	new String:attributes[32][32];
	new count = ExplodeString(attribute, ";", attributes, 32, 32);
	if(count%2!=0)
	{
		count--;
	}

	if(count>0)
	{
		TF2Items_SetNumAttributes(weapon, count/2);
		new i2=0;
		for(new i=0; i<count; i+=2)
		{
			new attrib=StringToInt(attributes[i]);
			if(attrib==0)
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

	if(weapon==INVALID_HANDLE)
	{
		return -1;
	}
	new entity=TF2Items_GiveNamedItem(client, weapon);
	CloseHandle(weapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}
stock AttachParticle(entity, String:particleType[], Float:offset[]={0.0,0.0,0.0}, bool:attach=true)
{
	new particle=CreateEntityByName("info_particle_system");

	decl String:targetName[128];
	decl Float:position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[0]+=offset[0];
	position[1]+=offset[1];
	position[2]+=offset[2];
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
	CreateTimer(3.0, DeleteParticle, particle);
	return particle;
}
public Action:DeleteParticle(Handle:timer, any:Ent)
{
	if (!IsValidEntity(Ent)) return;
	new String:cls[25];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "info_particle_system", false)) AcceptEntityInput(Ent, "Kill");
	return;
}
public Action:DeleteTrigger(Handle:timer, any:Ent)
{
	if (!IsValidEntity(Ent)) return;
	new String:cls[25];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "trigger_push", false)) AcceptEntityInput(Ent, "Kill");
	return;
}
public Action:Timer_SetRobotModel(Handle:hTimer, any:iClient)
{
	if(!gb_roboticsoldier)
		return Plugin_Stop;
	if(!IsPlayerAlive(iClient))
		return Plugin_Handled;
	
	if(TF2_IsPlayerInCondition(iClient, TFCond_Taunting) || TF2_IsPlayerInCondition(iClient, TFCond_Dazed))
		return Plugin_Handled;
	
	new TFClassType:iClass = TF2_GetPlayerClass(iClient);
	new String:strModel[PLATFORM_MAX_PATH];
	switch(iClass)
	{
		case TFClass_Scout: strcopy( strModel, sizeof(strModel), "scout");
		case TFClass_Sniper: strcopy( strModel, sizeof(strModel), "sniper");
		case TFClass_Soldier: strcopy( strModel, sizeof(strModel), "soldier");
		case TFClass_DemoMan: strcopy( strModel, sizeof(strModel), "demo");
		case TFClass_Medic: strcopy( strModel, sizeof(strModel), "medic");
		case TFClass_Heavy: strcopy( strModel, sizeof(strModel), "heavy");
		case TFClass_Pyro: strcopy( strModel, sizeof(strModel), "pyro");
		case TFClass_Spy: strcopy( strModel, sizeof(strModel), "spy");
		case TFClass_Engineer: strcopy( strModel, sizeof(strModel), "engineer");
	}
	if( strlen(strModel) > 0 )
	{
		Format(strModel, sizeof(strModel), "models/bots/%s/bot_%s.mdl", strModel, strModel);
		SetRobotModel(iClient, strModel);
	}	
	return Plugin_Stop;
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
stock SetRobotModel(iClient, const String:strModel[PLATFORM_MAX_PATH] = "" )
{
	if(!gb_roboticsoldier)
		return;
	
	if(strlen(strModel) > 2)
		PrecacheMdl(strModel);
	
	SetVariantString(strModel);
	AcceptEntityInput(iClient, "SetCustomModel");
	SetEntProp(iClient, Prop_Send, "m_bUseClassAnimations", 1);
}
stock PrecacheMdl( const String:strModel[PLATFORM_MAX_PATH], bool:bPreload = false )
{
	if( FileExists( strModel, true ) || FileExists( strModel, false ) )
		if( !IsModelPrecached( strModel ) )
			return PrecacheModel( strModel, bPreload );
	return -1;
}
stock TE_Particle(String:Name[], Float:origin[3]=NULL_VECTOR, Float:start[3]=NULL_VECTOR, Float:angles[3]=NULL_VECTOR,entindex=-1,attachtype=-1,attachpoint=-1,bool:resetParticles=true,customcolors = 0,Float:color1[3] = NULL_VECTOR,Float:color2[3] = NULL_VECTOR,controlpoint = -1,controlpointattachment = -1,Float:controlpointoffset[3] = NULL_VECTOR)
{
    // find string table
    new tblidx = FindStringTable("ParticleEffectNames");
    if (tblidx==INVALID_STRING_TABLE) 
    {
        LogError("Could not find string table: ParticleEffectNames");
        return;
    }
    new Float:delay=3.0;
    // find particle index
    new String:tmp[256];
    new count = GetStringTableNumStrings(tblidx);
    new stridx = INVALID_STRING_INDEX;
    new i;
    for (i=0; i<count; i++)
    {
        ReadStringTable(tblidx, i, tmp, sizeof(tmp));
        if (StrEqual(tmp, Name, false))
        {
            stridx = i;
            break;
        }
    }
    if (stridx==INVALID_STRING_INDEX)
    {
        LogError("Could not find particle: %s", Name);
        return;
    }

    TE_Start("TFParticleEffect");
    TE_WriteFloat("m_vecOrigin[0]", origin[0]);
    TE_WriteFloat("m_vecOrigin[1]", origin[1]);
    TE_WriteFloat("m_vecOrigin[2]", origin[2]);
    TE_WriteFloat("m_vecStart[0]", start[0]);
    TE_WriteFloat("m_vecStart[1]", start[1]);
    TE_WriteFloat("m_vecStart[2]", start[2]);
    TE_WriteVector("m_vecAngles", angles);
    TE_WriteNum("m_iParticleSystemIndex", stridx);
    if (entindex!=-1)
    {
        TE_WriteNum("entindex", entindex);
    }
    if (attachtype!=-1)
    {
        TE_WriteNum("m_iAttachType", attachtype);
    }
    if (attachpoint!=-1)
    {
        TE_WriteNum("m_iAttachmentPointIndex", attachpoint);
    }
    TE_WriteNum("m_bResetParticles", resetParticles ? 1 : 0);    
    
    if(customcolors)
    {
        TE_WriteNum("m_bCustomColors", customcolors);
        TE_WriteVector("m_CustomColors.m_vecColor1", color1);
        if(customcolors == 2)
        {
            TE_WriteVector("m_CustomColors.m_vecColor2", color2);
        }
    }
    if(controlpoint != -1)
    {
        TE_WriteNum("m_bControlPoint1", controlpoint);
        if(controlpointattachment != -1)
        {
            TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", controlpointattachment);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", controlpointoffset[0]);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", controlpointoffset[1]);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", controlpointoffset[2]);
        }
    }
    
    TE_SendToAll(delay);
}
stock GetTeamPlayerCount( iTeamNum = -1 )
{
	new iCounter = 0;
	for( new i = 1; i <= MaxClients; i++ )
		if(IsClientInGame(i) && (iTeamNum == -1 || GetClientTeam(i) == iTeamNum) && IsPlayerAlive(i))
			iCounter++;
	return iCounter;
}
stock DestroyBuildings()
{
	decl String:strObjects[3][] = {"obj_sentrygun","obj_dispenser","obj_teleporter"};
	for( new o = 0; o < sizeof(strObjects); o++ )
	{
		new iEnt = -1;
		while( ( iEnt = FindEntityByClassname( iEnt, strObjects[o] ) ) != -1 )
			if( IsValidEdict(iEnt) && GetEntProp( iEnt, Prop_Send, "m_iTeamNum" ) == BossTeam )
			{
				SetEntityHealth( iEnt, 100 );
				SetVariantInt( 1488 );
				AcceptEntityInput( iEnt, "RemoveHealth" );
			}
	}
}
public Action:SoundHook(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &Ent, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (!gb_roboticsoldier) return Plugin_Continue;
	if (volume == 0.0 || volume == 0.9997) return Plugin_Continue;
	if (!IsValidClient(Ent)) return Plugin_Continue;
	new client = Ent;
	new TFClassType:class = TF2_GetPlayerClass(client);
	if (GetClientTeam(client)== BossTeam)
	{
		if (StrContains(sound, "player/footsteps/", false) != -1 && class != TFClass_Medic)
		{
			new rand = GetRandomInt(1,18);
			Format(sound, sizeof(sound), "mvm/player/footsteps/robostep_%s%i.wav", (rand < 10) ? "0" : "", rand);
			pitch = GetRandomInt(95, 100);
			PrecacheSound(sound, false);
			EmitSoundToAll(sound, client, SNDCHAN_STATIC, 95, _, _, pitch);
			return Plugin_Changed;
		}
		if (StrContains(sound, "vo/", false) == -1) return Plugin_Continue;
		if (StrContains(sound, "announcer", false) != -1) return Plugin_Continue;
		if (StrContains(sound, "mvm", false) != -1) return Plugin_Continue;
		if (volume == 0.99997) return Plugin_Continue;
		ReplaceString(sound, sizeof(sound), "vo/", "vo/mvm/norm/", false);
		ReplaceString(sound, sizeof(sound), ".wav", ".mp3", false);
		new String:classname[10], String:classname_mvm[15];
		TF2_GetNameOfClass(class, classname, sizeof(classname));
		Format(classname_mvm, sizeof(classname_mvm), "%s_mvm", classname);
		ReplaceString(sound, sizeof(sound), classname, classname_mvm, false);
		new String:soundchk[PLATFORM_MAX_PATH];
		Format(soundchk, sizeof(soundchk), "sound/%s", sound);
		PrecacheSound(sound);
		return Plugin_Changed;
	}
	return Plugin_Continue;
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
stock IsValidClient( client )
{
	//Check for client "ID"
	if  ( client <= 0 || client > MaxClients ) 
		return false;
	
	//Check for client is in game
	if ( !IsClientInGame( client ) ) 
		return false;
	
	return true;
}