#pragma semicolon 1
#define  PREABILITY2
#define PREABILITY2_NOPNAME
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma newdecls required

public Plugin myinfo = 
{
	name="Freedom Abilities",
	description="Adds abilities for bosses to use.",
	version="2.0.0",
	author="WildCard65",
};

enum abilityIndexes
{
	faster_raging = 0,
	ability_dash,
	ability_blaster,
	rage_bulletrain,
	life_sounds,
	charge_truepower,
	ability_dash_ghost,
	charge_tripleparhoming,
	rage_bang,
};

static const char abilities[abilityIndexes][] =
{
	"faster_raging",
	"ability_dash",
	"ability_blaster",
	"rage_bulletrain",
	"life_sounds",
	"charge_truepower",
	"ability_dash_ghost",
	"charge_tripleparhoming",
	"rage_bang",
};

#define MAX_BOSSES 32
#define SET_FLAG(client, flag) FF2_SetFF2flags(client, FF2_GetFF2flags(client) | flag)
#define FLAG_DASH_READY (1<<16)
#define FLAG_DASH_COOLDOWN (1<<17)
#define FLAG_DASH_USE (1<<18)
#define FLAG_TRUEPOWER_USE (1<<19)

int iBlasterAmmo[MAX_BOSSES], iMaxBlasterAmmo[MAX_BOSSES], iBlasterIndex[MAX_BOSSES];
int iRageDamage[MAX_BOSSES];
int iSerpentineBullets[MAX_BOSSES], iDailLazers[MAX_BOSSES], iDailGhosts[MAX_BOSSES];
float fNextShot[MAX_BOSSES], fNextReload[MAX_BOSSES];
float currentTime;
Handle hPowerHud, hDashHud;

void OnPluginStart2()
{
	LoadTranslations("freedom_abilities.phrases");
	hPowerHud = CreateHudSynchronizer();
	hDashHud = CreateHudSynchronizer();
	HookEvent("arena_round_start", RoundStart);
}

void PrepareFlags(int client, int bIndex)
{
	if (FF2_HasAbility(bIndex, this_plugin_name, abilities[ability_dash]))
	{
		if ((FF2_GetFF2flags(client) & FLAG_DASH_USE) == FLAG_DASH_USE)
			FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FLAG_DASH_USE);
		if ((FF2_GetFF2flags(client) & FLAG_DASH_COOLDOWN) == FLAG_DASH_COOLDOWN)
			FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FLAG_DASH_COOLDOWN);
		if ((FF2_GetFF2flags(client) & FLAG_DASH_READY) != FLAG_DASH_READY)
			FF2_SetFF2flags(client, FF2_GetFF2flags(client) | FLAG_DASH_READY);
	}
	if (FF2_HasAbility(bIndex, this_plugin_name, abilities[charge_truepower]) && (FF2_GetFF2flags(client) & FLAG_TRUEPOWER_USE) == FLAG_TRUEPOWER_USE)
		FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FLAG_TRUEPOWER_USE);
}

bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
		return false;
	else if(!IsClientInGame(client))
		return false;
	else if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;
	else if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
			return false;
	return true;
}

