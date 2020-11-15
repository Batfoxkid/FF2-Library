/*
	This plugin is based on SHADoW's Project BlitzRocketHell

	Some features are taken from the old plugins
	but this is mostly made from the ground up.

	Changes mainly to improve on performance and
	supportative towards Unofficial Freak Fortress.

	Noticeable changes is the plugin now depends on
	a translation file and reloads itself once it's
	done. This is done instead of a massive amount
	of strings.

	Timer		Uses FF2_OnAbility2, engine time, formula for each wave

	Phrases		Changes the translation file that is used for other abilities

	Mann Up		Menu description for weapons, special weapon option (eg. Hook)

	Bounce 		Projectile bounce for (nearly) any projectile
			<0 - Random, less value means rarer for a single bounce
			<1 - Chance for each bounce
			>1 - Maximum bounces

	Soul		Classes to switch to, random & specific weapons for all classes or per class

	Difficulty 	Changes the difficulty, can be used for formulas
			<0 - Random, slightly based on lives left
			=0 - No change
			<1 - Chance for a higher level
			>1 - Level(s) gained

	Original Blitzkrieg - https://github.com/shadow93/BlitzRocketHell
	Ricochet - https://forums.alliedmods.net/showthread.php?p=2671241
*/
#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

#define MAJOR_REVISION	"0"
#define MINOR_REVISION	"1"
#define STABLE_REVISION	"0"
#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define FAR_FUTURE		100000000.0
#define MAX_SOUND_LENGTH	80
#define MAX_MODEL_LENGTH	128
#define MAX_MAP_LENGTH		99
#define MAX_ATTRIBUTE_LENGTH	512
#define MAX_CLASSNAME_LENGTH	64
#define MAX_BOSSNAME_LENGTH	64
#define MAX_TRANS_LENGTH	80
#define MAX_HUD_LENGTH		256
#define MAXTF2PLAYERS		36
#define MAXENTITIES		2048
#define MAX_WEAPONS		10

#define BLITZTIMER	"special_timer"
#define BLITZPHRASES	"special_phrases"
#define BLITZMANN	"special_mannup"
#define BLITZBOUNCE	"special_bounce"
#define BLITZSOUL	"rage_soul"
#define BLITZPOINTS	"special_points"
#define BLITZDIFF	"rage_difficulty"

#define SOUNDTICK	"sound_timer_tick"
#define SOUNDRESET	"sound_timer_reset"
#define SOUNDINTRO	"sound_mann_intro"
#define SOUNDLOSE	"sound_mann_lose"
#define SOUNDWIN	"sound_mann_win"
#define SOUNDLEVEL	"sound_level_"

// Names used for args
static const char ClassName[][] =
{
	"soldier",
	"scout",
	"sniper",
	"soldier",
	"demoman",
	"medic",
	"heavy",
	"pyro",
	"spy",
	"engineer"
};

// Required phrases, used to check if their avaiable
static const char Phrases[][] =
{
	"timer",
	"timer_max",
	"diff_single",
	"diff_multi",
	"level"
};

// Countdown Timer Settings
enum struct TimerEnum
{
	int Enabled;
	int Wave;
	int Max;
	float Next;
	Handle Hud;
}

// Mann Up Settings
enum struct MannUpEnum
{
	int Enabled;
	int Index;
	char Classname[MAX_CLASSNAME_LENGTH];
	char Attributes[MAX_ATTRIBUTE_LENGTH];
	char WinSound[MAX_SOUND_LENGTH];
	char LoseSound[MAX_SOUND_LENGTH];
}

// Bounce Settings
enum struct BounceEnum
{
	int Owned[MAXTF2PLAYERS];
	int Owner[MAXENTITIES];
}

// Point Settings
enum struct QueueEnum
{
	int Rockets;
	float Points;
	int Taken[MAXTF2PLAYERS];
}

// Difficulty Settings
enum struct DiffEnum
{
	int Enabled;
	float HudAt;
	Handle Hud;
	int Level[MAXTF2PLAYERS];
}

bool Enabled;			// If to reset the plugin on round end
int FF2Countdown;		// Countdown player ConVar value
int TotalPlayers;		// Total players
int Players;			// Alive players
DiffEnum Diff;			// Difficulty settings
QueueEnum Queue;		// Point settings
BounceEnum Bounce;		// Bounce settings
TimerEnum Timer;		// Countdown Timer settings
MannUpEnum MannUp;		// Mann Up settings
Handle OnHaleRage;		// VSH forward

// Used for Formula Operations
enum Operators
{
	Operator_None = 0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

public Plugin myinfo =
{
	name		=	"Freak Fortress 2: The Blitzkrieg Return",
	author		=	"Batfoxkid",
	description	=	"Remake based on SHADoW93's Project BlitzRocketHell",
	version		=	PLUGIN_VERSION
};

// SourceMod Events

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	OnHaleRage = CreateGlobalForward("VSH_OnDoRage", ET_Hook, Param_FloatByRef);
	return APLRes_Success;
}

public void OnPluginStart2()
{
	HookEvent("arena_round_start", _OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_Post);
	HookEvent("player_hurt", _OnPlayerHurt, EventHookMode_Post);

	if(FF2_GetRoundState() == 1)	// In case the plugin is loaded in late
		_OnRoundStart(view_as<Event>(INVALID_HANDLE), "plugin_lateload", false);
}

// TF2 Events

