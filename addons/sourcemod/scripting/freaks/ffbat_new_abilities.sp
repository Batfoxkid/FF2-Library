#pragma semicolon 1

#define FF2_USING_AUTO_PLUGIN__OLD

#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <tf2items>
#include <tf2attributes>
#include <freak_fortress_2>

#pragma newdecls required

#define MAJOR_REVISION	"1"
#define MINOR_REVISION	"0"
#define STABLE_REVISION	"0"
#define PLUGIN_VERSION MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define FAR_FUTURE		100000000.0
#define MAX_SOUND_LENGTH	80
#define MAX_MODEL_LENGTH	128
#define MAX_MATERIAL_LENGTH	128
#define MAX_ENTITY_LENGTH	48
#define MAX_EFFECT_LENGTH	48
#define MAX_ATTACHMENT_LENGTH	48
#define MAX_ICON_LENGTH		48
#define HEX_OR_DEC_LENGTH	12
#define MAX_ATTRIBUTE_LENGTH	256
#define MAX_CONDITION_LENGTH	256
#define MAX_CLASSNAME_LENGTH	64
#define MAX_BOSSNAME_LENGTH	64
#define MAX_ABILITY_LENGTH	64
#define MAX_PLUGIN_LENGTH	64
#define MAX_ITEM_LENGTH		48
#define MAX_HUD_LENGTH		192
#define MAX_CLIENT_LENGTH	80
#define MAXTF2PLAYERS		36
#define MAXENTITIES		2048

float OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };

enum Operators
{
	Operator_None = 0,
	Operator_Add,
	Operator_Subtract,
	Operator_Multiply,
	Operator_Divide,
	Operator_Exponent,
};

Handle SDKEquipWearable;

bool G_BlockSuicide[MAXTF2PLAYERS];
bool G_BlockPickups[MAXTF2PLAYERS];

FF2GameMode ff2_gm;

public Plugin myinfo =
{
	name		=	"Freak Fortress 2: New Abilities",
	author		=	"Batfoxkid",
	description	=	"Abilities for new bosses",
	version		=	PLUGIN_VERSION
};

/*
	Main Events
*/

public void OnPluginStart2()
{
	HookEvent("teamplay_round_start", OnRoundSetup, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", _OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_Post);
	HookEvent("teamplay_broadcast_audio", OnBroadcast, EventHookMode_Pre);
	HookEvent("teamplay_point_captured", OnCapturePoint, EventHookMode_PostNoCopy);

	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_flag_event", OnFlagEvent, EventHookMode_Pre);
	HookEvent("revive_player_complete", OnRevive);

	AddCommandListener(OnSuicide, "explode");
	AddCommandListener(OnSuicide, "kill");
	AddCommandListener(OnSuicide, "spectate");
	AddCommandListener(OnSuicide, "jointeam");
	AddCommandListener(OnSuicide, "autoteam");
	AddCommandListener(OnRage, "voicemenu");
	AddCommandListener(OnTaunt, "taunt"); 
	AddCommandListener(OnTaunt, "+taunt");

	GameData gameData = new GameData("equipwearable");
	if(gameData == INVALID_HANDLE)
	{
		FF2_LogError("[Gamedata] Failed to find equipwearable.txt");
	}
	else
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "CBasePlayer::EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		SDKEquipWearable = EndPrepSDKCall();
		if(SDKEquipWearable == null)
			FF2_LogError("[Gamedata] Failed to create call: CBasePlayer::EquipWearable");
	}
	delete gameData;

	PrecacheAbilities();

	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;

		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	}

	if(FF2_GetRoundState() == 1)
		_OnRoundStart(view_as<Event>(INVALID_HANDLE), "plugin_lateload", false);
}

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void OnPluginEnd()
{
	OnRoundEnd(view_as<Event>(INVALID_HANDLE), "plugin_end", false);
}

public Action OnSuicide(int client, const char[] command, int args)
{
	return G_BlockSuicide[client] ? Plugin_Handled : Plugin_Continue;
}