int SpawnWeapon(int client, char[] classname, int index, int level, int quality, const char[] attribute = "", bool show = true)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == null)
		return -1;
	TF2Items_SetClassname(hWeapon, classname);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, quality);
	char attributes[32][32];
	int count = ExplodeString(attribute, ";", attributes, 32, 32);
	if (count % 2)
		--count;
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2;
		for(int i; i < count; i += 2)
		{
			int attrib = StringToInt(attributes[i]);
			if (!attrib)
			{
				LogError("Bad weapon attribute passed: %s ; %s", attributes[i], attributes[i+1]);
				CloseHandle(hWeapon);
				return -1;
			}
			TF2Items_SetAttribute(hWeapon, i2, attrib, StringToFloat(attributes[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete hWeapon;
	EquipPlayerWeapon(client, entity);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", entity);
	if (!show)
	{
		SetEntProp(entity, Prop_Send, "m_iWorldModelIndex", -1);
		SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", -1, _, 0);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", 0.001);
	}
	return entity;
}

public void RoundStart(Event event, char[] name, bool dontBroadcast)
{
	for (int bIndex = 0; bIndex < MAX_BOSSES; bIndex++)
	{
		iBlasterAmmo[bIndex] = 0;
		iMaxBlasterAmmo[bIndex] = 0;
		iBlasterIndex[bIndex] = -1;
		iRageDamage[bIndex] = 0;
		iSerpentineBullets[bIndex] = 0;
		iDailLazers[bIndex] = 0;
		iDailGhosts[bIndex] = 0;
		fNextShot[bIndex] = 0.0;
		fNextReload[bIndex] = 0.0;
	}
	for (int client = 1; client <= MaxClients; client++)
	{
		int bIndex = -1;
		if (!IsValidClient(client) || (bIndex = FF2_GetBossIndex(client)) == -1)
			continue;
		PrepareFlags(client, bIndex);
		if (FF2_HasAbility(bIndex, this_plugin_name, abilities[faster_raging]))
			iRageDamage[bIndex] = FF2_GetBossRageDamage(bIndex);
		if (FF2_HasAbility(bIndex, this_plugin_name, abilities[ability_blaster]))
		{
			iMaxBlasterAmmo[bIndex] = FF2_GetAbilityArgument(bIndex, this_plugin_name, abilities[ability_blaster], 2, 3);
			iBlasterAmmo[bIndex] = iMaxBlasterAmmo[bIndex];
			int weap = SpawnWeapon(client, "tf_weapon_scattergun", 13, 100, 5);
			if (IsValidEntity(weap))
			{
				FF2_SetAmmo(client, weap, 0, iMaxBlasterAmmo[bIndex]);
				iBlasterIndex[bIndex] = weap;
			}
		}
	}
}

void DashFlagFix(int client, int bIndex)
{
	if (!FF2_HasAbility(bIndex, this_plugin_name, abilities[ability_dash]))
		return;
	int numFlags = 0;
	if ((FF2_GetFF2flags(client) & FLAG_DASH_USE) == FLAG_DASH_USE)
		numFlags++;
	if ((FF2_GetFF2flags(client) & FLAG_DASH_COOLDOWN) == FLAG_DASH_COOLDOWN)
		numFlags++;
	if ((FF2_GetFF2flags(client) & FLAG_DASH_READY) == FLAG_DASH_READY)
		numFlags++;
	if (numFlags != 1)
	{
		FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FLAG_DASH_USE);
		FF2_SetFF2flags(client, FF2_GetFF2flags(client) & ~FLAG_DASH_COOLDOWN);
		FF2_SetFF2flags(client, FF2_GetFF2flags(client) | FLAG_DASH_READY);
	}
}

void ReloadBlaster(int client, int bIndex)
{
	if (!FF2_HasAbility(bIndex, this_plugin_name, abilities[ability_blaster]))
		return;
	bool blasterOut = iBlasterIndex[bIndex] == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (blasterOut)
		return;
	if (iBlasterAmmo[bIndex] >= iMaxBlasterAmmo[bIndex] || fNextReload[bIndex] > currentTime)
		return;
	fNextReload[bIndex] = currentTime + FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_blaster], 1, 8.0);
	iBlasterAmmo[bIndex]++;
}

void ForceBlasterAmmo(int client, int bIndex)
{
	if (!FF2_HasAbility(bIndex, this_plugin_name, abilities[ability_blaster]))
		return;
	FF2_SetAmmo(client, iBlasterIndex[bIndex], 0, iBlasterAmmo[bIndex]);
}