public void _OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Queue.Rockets = 0;
	TotalPlayers = 0;
	int client = 1;
	for(; client<=MaxClients; client++)
	{
		Queue.Taken[client] = 0;
		Bounce.Owned[client] = 0;
		if(IsValidClient(client) && GetClientTeam(client)>view_as<int>(TFTeam_Spectator))
			TotalPlayers++;
	}
	Players = TotalPlayers;

	for(int boss; boss<=MaxClients; boss++)
	{
		client = GetClientOfUserId(FF2_GetBossUserId(boss));
		if(!IsValidClient(client))
			continue;

		if(FF2_HasAbility(boss, this_plugin_name, BLITZMANN))
			MannAll(boss);

		if(FF2_HasAbility(boss, this_plugin_name, BLITZPOINTS))
			Queue.Points = GetArgF(boss, BLITZPOINTS, "points", 0.03, 1);

		if(FF2_HasAbility(boss, this_plugin_name, BLITZDIFF) && LoadPhrases(boss))
			DiffSetup(boss);

		if(FF2_HasAbility(boss, this_plugin_name, BLITZSOUL))
			SoulChange(boss, BLITZSOUL, true, false);
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Diff.Enabled = 0;
	if(Enabled)
		CreateTimer(4.5, Timer_Unload, event.GetInt("team"), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPostAdminCheck(int client)
{
	if(IsValidClient(client))
	{
		Queue.Taken[client] = Queue.Rockets;
		Bounce.Owned[client] = 0;
	}
}

public void OnPostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	if(FF2_GetRoundState() != 1)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(client) && FF2_GetBossIndex(client)<0)
		CreateTimer(0.25, MannClient, client, TIMER_FLAG_NO_MAPCHANGE);
}

public void _OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if(Queue.Points <= 0)
		return;

	if(event.GetInt("damageamount") < 1)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(IsValidClient(client) && IsBoss(GetClientOfUserId(event.GetInt("attacker"))))
		Queue.Taken[client]++;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(IsValidEntity(entity) && StrContains(classname, "tf_projectile")>=0)
		SDKHook(entity, SDKHook_SpawnPost, OnProjectileSpawned);
}

public void OnGameFrame()
{
	if(!Diff.Enabled || Diff.HudAt>GetEngineTime())
		return;

	Diff.Enabled = 0;
	Diff.HudAt = GetEngineTime()+1.5;
	int boss;
	int client = 1;
	static char msg[MAX_HUD_LENGTH];
	SetHudTextParams(-1.0, 0.73, 1.6, 255, 255, 255, 255);
	for(; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;

		boss = FF2_GetBossIndex(client);
		if(boss<0 || Diff.Level[boss]<1)
			continue;

		Diff.Enabled++;
		if(IsFakeClient(client))
			continue;

		SetGlobalTransTarget(client);
		Format(msg, MAX_HUD_LENGTH, "level_%i", Diff.Level[boss]);
		if(TranslationPhraseExists(msg))
		{
			Format(msg, MAX_HUD_LENGTH, "%t", msg);
		}
		else
		{
			Format(msg, MAX_HUD_LENGTH, "%t", "level", Diff.Level[boss]);
		}
		FF2_ShowSyncHudText(client, Diff.Hud, "%t", "diff_single", msg);
	}

	if(Diff.Enabled > 1)
	{
		int i;
		static char level[MAX_BOSSNAME_LENGTH], name[MAX_BOSSNAME_LENGTH];
		SetHudTextParams(-1.0, 0.8-(Diff.Enabled*0.05), 1.6, 255, 255, 255, 255);
		for(client=1; client<=MaxClients; client++)
		{
			if(!IsValidClient(client) || IsFakeClient(client) || FF2_GetBossIndex(client)>=0)
				continue;

			SetGlobalTransTarget(client);
			strcopy(msg, MAX_HUD_LENGTH, "");
			for(i=1; i<=MaxClients; i++)
			{
				if(!IsValidClient(i))
					continue;

				boss = FF2_GetBossIndex(i);
				if(boss<0 || Diff.Level[boss]<1)
					continue;

				FF2_GetBossSpecial(boss, name, MAX_BOSSNAME_LENGTH, 0);
				Format(level, MAX_BOSSNAME_LENGTH, "level_%i", Diff.Level[boss]);
				if(TranslationPhraseExists(level))
				{
					Format(level, MAX_BOSSNAME_LENGTH, "%t", level);
				}
				else
				{
					Format(level, MAX_BOSSNAME_LENGTH, "%t", "level", Diff.Level[boss]);
				}
				Format(msg, MAX_HUD_LENGTH, "%s%t\n", msg, "diff_multi", name, level);
			}
			FF2_ShowSyncHudText(client, Diff.Hud, msg);
		}
	}
	else if(Diff.Enabled > 0)
	{
		for(client=1; client<=MaxClients; client++)
		{
			if(!IsValidClient(client))
				continue;

			boss = FF2_GetBossIndex(client);
			if(boss >= 0)
				break;
		}

		if(boss < 0)
			return;

		SetHudTextParams(-1.0, 0.75, 1.6, 255, 255, 255, 255);
		for(client=1; client<=MaxClients; client++)
		{
			if(!IsValidClient(client) || IsFakeClient(client) || FF2_GetBossIndex(client)>=0)
				continue;

			SetGlobalTransTarget(client);
			Format(msg, MAX_HUD_LENGTH, "level_%i", Diff.Level[boss]);
			if(TranslationPhraseExists(msg))
			{
				Format(msg, MAX_HUD_LENGTH, "%t", msg);
			}
			else
			{
				Format(msg, MAX_HUD_LENGTH, "%t", "level", Diff.Level[boss]);
			}
			FF2_ShowSyncHudText(client, Diff.Hud, "%t", "diff_single", msg);
		}
	}
	else
	{
		Diff.Enabled = 1;
		Diff.HudAt = FAR_FUTURE;
	}
}