public void OnItemSpawned(int entity)
{
	SDKHook(entity, SDKHook_StartTouch, OnPickup);
	SDKHook(entity, SDKHook_Touch, OnPickup);
}

public Action OnPickup(int entity, int client)
{
	if(!IsValidClient(client))
		return Plugin_Continue;

	return G_BlockPickups[client] ? Plugin_Handled : Plugin_Continue;
}

/*
	Stocks
*/

stock int AttachParticle(int entity, char[] particleType, float offset=0.0, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");

	char targetName[128];
	static float position[3];
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

stock int TF2_CreateAndEquipWearable(int client, const char[] classname, int index, int level, int quality, char[] attributes)
{
	int wearable = CreateEntityByName(classname);
	if(!IsValidEntity(wearable))
		return -1;

	SetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex", index);
	SetEntProp(wearable, Prop_Send, "m_bInitialized", 1);
		
	// Allow quality / level override by updating through the offset.
	static char netClass[64];
	GetEntityNetClass(wearable, netClass, sizeof(netClass));
	SetEntData(wearable, FindSendPropInfo(netClass, "m_iEntityQuality"), quality);
	SetEntData(wearable, FindSendPropInfo(netClass, "m_iEntityLevel"), level);

	SetEntProp(wearable, Prop_Send, "m_iEntityQuality", quality);
	SetEntProp(wearable, Prop_Send, "m_iEntityLevel", level);

	if(attributes[0])
	{
		char atts[32][32];
		int count = ExplodeString(attributes, " ; ", atts, 32, 32);
		if(count > 1)
		{
			for(int i; i<count; i+=2)
			{
				TF2Attrib_SetByDefIndex(wearable, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			}
		}
	}
		
	DispatchSpawn(wearable);
	if(SDKEquipWearable != null)
		SDKCall(SDKEquipWearable, client, wearable);

	return wearable;
}

// Credits to frigram
stock void TE_Particle(const char[] Name, float origin[3]=NULL_VECTOR, float start[3]=NULL_VECTOR, float angles[3]=NULL_VECTOR, int entindex=-1, int attachtype=-1, int attachpoint=-1, bool resetParticles=true, int customcolors=0, float color1[3]=NULL_VECTOR, float color2[3]=NULL_VECTOR, int controlpoint=-1, int controlpointattachment=-1, float controlpointoffset[3]=NULL_VECTOR, float delay=0.0)
{
	// find string table
	int tblidx = FindStringTable("ParticleEffectNames");
	if(tblidx == INVALID_STRING_TABLE)
	{
		FF2_LogError("[Plugin] Could not find string table: ParticleEffectNames");
		return;
	}

	// find particle index
	static char tmp[256];
	int count = GetStringTableNumStrings(tblidx);
	int stridx = INVALID_STRING_INDEX;
	for(int i; i<count; i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if(StrEqual(tmp, Name, false))
		{
			stridx = i;
			break;
		}
	}

	if(stridx == INVALID_STRING_INDEX)
	{
		FF2_LogError("[Boss] Could not find particle: %s", Name);
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

	if(entindex != -1)
		TE_WriteNum("entindex", entindex);

	if(attachtype != -1)
		TE_WriteNum("m_iAttachType", attachtype);

	if(attachpoint != -1)
		TE_WriteNum("m_iAttachmentPointIndex", attachpoint);

	TE_WriteNum("m_bResetParticles", resetParticles ? 1:0);
	if(customcolors)
	{
		TE_WriteNum("m_bCustomColors", customcolors);
		TE_WriteVector("m_CustomColors.m_vecColor1", color1);
		if(customcolors == 2)
			TE_WriteVector("m_CustomColors.m_vecColor2", color2);
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

stock bool ShowGameText(int client=0, const char[] icon="leaderboard_streak", int color=0, const char[] buffer, any ...)
{
	BfWrite bf;
	if(client)
	{
		bf = view_as<BfWrite>(StartMessageOne("HudNotifyCustom", client));
	}
	else
	{
		bf = view_as<BfWrite>(StartMessageAll("HudNotifyCustom"));
	}

	if(bf == null)
		return false;

	static char message[512];
	SetGlobalTransTarget(client);
	VFormat(message, sizeof(message), buffer, 5);
	ReplaceString(message, sizeof(message), "\n", "");

	bf.WriteString(message);
	bf.WriteString(icon);
	bf.WriteByte(color);
	EndMessage();
	return true;
}

stock int GetHealingTarget(int client, bool checkgun=false)
{
	int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if(!checkgun)
	{
		if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
			return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");

		return -1;
	}

	if(IsValidEntity(medigun))
	{
		static char classname[64];
		GetEntityClassname(medigun, classname, sizeof(classname));
		if(StrEqual(classname, "tf_weapon_medigun", false))
		{
			if(GetEntProp(medigun, Prop_Send, "m_bHealing"))
				return GetEntPropEnt(medigun, Prop_Send, "m_hHealingTarget");
		}
	}
	return -1;
}

stock void RandomlyDisguise(int client)	//Original code was mecha's, but the original code is broken and this uses a better method now.
{
	int disguiseTarget = -1;
	int team = GetClientTeam(client) == VSH2Team_Boss ? VSH2Team_Boss:VSH2Team_Red;

	ArrayList disguiseArray = new ArrayList();
	for(int clientcheck=1; clientcheck<=MaxClients; clientcheck++)
	{
		if(IsValidClient(clientcheck) && GetClientTeam(clientcheck)==team && clientcheck!=client)
			disguiseArray.Push(clientcheck);
	}

	if(disguiseArray.Length < 1)
	{
		disguiseTarget = client;
	}
	else
	{
		disguiseTarget = disguiseArray.Get(GetRandomInt(0, disguiseArray.Length-1));
		if(!IsValidClient(disguiseTarget))
			disguiseTarget = client;
	}
	delete disguiseArray;

	if(TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		TF2_DisguisePlayer(client, view_as<TFTeam>(team), TF2_GetPlayerClass(disguiseTarget), disguiseTarget);
	}
	else
	{
		TF2_AddCondition(client, TFCond_Disguised, -1.0);
		SetEntProp(client, Prop_Send, "m_nDisguiseTeam", team);
		SetEntProp(client, Prop_Send, "m_nDisguiseClass", view_as<int>(TF2_GetPlayerClass(disguiseTarget)));
		SetEntProp(client, Prop_Send, "m_iDisguiseTargetIndex", disguiseTarget);
		SetEntProp(client, Prop_Send, "m_iDisguiseHealth", 200);
	}
}

stock bool TF2_IsSlotClassname(int iClient, int iSlot, const char[] sClassname)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients && IsValidEdict(iWeapon))
	{
		char sClassname2[32];
		GetEdictClassname(iWeapon, sClassname2, sizeof(sClassname2));
		if (StrEqual(sClassname, sClassname2))
			return true;
	}
	
	return false;
}

stock bool ConfigureWorldModelOverride(int entity, const char[] model, bool wearable=false)
{
	if(!FileExists(model, true))
		return false;

	int modelIndex = PrecacheModel(model);
	SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", modelIndex, _, 0);
	SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", modelIndex, _, 1);
	SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", modelIndex, _, 2);
	SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", modelIndex, _, 3);
	SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", (wearable ? GetEntProp(entity, Prop_Send, "m_nModelIndex") : GetEntProp(entity, Prop_Send, "m_iWorldModelIndex")), _, 0);
	return true;
}

public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR); // send it away first in case it feels like dying dramatically
		AcceptEntityInput(entity, "Kill");
	}
}