public void OnGameFrame() //GameFrame to handle blaster reload.
{
	currentTime = GetGameTime();
	if (FF2_GetRoundState() != 1)
		return;
	for (int client = 1; client <= MaxClients; client++)
	{
		int bIndex = -1;
		if (!IsValidClient(client) || (bIndex = FF2_GetBossIndex(client)) == -1)
			continue;
		DashFlagFix(client, bIndex);
		ReloadBlaster(client, bIndex);
		ForceBlasterAmmo(client, bIndex);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int bIndex = FF2_GetBossIndex(client);
	if (FF2_GetRoundState() != 1 || bIndex == -1)
		return Plugin_Continue;
	if ((buttons & IN_ATTACK) && FF2_HasAbility(bIndex, this_plugin_name, abilities[ability_blaster]))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == iBlasterIndex[bIndex])
		{
			if (fNextShot[bIndex] < currentTime)
			{
				fNextShot[bIndex] = FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_blaster], 5, 3.0) + currentTime;
				FF2_DoAbility(bIndex, this_plugin_name, abilities[ability_blaster], -1);
			}
			
			buttons &= ~IN_ATTACK;
			return Plugin_Changed;
		}
	}
	else if ((buttons & IN_ATTACK2) && FF2_HasAbility(bIndex, this_plugin_name, abilities[ability_dash]))
	{
		if ((FF2_GetFF2flags(client) & FLAG_DASH_READY) != FLAG_DASH_READY || (FF2_GetFF2flags(client) & FLAG_TRUEPOWER_USE) == FLAG_TRUEPOWER_USE)
			return Plugin_Continue;
		FF2_DoAbility(bIndex, this_plugin_name, abilities[ability_dash], -1);
	}
	return Plugin_Continue;
}

public int FF2_PreAbility(int boss, const char[] plugin_name, const char[] ability_name, int status, bool &enabled)
{
	if (!StrEqual(plugin_name, this_plugin_name))
		return;
	if (StrEqual(ability_name, abilities[charge_truepower]))
	{
		int slot = FF2_GetAbilityArgument(boss, this_plugin_name, abilities[charge_truepower], 0);
		if (FF2_GetBossCharge(boss, slot) < 0.0)
			return;
		else
		{
			int client = -1;
			if ((!IsValidClient(client = GetClientOfUserId(FF2_GetBossUserId(boss))) || (FF2_GetFF2flags(client) & FLAG_TRUEPOWER_USE) == FLAG_TRUEPOWER_USE) || FF2_GetBossCharge(boss, 0) < 20.0)
			{
				FF2_SetBossCharge(boss, slot, 0.2);
				enabled = false;
			}
		}
	}
	if (StrEqual(ability_name, abilities[charge_tripleparhoming]))
	{
		int slot = FF2_GetAbilityArgument(boss, this_plugin_name, abilities[charge_tripleparhoming], 0);
		if (FF2_GetBossCharge(boss, slot) < 0.0)
			return;
		else
		{
			int client = GetClientOfUserId(FF2_GetBossUserId(boss));
			if (!IsValidClient(client) || FF2_GetBossCharge(boss, 0) < 10.0)
			{
				FF2_SetBossCharge(boss, slot, 0.2);
				enabled = false;
			}
		}
	}
	return;
}

void SpeedUp_Rage(int bIndex)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss))
		return;
	float percentage = FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[faster_raging], 1, 0.15);
	int lives = FF2_GetBossLives(bIndex) - 1, maxLives = FF2_GetBossMaxLives(bIndex);
	float mult = 1.0 - (percentage * (maxLives - lives));
	int newDmg = RoundToNearest(view_as<float>(iRageDamage[bIndex]) * mult);
	PrintHintText(boss, "%t", "Faster Rage", newDmg);
	FF2_SetBossRageDamage(bIndex, newDmg);
}

public Action Timer_DeleteGhost(Handle timer, any ghost)
{
	int toDelete = EntRefToEntIndex(ghost);
	if (IsValidEntity(toDelete))
		AcceptEntityInput(toDelete, "Kill");
	return Plugin_Continue;
}