// FF2 Events

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	int slot = FF2_GetArgI(boss, this_plugin_name, ability_name, "slot", 0);
	if(!slot)  //Rage
	{
		if(!boss)
		{
			Action action = Plugin_Continue;
			Call_StartForward(OnHaleRage);
			float distance = FF2_GetRageDist(boss, this_plugin_name, ability_name);
			float newDistance = distance;
			Call_PushFloatRef(newDistance);
			Call_Finish(action);
			if(action == Plugin_Changed)
			{
				distance = newDistance;
			}
			else if(action != Plugin_Continue)
			{
				return Plugin_Continue;
			}
		}
	}

	static char sound[MAX_SOUND_LENGTH];
	float engineTime = GetEngineTime();
	if(StrEqual(ability_name, BLITZTIMER))
	{
		if(Timer.Enabled < 1)
		{
			if(!LoadPhrases(boss))
				return Plugin_Continue;

			Timer.Enabled = boss+1;
			Timer.Wave = 1;
			Timer.Max = RoundFloat(GetArgF(boss, BLITZTIMER, "waves", 10.0, 0));
			Timer.Next = GetArgF(boss, BLITZTIMER, "time", 60.0, 2)+engineTime;
			Timer.Hud = CreateHudSynchronizer();
			if(Timer.Max > 0)
			{
				ServerCommand("sm plugins unload roundtimer");
				FF2Countdown = GetConVarInt(FindConVar("ff2_countdown_players"));
				if(FF2Countdown > 0)
					SetConVarInt(FindConVar("ff2_countdown_players"), 0);
			}
		}

		if(Timer.Enabled != boss+1)
			return Plugin_Continue;

		int r;
		int g = 255;
		float left = Timer.Next-engineTime;
		if(left < 0.2)
		{
			if(++Timer.Wave > Timer.Max)
			{
				ForceTeamWin(GetClientTeam(GetClientOfUserId(FF2_GetBossUserId(boss)))==3 ? 2 : 3);
				return Plugin_Continue;
			}

			Timer.Next = GetArgF(boss, BLITZTIMER, "time", (45.0+(15.0*Timer.Wave)), 2)+engineTime;
			for(r=1; r<=MaxClients; r++)
			{
				if(!IsValidClient(r) || !IsPlayerAlive(r))
					continue;

				g = FF2_GetBossIndex(r);
				if(g < 0)
				{
					if(!FF2Player(r).GetPropAny("bIsMinion"))
						TF2_RegeneratePlayer(r);
				}
				else if(FF2_HasAbility(g, this_plugin_name, BLITZSOUL))
				{
					FF2_DoAbility(g, this_plugin_name, BLITZSOUL, 4);
				}
			}

			r = -1;
			while((r=FindEntityByClassname2(r, "tf_projectile*")) != -1)
				RemoveEntity(r);

			if(FF2_RandomSound(SOUNDRESET, sound, MAX_SOUND_LENGTH, boss))
				EmitSoundToAll(sound);

			return Plugin_Continue;
		}

		if(left < 30)
			r = 255;

		if(left < 10)
			g = 0;

		SetHudTextParams(-1.0, 0.2, 0.3, r, g, 0, 255);

		static int lastWhole;
		if(lastWhole != RoundFloat(left))
		{
			lastWhole = RoundFloat(left);
			if(left<10 && FF2_RandomSound(SOUNDTICK, sound, MAX_SOUND_LENGTH, boss))
				EmitSoundToAll(sound);
		}

		static char time[8];
		if(RoundFloat(left)%60 >= 10)
		{
			Format(time, 8, "%i:%i", RoundToFloor(left/60.0), RoundFloat(left)%60);
		}	
		else
		{
			Format(time, 8, "%i:0%i", RoundToFloor(left/60.0), RoundFloat(left)%60);
		}

		for(r=1; r<=MaxClients; r++)
		{
			if(!IsValidClient(r) || IsFakeClient(r))
				continue;

			SetGlobalTransTarget(r);
			if(Timer.Max > 0)
			{
				FF2_ShowSyncHudText(r, Timer.Hud, "%t", "timer_max", Timer.Wave, Timer.Max, time);
			}
			else
			{
				FF2_ShowSyncHudText(r, Timer.Hud, "%t", "timer", Timer.Wave, time);
			}
		}
	}
	else if(!StrContains(ability_name, BLITZSOUL))
	{
		SoulChange(boss, ability_name, true, true);
	}
	else if(!StrContains(ability_name, BLITZDIFF))
	{
		if(Diff.Level[boss] < 1)
			DiffSetup(boss);

		float level = GetArgF(boss, ability_name, "level", 1.0, 0);
		if(!level)
			return Plugin_Continue;

		if(level < 0)
		{
			int max = FF2_GetBossMaxLives(boss);
			if(max > 7)
			{
				Diff.Level[boss] = GetRandomInt(1, 9);
			}
			else
			{
				Diff.Level[boss] = GetRandomInt(max+1, 10)-FF2_GetBossLives(boss);
			}
		}
		else if(level < 1)
		{
			Diff.Level[boss] = 1;
			while(GetRandomFloat(0.0, 1.0)<Diff.Level[boss] && Diff.Level[boss]<10)
			{
				Diff.Level[boss]++;
			}
		}
		else
		{
			if(GetArgF(boss, ability_name, "yes", 0.0, 0))
			{
				switch(Diff.Level[boss])
				{
					case 9:
						Diff.Level[boss] = 420;

					case 420:
						Diff.Level[boss] = 777;

					case 777:
						Diff.Level[boss] = 999;

					case 999:
						Diff.Level[boss] = 1337;

					case 1337:
						Diff.Level[boss] = 9001;

					default:
						Diff.Level[boss] += RoundFloat(level);
				}
			}
			else
			{
				Diff.Level[boss] += RoundFloat(level);
			}
		}

		Format(sound, MAX_SOUND_LENGTH, "%s%i", SOUNDLEVEL, Diff.Level[boss]);
		if(FF2_RandomSound(sound, sound, MAX_SOUND_LENGTH, boss))
			EmitVoiceToAll(sound);
	}
	return Plugin_Continue;
}