stock int FindEntityByClassname2(int startEnt, const char[] classname)
{
	while(startEnt>-1 && !IsValidEntity(startEnt))
	{
		startEnt--;
	}
	return FindEntityByClassname(startEnt, classname);
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
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return true;

	return (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode) ||
		!GetEntProp(client, Prop_Data, "m_takedamage"));
}

stock bool IsInvis(int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return true;

	return (TF2_IsPlayerInCondition(client, TFCond_Cloaked) || TF2_IsPlayerInCondition(client, TFCond_Stealthed) || TF2_IsPlayerInCondition(client, TFCond_StealthedUserBuffFade));
}

static void Operate(ArrayList sumArray, int &bracket, float value, ArrayList _operator)
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

static void OperateString(ArrayList sumArray, int &bracket, char[] value, int size, ArrayList _operator)
{
	if(!StrEqual(value, ""))  //Make sure 'value' isn't blank
	{
		Operate(sumArray, bracket, StringToFloat(value), _operator);
		strcopy(value, size, "");
	}
}

stock float ParseFormula(int boss, const char[] key, float defaultValue, const char[] abilityName, const char[] argName, int argNumber, int valueCheck)
{
	static char formula[1024];
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
					FF2_LogError("[Boss] Formula at arg%i/%s for %s has an invalid operator at character %i", argNumber, argName, abilityName, i+1);
					delete sumArray;
					delete _operator;
					return defaultValue;
				}

				if(--bracket < 0)
				{
					FF2_LogError("[Boss] Formula at arg%i/%s for %s has an unbalanced parentheses at character %i", argNumber, argName, abilityName, i+1);
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
			case 'n', 'x':
			{
				Operate(sumArray, bracket, float(CountPlayers()), _operator);
			}
			case 'a', 'y':
			{
				Operate(sumArray, bracket, float(CountPlayers(true)), _operator);
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
		FF2_LogError("[Boss] An invalid formula at arg%i/%s for %s!", argNumber, argName, abilityName);
		return defaultValue;
	}
	return result;
}