public Action Timer_CreateGhost(Handle timer, any bIndex)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex)), maxGhost = FF2_GetAbilityArgument(bIndex, this_plugin_name, abilities[ability_dash_ghost], 3, 10);
	if (FF2_GetRoundState() != 1 || iDailGhosts[bIndex] == maxGhost || !IsValidClient(boss))
		return Plugin_Stop;
	float pos[3], ang[3];
	GetEntPropVector(boss, Prop_Send, "m_vecOrigin", pos);
	GetClientEyeAngles(boss, ang);
	ang[0] = 0.0;
	char gModel[PLATFORM_MAX_PATH] = "";
	FF2_GetAbilityArgumentString(bIndex, this_plugin_name, abilities[ability_dash_ghost], 2, gModel, PLATFORM_MAX_PATH);
	if (StrEqual(gModel, ""))
		return Plugin_Stop;
	int ghost = CreateEntityByName("prop_physics_override");
	if (!IsValidEntity(ghost))
		return Plugin_Continue;
	DispatchKeyValue(ghost, "spawnflags", "2");
	DispatchKeyValue(ghost, "health", "0"); //Prevents damage.
	DispatchKeyValue(ghost, "model", gModel);
	DispatchKeyValue(ghost, "nodamageforces", "1");
	TeleportEntity(ghost, pos, ang, NULL_VECTOR);
	DispatchSpawn(ghost);
	SetEntityMoveType(ghost, MOVETYPE_NONE);
	SetEntProp(ghost, Prop_Send, "m_CollisionGroup", 1);
	SetEntProp(ghost, Prop_Send, "m_usSolidFlags", 4); // not solid
	SetEntProp(ghost, Prop_Send, "m_nSolidType", 0); // not solid
	SetEntityRenderMode(ghost, RENDER_TRANSCOLOR);
	SetEntityRenderColor(ghost, 0, 255, 0, 100);
	CreateTimer(FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_dash_ghost], 4, 2.0), Timer_DeleteGhost, EntIndexToEntRef(ghost));
	iDailGhosts[bIndex]++;
	return Plugin_Continue;
}

public Action Timer_DashCooldown(Handle timer, any bIndex)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss))
		return Plugin_Continue;
	SetHudTextParams(-1.0, 0.3, 1.0, 0, 255, 0, 255);
	FF2_ShowSyncHudText(boss, hDashHud, "%t", "Dash Ready");
	FF2_SetFF2flags(boss, FF2_GetFF2flags(boss) & ~FLAG_DASH_COOLDOWN);
	FF2_SetFF2flags(boss, FF2_GetFF2flags(boss) | FLAG_DASH_READY);
	return Plugin_Continue;
}

void EndDash(int bIndex)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss) || (FF2_GetFF2flags(boss) & FLAG_DASH_USE) != FLAG_DASH_USE)
		return;
	SDKUnhook(boss, SDKHook_StartTouchPost, BossTouch);
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Secondary);
	int weapon = GetPlayerWeaponSlot(boss, TFWeaponSlot_Melee);
	if (weapon == -1 || !IsValidEntity(weapon))
	{
		for (int slot = TFWeaponSlot_Primary; slot <= TFWeaponSlot_Building; slot++)
		{
			weapon = GetPlayerWeaponSlot(boss, slot);
			if (weapon != -1 && IsValidEntity(weapon))
				break;
		}
	}
	SetEntPropEnt(boss, Prop_Send, "m_hActiveWeapon", weapon);
	SetEntityMoveType(boss, MOVETYPE_WALK);
	FF2_SetFF2flags(boss, FF2_GetFF2flags(boss) & ~FLAG_DASH_USE);
	FF2_SetFF2flags(boss, FF2_GetFF2flags(boss) | FLAG_DASH_COOLDOWN);
	CreateTimer(FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_dash], 3, 2.0), Timer_DashCooldown, bIndex);
}

public void BossTouch(int entity, int other)
{
	SDKUnhook(entity, SDKHook_StartTouchPost, BossTouch);
	int bIndex = FF2_GetBossIndex(entity);
	if (bIndex != -1)
		EndDash(bIndex);
}

public Action Timer_EndDash(Handle timer, any bIndex)
{
	EndDash(bIndex);
	return Plugin_Continue;
}