public Action FF2_OnAddQueuePoints(int add_points[MAXPLAYERS+1])
{
	if(Queue.Points <= 0)
		return Plugin_Continue;

	for(int client=1; client<=MaxClients; client++)
	{
		if(add_points[client] < 1)
			continue;

		add_points[client] /= 3;
		add_points[client] += RoundToCeil((Queue.Rockets-Queue.Taken[client])*Queue.Points);
	}
	Queue.Points = 0.0;
	return Plugin_Changed;
}

public void FF2_OnAlivePlayersChanged(int players, int bosses)
{
	if(!bosses || !players || FF2_GetRoundState()!=1)
		return;

	Players = players+bosses;
	if(TotalPlayers > players+bosses)
		TotalPlayers = players+bosses;
}

// Publics

public void MannAll(int boss)
{
	if(MannUp.Enabled > 0)
		return;

	MannUp.Enabled = boss+1;
	if(!LoadPhrases(boss))
		return;

	HookEvent("post_inventory_application", OnPostInventoryApplication, EventHookMode_Post);
	FF2_GetArgNamedS(boss, this_plugin_name, BLITZMANN, "classname", MannUp.Classname, MAX_CLASSNAME_LENGTH);
	if(MannUp.Classname[0] != '\0')
	{
		FF2_GetArgNamedS(boss, this_plugin_name, BLITZMANN, "attributes", MannUp.Attributes, MAX_ATTRIBUTE_LENGTH);
		MannUp.Index = RoundFloat(GetArgF(boss, BLITZMANN, "index", -1.0, 2));
	}

	FF2_RandomSound(SOUNDWIN, MannUp.WinSound, MAX_SOUND_LENGTH, boss);
	FF2_RandomSound(SOUNDLOSE, MannUp.LoseSound, MAX_SOUND_LENGTH, boss);

	CreateTimer(2.0, Timer_DelayedSound, boss, TIMER_FLAG_NO_MAPCHANGE);

	for(int client=1; client<=MaxClients; client++)
	{
		MannClient(INVALID_HANDLE, client);
	}
}

public Action MannClient(Handle timer, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client) || FF2_GetBossIndex(client)>=0)
		return Plugin_Continue;

	int weapon, index;
	static char classname[MAX_CLASSNAME_LENGTH], buffer[MAX_CLASSNAME_LENGTH], attr[MAX_ATTRIBUTE_LENGTH];
	Panel panel = new Panel();

	int boss = MannUp.Enabled-1;
	SetGlobalTransTarget(client);
	FF2_GetBossSpecial(boss, classname, MAX_CLASSNAME_LENGTH, 0);
	panel.SetTitle(classname);

	for(int i; i<4; i++)
	{
		weapon = GetPlayerWeaponSlot(client, i);
		if(weapon<=MaxClients || !GetEntityClassname(weapon, classname, MAX_CLASSNAME_LENGTH))
			continue;

		index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		IntToString(index, buffer, MAX_CLASSNAME_LENGTH);
		FF2_GetArgNamedS(boss, this_plugin_name, BLITZMANN, buffer, attr, MAX_ATTRIBUTE_LENGTH);
		if(attr[0] == '\0')
		{
			FF2_GetArgNamedS(boss, this_plugin_name, BLITZMANN, classname, attr, MAX_ATTRIBUTE_LENGTH);
			if(attr[0] == '\0')
				continue;

			strcopy(buffer, MAX_CLASSNAME_LENGTH, classname);
		}

		TF2_RemoveWeaponSlot(client, i);
		SpawnWeapon(client, classname, index, 101, 7, attr, true, boss, BLITZMANN, buffer);
		if(TranslationPhraseExists(buffer))
		{
			panel.DrawText(" ");
			Format(buffer, MAX_ATTRIBUTE_LENGTH, "%t", buffer);
			panel.DrawText(buffer);
		}
	}

	if(MannUp.Classname[0] != '\0')
	{
		// Remove items on the action slot
		weapon = -1;
		while((weapon=FindEntityByClassname2(weapon, "tf_wear*")) != -1)
		{
			if(client == GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity"))
			{
				index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
				if(index==241 || (index>279 && index<287) || index==288 || index==362 || index==364 || index==365 || index==493 || index==536 || index==542 || index==673)
					TF2_RemoveWearable(client, weapon);
			}
		}

		weapon = -1;
		while((weapon=FindEntityByClassname2(weapon, "tf_powerup_bottle")) != -1)
		{
			if(client == GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity"))
				TF2_RemoveWearable(client, weapon);
		}

		weapon = -1;
		while((weapon=FindEntityByClassname2(weapon, "tf_weap*")) != -1)
		{
			if(client == GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity"))
			{
				index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
				if(index==1152 || index==1069 || index==1070 || index==1132 || index==5604) {
					RemovePlayerItem(client, weapon);
					AcceptEntityInput(weapon, "Kill");
				}
			}
		}

		strcopy(classname, MAX_CLASSNAME_LENGTH, MannUp.Classname);
		SpawnWeapon(client, classname, MannUp.Index, 101, 7, MannUp.Attributes, false, boss, BLITZMANN, "attributes");
		if(TranslationPhraseExists("special"))
		{
			Format(buffer, MAX_ATTRIBUTE_LENGTH, "%t", "special");
			panel.DrawText(buffer);
		}
	}

	panel.DrawItem("Exit");
	panel.Send(client, MannClientH, 20);
	return Plugin_Continue;
}

public int MannClientH(Handle panel, MenuAction action, int client, int param)
{
	// Nothing to do, panel is automatically closed
}

public Action Timer_DelayedSound(Handle timer, int boss)
{
	char sound[MAX_SOUND_LENGTH];
	if(!FF2_RandomSound(SOUNDINTRO, sound, MAX_SOUND_LENGTH, boss))
		return Plugin_Continue;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && !IsFakeClient(client) && FF2_GetBossIndex(client)<0)
			EmitSoundToClient(client, sound);
	}
	return Plugin_Continue;
}