/*
	Backward Complability Stocks
*/

stock float GetArgF(int boss, const char[] abilityName, const char[] argName, int argNumber, float defaultValue, int valueCheck)
{
	static char buffer[1024];
	FF2Player player = FF2Player(boss, true);
	if(!player.GetArgS(this_plugin_name, abilityName, argName, buffer, sizeof(buffer)))
		FF2_GetAbilityArgumentString(boss, this_plugin_name, abilityName, argNumber, buffer, sizeof(buffer));

	if(buffer[0])
	{
		float value = ParseFormula(boss, buffer, defaultValue, abilityName, argName, argNumber, valueCheck);
		return value; 
	}
	else if((valueCheck==1 && defaultValue<0) || (valueCheck==2 && defaultValue<=0))
	{
		FF2_LogError("[Boss] Formula at arg%i/%s for %s is not allowed to be blank.", argNumber, argName, abilityName);
		return 0.0;
	}
	return defaultValue;
}

stock int GetArgI(int boss, const char[] abilityName, const char[] argName, int argNumber, int defaultValue=0)
{
	FF2Player player = FF2Player(boss, true);
	int val = player.GetArgI(this_plugin_name, abilityName, argName, -999);
	return val == -999 ? FF2_GetAbilityArgument(boss, this_plugin_name, abilityName, argNumber, defaultValue):val;
}

stock int GetArgS(int boss, const char[] ability_name, const char[] argument, int index, char[] buffer, int bufferLength)
{
	FF2Player player = FF2Player(boss, true);
	if(!player.GetArgS(this_plugin_name, ability_name, argument, buffer, bufferLength))
		FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, index, buffer, bufferLength);
	
	return strlen(buffer);
}

stock bool GetBossName(int boss=0, char[] buffer, int bufferLength, int bossMeaning=0)
{
	return FF2_GetBossSpecial(boss, buffer, bufferLength, bossMeaning);
}

stock void EmitVoiceToAll(const char[] sample, int entity=SOUND_FROM_PLAYER, int channel=SNDCHAN_AUTO, int level=SNDLEVEL_NORMAL)
{
	EmitSoundToAll(sample, entity, channel, level);
}

stock int SpawnWeapon(int client, char[] name, int index, int level, int qual, char[] att, bool visible=true)
{
	int weapon = FF2Player(client).SpawnWeapon(name, index, level, qual, att);
	if(visible)
	{
		SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", 1);
	}
	else
	{
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntPropFloat(weapon, Prop_Send, "m_flModelScale", 0.001);
	}
	return weapon;
}