void Do_Dash(int bIndex)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss))
		return;
	FF2_SetFF2flags(boss, (FF2_GetFF2flags(boss) & ~FLAG_DASH_READY) | FLAG_DASH_USE);
	float vel = FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_dash], 1, 2000.0);
	float duration = FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_dash], 2, 0.5);
	TF2_RemoveWeaponSlot(boss, TFWeaponSlot_Secondary);
	int weapon = SpawnWeapon(boss, "tf_weapon_pistol", 22, 100, 5, "1;3.0;96;50000.0");
	if (IsValidEntity(weapon))
		FF2_SetAmmo(boss, weapon, 1, 0);
	float bossPosition[3], eyeAngles[3], velocity[3];
	GetEntPropVector(boss, Prop_Send, "m_vecOrigin", bossPosition);
	bossPosition[2] += 65;
	GetClientEyeAngles(boss, eyeAngles);
	GetAngleVectors(eyeAngles, velocity, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(velocity, vel);
	CreateTimer(duration, Timer_EndDash, bIndex);
	SDKHook(boss, SDKHook_StartTouchPost, BossTouch);
	SetEntityMoveType(boss, MOVETYPE_FLYGRAVITY);
	TeleportEntity(boss, NULL_VECTOR, NULL_VECTOR, velocity);
	iDailGhosts[bIndex] = 0;
	if (FF2_HasAbility(bIndex, this_plugin_name, abilities[ability_dash_ghost]))
		CreateTimer(FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_dash_ghost], 1, 0.2), Timer_CreateGhost, bIndex, TIMER_REPEAT);
}

public Action NoTouchBoss(int entity, int other)
{
	if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == other)
		return Plugin_Handled;
	return Plugin_Continue;
}

int FireProjectile(int client, float pos[3], float ang[3], float velocity, float damage, bool hook)
{
	int projectile = CreateEntityByName("tf_projectile_energy_ball");
	if (IsValidEntity(projectile))
	{
		float vel[3];
		SetEntDataFloat(projectile, FindSendPropInfo("CTFProjectile_EnergyBall", "m_iDeflected")+4, damage, true);
		SetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity", client);
		SetEntProp(projectile, Prop_Send, "m_iTeamNum", FF2_GetBossTeam());
		GetAngleVectors(ang, vel, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(vel, velocity);
		DispatchSpawn(projectile);
		TeleportEntity(projectile, pos, ang, vel);
		if (hook)
			SDKHook(projectile, SDKHook_StartTouch, NoTouchBoss);
		return projectile;
	}
	return -1;
}

void Do_Blaster(int bIndex)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss) || iBlasterAmmo[bIndex]  == 0)
		return;
	iBlasterAmmo[bIndex]--;
	if (iBlasterAmmo[bIndex] == 0)
		SetEntPropEnt(boss, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(boss, TFWeaponSlot_Melee));
	float pos[3], ang[3], damage = FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_blaster], 4, 15.0);
	GetClientEyePosition(boss, pos);
	GetClientEyeAngles(boss, ang);
	FireProjectile(boss, pos, ang, FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[ability_blaster], 3, 3000.0), damage, true);
}

void MakeNewProjectile(int entity, int boss, int bIndex)
{
	float pos[3], ang[3] = {90.0, 0.0, 0.0};
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	float vel = FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[rage_bulletrain], 3, 6000.0);
	float dmg = FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[rage_bulletrain], 4, 15.0);
	float angle = GetRandomFloat(0.0, 2 * FLOAT_PI);
	float rad = GetRandomFloat(0.0, FF2_GetRageDist(bIndex, this_plugin_name, NULL_STRING));
	float mod[3] = {0.0, 0.0, -20.0};
	mod[0] = rad * Cosine(angle);
	mod[1] = rad * Sine(angle);
	AddVectors(pos, mod, pos);
	FireProjectile(boss, pos, ang, vel, dmg, false);
}

public Action OnEntTouch(int entity, int other)
{
	int boss = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (!IsValidClient(boss))
		return Plugin_Continue;
	int bIndex = FF2_GetBossIndex(boss);
	if (bIndex == -1)
		return Plugin_Continue;
	if (other > 0 && other <= MaxClients) //Touched a player
		return Plugin_Continue;
	MakeNewProjectile(entity, boss, bIndex);
	return Plugin_Continue;
}