public void SoulChange(int boss, const char[] ability_name, bool change, bool timer)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	if(!IsPlayerAlive(client))
		return;

	int count, i, a;
	static int classes[MAX_WEAPONS];
	TFClassType class = TFClass_Unknown;
	static char format[MAX_MODEL_LENGTH], list[MAX_WEAPONS][16];
	if(change)
	{
		FF2_GetArgNamedS(boss, this_plugin_name, ability_name, "classes", format, MAX_MODEL_LENGTH);
		count = ExplodeString(format, ";", list, MAX_WEAPONS, 16);
		if(count)
		{
			a = count;
			for(; i<count && i<MAX_WEAPONS; i++)
			{
				class = view_as<TFClassType>(StringToInt(list[i]));
				if(class == TFClass_Unknown)
				{
					class = TF2_GetClass(list[i]);
					if(class == TFClass_Unknown)
					{
						a--;
						continue;
					}
				}

				classes[i] = view_as<int>(class);
			}

			if(a > 0)
				class = view_as<TFClassType>(classes[GetRandomInt(0, a-1)]);
		}
	}

	if(timer && FF2_HasAbility(boss, this_plugin_name, BLITZSOUL))
	{
		float duration = GetArgF(boss, ability_name, "duration", 0.0, 0);
		if(duration > 0)
			CreateTimer(duration, Timer_ResetSoul, boss, TIMER_FLAG_NO_MAPCHANGE);
	}

	if(class == TFClass_Unknown)
	{
		class = TF2_GetPlayerClass(client);
	}
	else
	{
		NullRockets(client);
		TF2_SetPlayerClass(client, class, false, false);
		Format(format, MAX_MODEL_LENGTH, "%s model", ClassName[class]);
		FF2_GetArgNamedS(boss, this_plugin_name, ability_name, format, format, MAX_MODEL_LENGTH);
		if(FileExists(format, true) && (IsModelPrecached(format) || PrecacheModel(format)))
		{
			SetVariantString(format);
			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		}
	}

	int weapon;
	bool allclass;
	static char prefix[16], attr[MAX_ATTRIBUTE_LENGTH], name[MAX_CLASSNAME_LENGTH];
	TF2_RemoveAllWeapons(client);
	for(i=1; i<8; i++)
	{
		count = 0;
		allclass = false;
		for(a=1; a<MAX_WEAPONS; a++)
		{
			Format(format, MAX_MODEL_LENGTH, "%s name %i %i", ClassName[class], i, a);
			FF2_GetArgNamedS(boss, this_plugin_name, ability_name, format, format, MAX_MODEL_LENGTH);
			if(format[0] != '\0')
				classes[count++] = a;
		}

		if(!count)
		{
			allclass = true;
			for(a=1; a<MAX_WEAPONS; a++)
			{
				Format(format, MAX_MODEL_LENGTH, "name %i %i", i, a);
				FF2_GetArgNamedS(boss, this_plugin_name, ability_name, format, format, MAX_MODEL_LENGTH);
				if(format[0] != '\0')
				classes[count++] = a;
			}

			if(!count)
				continue;
		}

		a = classes[GetRandomInt(0, count-1)];
		if(allclass)
		{
			strcopy(prefix, 16, "");
		}
		else
		{
			Format(prefix, 16, "%s ", ClassName[class]);
		}
		Format(format, MAX_MODEL_LENGTH, "%sname %i %i", prefix, i, a);
		FF2_GetArgNamedS(boss, this_plugin_name, ability_name, format, name, MAX_CLASSNAME_LENGTH);
		Format(format, MAX_MODEL_LENGTH, "%sindex %i %i", prefix, i, a);
		count = RoundFloat(GetArgF(boss, ability_name, format, -1.0, 1));
		Format(format, MAX_MODEL_LENGTH, "%sattr %i %i", prefix, i, a);
		FF2_GetArgNamedS(boss, this_plugin_name, ability_name, format, attr, MAX_ATTRIBUTE_LENGTH);

		weapon = SpawnWeapon(client, name, count, Diff.Level[boss]>0 ? Diff.Level[boss]*GetRandomInt(1, 10) : 101, 14, attr, false, boss, ability_name, format);
		if(weapon == -1)
			continue;

		Format(format, MAX_MODEL_LENGTH, "%sclip %i %i", prefix, i, a);
		count = RoundFloat(GetArgF(boss, ability_name, format, -1.0, 0));
		Format(format, MAX_MODEL_LENGTH, "%sammo %i %i", prefix, i, a);
		FF2_SetAmmo(client, weapon, RoundFloat(GetArgF(boss, ability_name, format, -1.0, 0)), count);
	}
}

public void DiffSetup(int boss)
{
	if(Diff.Enabled < 1)
		Diff.Hud = CreateHudSynchronizer();

	Diff.Enabled = 1;
	Diff.HudAt = 0.0;
	static char map[MAX_MAP_LENGTH];
	GetCurrentMap(map, MAX_MAP_LENGTH);
	float level = GetArgF(boss, BLITZDIFF, map, -9999.0, 0);
	if(level == -9999)
		level = GetArgF(boss, BLITZDIFF, "start", 3.0, 0);

	if(level <= 0)
	{
		int max = FF2_GetBossMaxLives(boss);
		if(max > 7)
		{
			Diff.Level[boss] = GetRandomInt(1, 9);
		}
		else
		{
			Diff.Level[boss] = GetRandomInt(max+1, 10)-max;
		}
	}
	else if(level < 1)
	{
		Diff.Level[boss] = 1;
		while(GetRandomFloat(0.0, 1.0)<level && Diff.Level[boss]<10)
		{
			Diff.Level[boss]++;
		}
	}
	else
	{
		Diff.Level[boss] = RoundFloat(level);
	}
}