/*
	Modules
*/

#include "characters_new/gray.sp"

/*
	Other Events
*/

void PrecacheAbilities()
{
	GMS_Precache();
}

public void OnRoundSetup(Event event, const char[] name, bool dontBroadcast)
{
	GMS_Clean();
}

public void _OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int boss;
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;

		boss = FF2_GetBossIndex(client);
		if(boss < 0)
			continue;

		if(FF2_HasAbility(boss, this_plugin_name, GMA_NAME))
			GMA_Setup(client, boss);

		if(FF2_HasAbility(boss, this_plugin_name, GME_NAME))
			GME_Setup(client, boss);

		if(FF2_HasAbility(boss, this_plugin_name, GMR_NAME))
			GMR_Setup(client, boss);
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	GME_Clean(event ? view_as<TFTeam>(event.GetInt("team")):view_as<TFTeam>(VSH2Team_Boss));
	GMR_Clean();

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
			OnClientDisconnect(client);
	}
}

public Action OnBroadcast(Event event, const char[] name, bool dontBroadcast)
{
	return GME_Broadcast(event);
}

public void OnCapturePoint(Event event, const char[] name, bool dontBroadcast)
{
	GMS_PointCapture();
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int client = GetClientOfUserId(event.GetInt("userid"));
	int flags = event.GetInt("death_flags");

	GME_Death(client, flags);
	GMS_Death(client, flags, false);
	GMR_Death(client, flags, attacker);
	return Plugin_Continue;
}

public Action OnFlagEvent(Event event, const char[] name, bool dontBroadcast)
{
	return GMS_Flag(event.GetInt("player"), event.GetInt("eventtype"));
}

public void OnRevive(Event event, const char[] name, bool dontBroadcast)
{
	GMR_Revive(event.GetInt("entindex"));
}

public void OnGameFrame()
{
	GMS_TeleFrame();
}

public void OnClientDisconnect(int client)
{
	G_BlockSuicide[client] = false;
	GMS_Death(client, 0, true);
}

public Action OnRage(int client, const char[] command, int args)
{
	static char arg[4];
	GetCmdArg(1, arg, sizeof(arg));
	if(!arg[0] || StringToInt(arg))
		return Plugin_Continue;

	GetCmdArg(2, arg, sizeof(arg));
	if(!arg[0] || StringToInt(arg))
		return Plugin_Continue;

	return GMS_Rage(client);
}

public Action OnTaunt(int client, const char[] command, int args)
{
	GMS_Rage(client);
	return Plugin_Continue;
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	return GMS_OnTakeDamage(client, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
}

public Action OnTakeDamageAlive(int client, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	return GMS_OnTakeDamageAlive(client, attacker, inflictor, damage, damagetype, weapon, damageForce, damagePosition, damagecustom);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(!StrContains(classname, "item_healthkit") || !StrContains(classname, "item_ammopack") || StrEqual(classname, "tf_ammo_pack"))
	{
		SDKHook(entity, SDKHook_Spawn, OnItemSpawned);
	}
	else if(StrEqual(classname, "item_teamflag"))
	{
		SDKHook(entity, SDKHook_Spawn, GMS_FlagSpawn);
	}
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!StrContains(ability_name, GMS_NAME))
		GMS_Ability(boss, ability_name);

	return Plugin_Continue;
}

public Action OnStomp(int attacker, int victim, float &damageMultiplier, float &damageBonus, float &jumpPower)
{
	return GMS_Goomba(victim, damageMultiplier, jumpPower);
}


int CountPlayers(bool alives = false)
{
	int count;
	for(int i = 1; i <= MaxClients; i++)
	if(IsClientInGame(i) && TF2_GetClientTeam(i) > TFTeam_Spectator)
		if(!alives || IsPlayerAlive(i))
			count++;
	return count;
}

//#file "FF2 Subplugin: New Abilities"