public Action Timer_FireBullet(Handle timer, DataPack data)
{
	data.Reset();
	int bIndex = data.ReadCell();
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (FF2_GetRoundState() != 1 || !IsValidClient(boss) || iSerpentineBullets[bIndex] == data.ReadCell())
		return Plugin_Stop;
	iSerpentineBullets[bIndex]++;
	float pos[3];
	GetClientEyePosition(boss, pos);
	pos[2] += 40.0;
	float velocity = data.ReadFloat(), damage = data.ReadFloat();
	int projectile = FireProjectile(boss, pos, view_as<float>({-90.0, 0.0, 0.0}), velocity, damage, true);
	SDKHook(projectile, SDKHook_StartTouch, OnEntTouch);
	return Plugin_Continue;
}

void Do_BulletRain(int bIndex)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss))
		return;
	iSerpentineBullets[bIndex] = 0;
	FakeClientCommand(boss, "taunt 0");
	DataPack data;
	CreateDataTimer(FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[rage_bulletrain], 1, 0.1), Timer_FireBullet, data, TIMER_REPEAT);
	data.WriteCell(bIndex);
	data.WriteCell(FF2_GetAbilityArgument(bIndex, this_plugin_name, abilities[rage_bulletrain], 2, 20));
	data.WriteFloat(FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[rage_bulletrain], 3, 6000.0));
	data.WriteFloat(FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[rage_bulletrain], 4, 15.0));
}

public Action Timer_NextSound(Handle timer, DataPack data)
{
	char sound[PLATFORM_MAX_PATH] = "";
	int bIndex = data.ReadCell(), lives = data.ReadCell();
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss))
		return Plugin_Continue;
	FF2_GetAbilityArgumentString(bIndex, this_plugin_name, abilities[life_sounds], lives, sound, PLATFORM_MAX_PATH);
	if (!StrEqual(sound, ""))
	{
		EmitSoundToAll(sound, .volume = 1.0);
		EmitSoundToAll(sound, .volume = 1.0);
	}
	return Plugin_Continue;
}

void Do_LifeSounds(int bIndex)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss))
		return;
	int lives = FF2_GetBossLives(bIndex);
	char sound[PLATFORM_MAX_PATH] = "";
	FF2_GetAbilityArgumentString(bIndex, this_plugin_name, abilities[life_sounds], 1, sound, PLATFORM_MAX_PATH);
	DataPack info;
	float nTime = FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[life_sounds], 1, 1.0);
	CreateDataTimer(nTime, Timer_NextSound, info);
	info.WriteCell(bIndex);
	info.WriteCell(lives);
	info.Reset();
}

void DeleteLazers(ArrayList &lazers)
{
	for (int i = 0; i < lazers.Length; i++)
	{
		int beams[2];
		lazers.GetArray(i, beams);
		int beam = EntRefToEntIndex(beams[0]);
		if (IsValidEntity(beam))
			AcceptEntityInput(beam, "Kill");
		beam = EntRefToEntIndex(beams[1]);
		if (IsValidEntity(beam))
			AcceptEntityInput(beam, "Kill");
	}
	delete lazers;
}

public Action Timer_DeleteLazers(Handle timer, DataPack data)
{
	data.Reset();
	int bIndex = data.ReadCell();
	ArrayList lazers = data.ReadCell();
	DeleteLazers(lazers);
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (IsValidClient(boss))
	{
		TF2_RemoveCondition(boss, TFCond_Ubercharged);
		SetEntityMoveType(boss, MOVETYPE_WALK);
	}
	FF2_SetFF2flags(boss, FF2_GetFF2flags(boss) & ~FLAG_TRUEPOWER_USE);
	return Plugin_Continue;
}