public Action Timer_ResetSoul(Handle timer, int boss)
{
	if(FF2_GetRoundState() != 1)
		return Plugin_Continue;

	SoulChange(boss, BLITZSOUL, false, false);
	return Plugin_Continue;
}

public void NullRockets(int client)
{
	Bounce.Owned[client] = 0;
	int entity = -1;
	while((entity=FindEntityByClassname2(entity, "tf_projectile*")) != -1)
	{
		if(client == GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))
			RemoveEntity(entity);
	}
}

public bool LoadPhrases(int boss)
{
	if(Enabled)
		return true;

	Enabled = true;
	if(FF2_HasAbility(boss, this_plugin_name, BLITZPHRASES))
	{
		char phrase[MAX_TRANS_LENGTH];
		FF2_GetArgNamedS(boss, this_plugin_name, BLITZPHRASES, "file", phrase, MAX_TRANS_LENGTH);
		if(phrase[0] != '\0')
		{
			LoadTranslations(phrase);
			for(int i; i<sizeof(Phrases); i++)
			{
				if(!TranslationPhraseExists(Phrases[i]))
				{
					if(Enabled)
					{
						FF2_LogError("[Boss] Boss has %s and is missing the following phrases in %s.txt", BLITZPHRASES, phrase);
						Enabled = false;
					}
					FF2_LogError("[Boss] %s", Phrases[i]);
				}
			}

			if(!Enabled)
			{
				Enabled = true;
				PrintToChatAll("This boss has a bug with it's text files!");
				PrintToChatAll("Please try to avoid picking this boss and tell an admin!");
				ForceTeamWin(0);
				return false;
			}
			return true;
		}
	}
	LoadTranslations("dmedic.phrases");
	return true;
}

public Action Timer_Unload(Handle timer, int team)
{
	if(Timer.Enabled)
	{	
		ServerCommand("sm plugins load roundtimer");
		if(FF2Countdown > 0)
			SetConVarInt(FindConVar("ff2_countdown_players"), FF2Countdown);
	}

	int entity;
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;

		if(FF2_GetBossIndex(client) >= 0)
		{
			TF2_AddCondition(client, TFCond_RestrictToMelee, 12.0);
			entity = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
			if(entity > MaxClients)
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", entity);
		}
		else if(MannUp.Enabled)
		{
			EmitSoundToClient(client, GetClientTeam(client)==team ? MannUp.WinSound : MannUp.LoseSound);
		}
	}
	ServerCommand("sm plugins reload freaks/%s.ff2", this_plugin_name);
	return Plugin_Continue;
}

public float GetArgF(int boss, const char[] abilityName, const char[] argName, float defaultValue, int valueCheck)
{
	static char buffer[2048];
	FF2_GetArgNamedS(boss, this_plugin_name, abilityName, argName, buffer, 1024);

	if(strlen(buffer))
	{
		float value = ParseFormula(boss, buffer, defaultValue, abilityName, argName, valueCheck);
		return value; 
	}
	else if((valueCheck==1 && defaultValue<0) || (valueCheck==2 && defaultValue<=0))
	{
		FF2_LogError("[Boss] Formula at %s for %s is not allowed to be blank.", argName, abilityName);
		return 0.0;
	}
	return defaultValue;
}

// SDKHooks

public void OnProjectileSpawned(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(!IsValidClient(client))
		return;

	int boss = FF2_GetBossIndex(client);
	if(boss < 0)
		return;

	Queue.Rockets++;
	if(!FF2_HasAbility(boss, this_plugin_name, BLITZBOUNCE))
		return;

	int i = RoundFloat(GetArgF(boss, BLITZBOUNCE, "limit", 250.0, 0));
	if(i>0 && Bounce.Owned[client]>=i)
	{
		i = -1;
		while((i=FindEntityByClassname2(i, "tf_projectile*")) != -1)
		{
			if(i!=entity && client==GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"))
			{
				RemoveEntity(i);
				Bounce.Owned[client]--;
				break;
			}
		}
	}

	float bounces = GetArgF(boss, BLITZBOUNCE, "bounces", 2.0, 1);
	if(bounces <= 0)
	{
		while(GetRandomInt(0, 1))
		{
			bounces++;
		}
		if(bounces <= 0)
			return;
	}
	else if(bounces < 1)
	{
		client = 0;
		while(GetRandomFloat(0.0, 1.0) < bounces)
		{
			client++;
		}
		bounces = float(client);
	}

	Bounce.Owned[client]++;
	Bounce.Owner[entity] = client;
	SetEntProp(entity, Prop_Data, "m_iHammerID", RoundToCeil(bounces));
	SDKHook(entity, SDKHook_StartTouch, Bounce_StartTouch);
}

public Action Bounce_StartTouch(int entity, int other)
{
	if(IsValidClient(other))
	{
		Bounce.Owned[Bounce.Owner[entity]]--;
		return Plugin_Continue;
	}

	int bounces = GetEntProp(entity, Prop_Data, "m_iHammerID");
	if(bounces < 1)
	{
		Bounce.Owned[Bounce.Owner[entity]]--;
		return Plugin_Continue;
	}

	static char classname[MAX_CLASSNAME_LENGTH];
	if(GetEntityClassname(other, classname, MAX_CLASSNAME_LENGTH) && !strncmp(classname, "obj_", 4, false))
	{
		Bounce.Owned[Bounce.Owner[entity]]--;
		return Plugin_Continue;
	}

	SDKHook(entity, SDKHook_Touch, Bounce_Touch);
	return Plugin_Handled;
}

public Action Bounce_Touch(int entity, int other)
{
	static float vOrigin[3], vAngles[3], vVelocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vVelocity);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceRayDontHitSelf, entity);
	if(!TR_DidHit(trace))
	{
		trace.Close();
		Bounce.Owned[Bounce.Owner[entity]]--;
		return Plugin_Continue;
	}

	static float vNormal[3];
	TR_GetPlaneNormal(trace, vNormal);
	trace.Close();

	float dotProduct = GetVectorDotProduct(vNormal, vVelocity);
	ScaleVector(vNormal, dotProduct);
	ScaleVector(vNormal, 2.0);

	static float vBounceVec[3];
	SubtractVectors(vVelocity, vNormal, vBounceVec);
	GetVectorAngles(vBounceVec, vAngles);
	TeleportEntity(entity, NULL_VECTOR, vAngles, vBounceVec);

	SetEntProp(entity, Prop_Data, "m_iHammerID", GetEntProp(entity, Prop_Data, "m_iHammerID")-1);
	SDKUnhook(entity, SDKHook_Touch, Bounce_Touch);
	return Plugin_Handled;
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return (entity != data);
}

// Stocks

stock int AttachParticle(int entity, char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");

	char targetName[128];
	float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[2] += offset;
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
	int entity = EntRefToEntIndex(entid);
	if(IsValidEntity(entity) && entity>MaxClients)
		RemoveEntity(entity);
}

stock void ForceTeamWin(int team)
{
	int entity = FindEntityByClassname2(-1, "team_control_point_master");
	if(!IsValidEntity(entity))
	{
		entity = CreateEntityByName("team_control_point_master");
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "Enable");
	}
	SetVariantInt(team);
	AcceptEntityInput(entity, "SetWinner");
}

stock void SetCondition(int client, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if(count <= 0)
		return;

	for(int i=0; i<count; i+=2)
	{
		TF2_AddCondition(client, view_as<TFCond>(StringToInt(conds[i])), StringToFloat(conds[i+1]));
	}
}

stock void RemoveCondition(int client, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if(count <= 0)
		return;

	for(int i=0; i<count; i+=2)
	{
		TF2_RemoveCondition(client, view_as<TFCond>(StringToInt(conds[i])));
	}
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;

	if(!IsClientInGame(client))
		return false;

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}

stock bool IsBoss(int client)
{
	if(!IsValidClient(client))
		return false;

	return FF2_GetBossIndex(client)>=0;
}

stock bool IsInvuln(int client)
{
	if(!IsValidClient(client))
		return true;

	return (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode) ||
		!GetEntProp(client, Prop_Data, "m_takedamage"));
}

stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	while(startEnt>-1 && !IsValidEntity(startEnt))
	{
		startEnt--;
	}
	return FindEntityByClassname(startEnt, classname);
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int qual, const char[] att, bool perserve, int boss, const char[] abilityName, const char[] argName)
{
	if(StrEqual(name, "saxxy", false))	// if "saxxy" is specified as the name, replace with appropiate name
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_bat");
			case TFClass_Pyro:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_fireaxe");
			case TFClass_DemoMan:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_bottle");
			case TFClass_Heavy:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_fists");
			case TFClass_Engineer:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_wrench");
			case TFClass_Medic:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_bonesaw");
			case TFClass_Sniper:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_club");
			case TFClass_Spy:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_knife");
			default:		strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_shovel");
		}
	}
	else if(StrEqual(name, "tf_weapon_shotgun", false))	// If using tf_weapon_shotgun for Soldier/Pyro/Heavy/Engineer
	{
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Pyro:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_shotgun_pyro");
			case TFClass_Heavy:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_shotgun_hwg");
			case TFClass_Engineer:	strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_shotgun_primary");
			default:		strcopy(name, MAX_CLASSNAME_LENGTH, "tf_weapon_shotgun_soldier");
		}
	}

	Handle hWeapon;
	if(perserve)
	{
		hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);
	}
	else
	{
		hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	}

	if(hWeapon == INVALID_HANDLE)
		return -1;

	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	static char atts[32][128];
	int count = ExplodeString(att, ";", atts, 32, 32);

	if(count % 2)
		--count;

	if(count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2;
		for(int i; i<count; i+=2)
		{
			int attrib = StringToInt(atts[i]);
			if(!attrib)
			{
				FF2_LogError("[Boss] Bad weapon attribute passed: %s ; %s", atts[i], atts[i+1]);
				CloseHandle(hWeapon);
				return -1;
			}

			TF2Items_SetAttribute(hWeapon, i2, attrib, ParseFormula(boss, atts[i+1], 0.0, abilityName, argName, 0));
			i2++;
		}
	}
	else
	{
		TF2Items_SetNumAttributes(hWeapon, 0);
	}

	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;
	if(entity == -1)
		return -1;

	EquipPlayerWeapon(client, entity);
	SetEntProp(entity, Prop_Send, "m_bValidatedAttachedEntity", 1);
	return entity;
}