public Action Timer_ResizeLazer(Handle timer, DataPack data)
{
	data.Reset();
	int bIndex = data.ReadCell(), maxIter = FF2_GetAbilityArgument(bIndex, this_plugin_name, abilities[charge_truepower], 4, 20);
	float charge = data.ReadFloat();
	ArrayList lazers = data.ReadCell();
	if (FF2_GetRoundState() != 1)
	{
		DeleteLazers(lazers);
		return Plugin_Stop;
	}
	if (iDailLazers[bIndex] == maxIter)
	{
		for (int i = 0; i < lazers.Length; i++)
		{
			int beams[2];
			lazers.GetArray(i, beams);
			int beam = EntRefToEntIndex(beams[1]);
			if (IsValidEntity(beam))
			{
				char dmgStr[20];
				Format(dmgStr, sizeof(dmgStr), "%i", RoundFloat(200 * (charge / 100.0)));
				DispatchKeyValue(beam, "damage", dmgStr);
			}
		}
		DataPack d2;
		CreateDataTimer(FF2_GetAbilityArgumentFloat(bIndex, this_plugin_name, abilities[charge_truepower], 5, 5.0), Timer_DeleteLazers, d2);
		d2.WriteCell(bIndex);
		d2.WriteCell(lazers);
		return Plugin_Stop;
	}
	for (int i = 0; i < lazers.Length; i++)
	{
		int beams[2];
		lazers.GetArray(i, beams);
		int beam = EntRefToEntIndex(beams[1]);
		if (IsValidEntity(beam))
		{
			SetVariantFloat(20.0 * (float(iDailLazers[bIndex]) / float(maxIter)));
			AcceptEntityInput(beam, "Width");
		}
	}
	iDailLazers[bIndex]++;
	return Plugin_Continue;
}

public bool TraceRayNoPlayers(int entity, int mask)
{
	return !entity || entity > MaxClients;
}

void GetPoints(const float pos[3], float gPos[3], float sPos[3])
{
	static float gAngs[3] = {90.0, 0.0, 0.0}, sAngs[3] =  { -90.0, 0.0, 0.0 };
	Handle gTrace = TR_TraceRayFilterEx(pos, gAngs, CONTENTS_SOLID|CONTENTS_WINDOW|CONTENTS_GRATE, RayType_Infinite, TraceRayNoPlayers);
	TR_GetEndPosition(gPos, gTrace);
	delete gTrace;
	Handle sTrace = TR_TraceRayFilterEx(pos, sAngs, CONTENTS_SOLID|CONTENTS_WINDOW|CONTENTS_GRATE, RayType_Infinite, TraceRayNoPlayers);
	TR_GetEndPosition(sPos, sTrace);
	delete sTrace;
}

void CreateLazers(int bIndex, int lazerCount, ArrayList &lazerArray, float pos[3])
{
	lazerArray = CreateArray(2, lazerCount);
	int i = 0;
	while (i < lazerCount)
	{
		float nPos[3], gPos[3], sPos[3];
		float angle = GetRandomFloat(0.0, 2 * FLOAT_PI);
		float rad = GetRandomFloat(100.0, FF2_GetRageDist(bIndex, this_plugin_name, NULL_STRING));
		float mod[3] = {0.0, 0.0, 0.0};
		mod[0] = rad * Cosine(angle);
		mod[1] = rad * Sine(angle);
		AddVectors(pos, mod, nPos);
		GetPoints(nPos, gPos, sPos);
		int gTarget = CreateEntityByName("info_target");
		if (!IsValidEntity(gTarget))
			continue;
		char endName[124], startName[124];
		Format(endName, sizeof(endName), "EndPoint%i", i);
		Format(startName, sizeof(startName), "StartPoint%i", i);
		DispatchKeyValue(gTarget, "targetname", endName);
		DispatchSpawn(gTarget);
		TeleportEntity(gTarget, gPos, NULL_VECTOR, NULL_VECTOR);
		int sBeam = CreateEntityByName("env_laser");
		if (!IsValidEntity(sBeam))
		{
			AcceptEntityInput(gTarget, "Kill");
			continue;
		}
		DispatchKeyValue(sBeam, "targetname", startName);
		DispatchKeyValue(sBeam, "rendercolor", "255.0 217.0 0.0");
		DispatchKeyValue(sBeam, "life", "0");
		DispatchKeyValueFloat(sBeam, "width", 0.1);
		DispatchKeyValue(sBeam, "texture", "sprites/laserbeam.spr");
		DispatchKeyValue(sBeam, "LaserTarget", endName);
		DispatchKeyValue(sBeam, "spawnflags", "1");
		DispatchSpawn(sBeam);
		TeleportEntity(sBeam, sPos, NULL_VECTOR, NULL_VECTOR);
		int beamArray[2] =  { -1, -1 };
		beamArray[0] = EntIndexToEntRef(gTarget);
		beamArray[1] = EntIndexToEntRef(sBeam);
		lazerArray.SetArray(i, beamArray);
		i++;
	}
}