stock void Operate(ArrayList sumArray, int &bracket, float value, ArrayList _operator)
{
	float sum = sumArray.Get(bracket);
	switch(_operator.Get(bracket))
	{
		case Operator_Add:
		{
			sumArray.Set(bracket, sum+value);
		}
		case Operator_Subtract:
		{
			sumArray.Set(bracket, sum-value);
		}
		case Operator_Multiply:
		{
			sumArray.Set(bracket, sum*value);
		}
		case Operator_Divide:
		{
			if(!value)
			{
				FF2_LogError("[Boss] Detected a divide by 0 in a boss with %s!", this_plugin_name);
				bracket = 0;
				return;
			}
			sumArray.Set(bracket, sum/value);
		}
		case Operator_Exponent:
		{
			sumArray.Set(bracket, Pow(sum, value));
		}
		default:
		{
			sumArray.Set(bracket, value);  //This means we're dealing with a constant
		}
	}
	_operator.Set(bracket, Operator_None);
}

stock void OperateString(ArrayList sumArray, int &bracket, char[] value, int size, ArrayList _operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

public float ParseFormula(int boss, const char[] key, float defaultValue, const char[] abilityName, const char[] argName, int valueCheck)
{
	static char formula[2048];
	strcopy(formula, sizeof(formula), key);
	int size = 1;
	int matchingBrackets;
	for(int i; i<=strlen(formula); i++)  //Resize the arrays once so we don't have to worry about it later on
	{
		if(formula[i] == '(')
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
		else if(formula[i] == ')')
		{
			matchingBrackets++;
		}
	}

	ArrayList sumArray=CreateArray(_, size), _operator=CreateArray(_, size);
	int bracket;
	sumArray.Set(0, 0.0);
	_operator.Set(bracket, Operator_None);

	char character[2], value[16];
	for(int i; i<=strlen(formula); i++)
	{
		character[0] = formula[i];
		switch(character[0])
		{
			case ' ', '\t':
			{
				continue;
			}
			case '(':
			{
				bracket++;
				sumArray.Set(bracket, 0.0);
				_operator.Set(bracket, Operator_None);
			}
			case ')':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				if(_operator.Get(bracket) != Operator_None)
				{
					FF2_LogError("[Boss] Formula at %s for %s has an invalid operator at character %i", argName, abilityName, i+1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				if(--bracket < 0)
				{
					FF2_LogError("[Boss] Formula at %s for %s has an unbalanced parentheses at character %i", argName, abilityName, i+1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				Operate(sumArray, bracket, sumArray.Get(bracket+1), _operator);
			}
			case '\0':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
			}
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.':
			{
				StrCat(value, sizeof(value), character);
			}
			case 'n', 'x':	// Players Total
			{
				Operate(sumArray, bracket, float(TotalPlayers), _operator);
			}
			case 'a', 'y':	// Player Alive
			{
				Operate(sumArray, bracket, float(Players), _operator);
			}
			case 't':	// Time Left of Wave
			{
				if(Timer.Enabled)
				{
					Operate(sumArray, bracket, Timer.Next-GetEngineTime(), _operator);
				}
				else
				{
					Operate(sumArray, bracket, 0.0, _operator);
				}
			}
			case 'w':	// Current Wave
			{
				if(Timer.Enabled)
				{
					Operate(sumArray, bracket, float(Timer.Wave), _operator);
				}
				else
				{
					Operate(sumArray, bracket, 0.0, _operator);
				}
			}
			case 'h':	// Current Health
			{
				Operate(sumArray, bracket, float(FF2_GetBossHealth(boss)), _operator);
			}
			case 'm':	// Max Health
			{
				Operate(sumArray, bracket, float(FF2_GetBossMaxHealth(boss)*FF2_GetBossMaxLives(boss)), _operator);
			}
			case 'l':	// Current Lives
			{
				Operate(sumArray, bracket, float(FF2_GetBossLives(boss)), _operator);
			}
			case 'r':	// Random Number
			{
				Operate(sumArray, bracket, GetRandomFloat(0.0, 1.0), _operator);
			}
			case 'd', 'z':	// Difficulty
			{
				Operate(sumArray, bracket, float(Diff.Level[boss]), _operator);
			}
			case '+', '-', '*', '/', '^':
			{
				OperateString(sumArray, bracket, value, sizeof(value), _operator);
				switch(character[0])
				{
					case '+':
						_operator.Set(bracket, Operator_Add);

					case '-':
						_operator.Set(bracket, Operator_Subtract);

					case '*':
						_operator.Set(bracket, Operator_Multiply);

					case '/':
						_operator.Set(bracket, Operator_Divide);

					case '^':
						_operator.Set(bracket, Operator_Exponent);
				}
			}
		}
	}

	float result = sumArray.Get(0);
	delete sumArray;
	delete _operator;
	if((valueCheck==1 && result<0) || (valueCheck==2 && result<=0))
	{
		FF2_LogError("[Boss] An invalid formula at %s for %s!", argName, abilityName);
		return defaultValue;
	}
	return result;
}

stock float MathRatio(float amount, float ratio, float max)
{
	return amount*(ratio-max)/max*-1.0;
}

stock float MathWhack(float victim, float attacker, float attackerMax, float bonus, float min, float max)
{
	if(victim < min)
	{
		victim = min;
		return 101.0;
	}

	if(victim > max+min)
		victim = max+min;

	if(attacker > attackerMax)
		attacker = attackerMax;

	return MathRatio(100.0, victim-min, max) + MathRatio(bonus, attacker, attackerMax);
}

// Backward Complability Stocks

stock void EmitVoiceToAll(const char[] sample, int entity=SOUND_FROM_PLAYER)
{
	EmitSoundToAll(sample, entity);
}

int FF2_GetArgI(int boss, const char[] pl_name, const char[] ab_name, const char[] key_name, int num, int def_value = 0)
{
	int val = FF2_GetArgNamedI(boss, pl_name, ab_name, key_name, -999);
	return val == -999 ? FF2_GetAbilityArgument(boss, pl_name, ab_name, num, def_value):val;
}

#file "FF2 Subplugin: The Blitzkrieg Returns"