void Do_TruePower(int bIndex, int status)
{
	int boss = GetClientOfUserId(FF2_GetBossUserId(bIndex));
	if (!IsValidClient(boss))
		return;
	int slot = FF2_GetAbilityArgument(bIndex, this_plugin_name, abilities[charge_truepower], 0);
	float charge = FF2_GetBossCharge(bIndex, slot);
	switch(status)
	{
		case 1:
		{
			SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
			FF2_ShowSyncHudText(boss, hPowerHud, "%t", "True Power Cooldown", -RoundFloat(charge));
		}
		case 2:
		{
			SetHudTextParams(-1.0, 0.88, 0.15, 255, 255, 255, 255);
			FF2_ShowSyncHudText(boss, hPowerHud, "%t", "True Power Charge", RoundFloat(charge));
		}
		case 3:
		{
			FF2_SetFF2flags(boss, FF2_GetFF2flags(boss) | FLAG_TRUEPOWER_USE);
			TF2_AddCondition(boss, TFCond_Ubercharged, TFCondDuration_Infinite);
			FF2_SetBossCharge(bIndex, 0, FF2_GetBossCharge(bIndex, 0)-20.0);
			float position[3];
			GetClientEyePosition(boss, position);
			iDailLazers[bIndex] = 0;
			SetEntityMoveType(boss, MOVETYPE_NONE);
			ArrayList lazers;
			CreateLazers(bIndex, FF2_GetAbilityArgument(bIndex, this_plugin_name, abilities[charge_truepower], 3, 50), lazers, position);
			DataPack data;
			CreateDataTimer(0.2, Timer_ResizeLazer, data, TIMER_REPEAT);
			data.WriteCell(bIndex);
			data.WriteFloat(charge);
			data.WriteCell(lazers);
			char sound[PLATFORM_MAX_PATH];
			if(FF2_RandomSound("sound_ability", sound, PLATFORM_MAX_PATH, bIndex, slot))
			{
				EmitSoundToAll(sound, boss, _, _, _, _, _, boss, position);
				EmitSoundToAll(sound, boss, _, _, _, _, _, boss, position);
				for(int target = 1; target <= MaxClients; target++)
				{
					if(IsValidClient(target) && target != boss)
					{
						EmitSoundToClient(target, sound, boss, _, _, _, _, _, boss, position);
						EmitSoundToClient(target, sound, boss, _, _, _, _, _, boss, position);
					}
				}
			}
		}
	}
}

public void FF2_OnAbility2(int client, const char[] plugin_name, const char[] ability_name, int status)
{
	if (!StrEqual(plugin_name, this_plugin_name))
		return;
	if (StrEqual(ability_name, abilities[faster_raging]))
		SpeedUp_Rage(client);
	else if (StrEqual(ability_name, abilities[ability_dash]))
		Do_Dash(client);
	else if (StrEqual(ability_name, abilities[ability_blaster]))
		Do_Blaster(client);
	else if (StrEqual(ability_name, abilities[rage_bulletrain]))
		Do_BulletRain(client);
	else if (StrEqual(ability_name, abilities[life_sounds]))
		Do_LifeSounds(client);
	else if (StrEqual(ability_name, abilities[charge_truepower]))
		Do_TruePower(client, status);
}