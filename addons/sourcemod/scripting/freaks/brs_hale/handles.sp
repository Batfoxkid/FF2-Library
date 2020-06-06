#include "brs_hale/medigun.sp"
#include "brs_hale/stun_gun.sp"
#include "brs_hale/homing.sp"
#include "brs_hale/upgrade.sp"
#include "brs_hale/wrap.sp"
#include "brs_hale/multiple.sp"

static const char SpecialAb[][] = {
	"invalid",
	"special_weapons_stungun",
	"special_weapons_medigun",
	"special_weapons_homing",
	"special_weapons_multiple"
};

public void RoundEnd_Cleanup() 
{
	if(IsBRSAcitve)
	{
		for(int x = 1; x <= MaxClients; x++)
		{
			if(IsClientInGame(x)) {
				Global_Unhook(x);
				int boss = FF2_GetBossIndex(x);
				if(boss >= 0) {
					Tracker[boss].DmgSince = 0.0;
					Tracker[boss].IsRaging = false;
				}
			}
		}
		delete ADTWeapons;
		IsBRSAcitve = false;
	}
}

public bool RoundStart_PrepAbilities() 
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(!ValidatePlayer(client, AnyAlive))
			continue;
		
		FF2Prep Boss = FF2Prep(client);
		if(!Boss.HasAbility(this_plugin_name, BRS_CFG)) {
			continue;
		}
		
		SDKHook(client, SDKHook_OnTakeDamageAlive, Post_TakeDamageAlive);
		ADTWeapons = new ArrayList(2);
		return true;
	}
	return false;
}

public void OnEntityCreated(int entity, const char[] cls)
{
	if(!IsRoundActive())
		return;
	
	if(!bIsBRSWeapon)
		return;
	if(!strcmp(cls, "tf_weapon_medigun") && iWeapon == Healing) {
		Start_AntiMedigun(entity);
	}
	else if(!strcmp(cls, "tf_weapon_pistol") && iWeapon == StunGun) {
		Start_StunGun(entity);
	}
	else if(!strcmp(cls, "tf_weapon_rocketlauncher") && iWeapon == Multiple) {
		Start_MultiRocket(entity);
	}
}

public void FF2_OnAbility_PickWeapon(int boss, const char[] Ability_Name)
{
	if(!strcmp(Ability_Name, "special_weapons_medigun"))
		Handle_MedigunRage(boss);
	else if(!strcmp(Ability_Name, "special_weapons_stungun"))	
		Handle_StunRage(boss);
	else if(!strcmp(Ability_Name, "special_weapons_homing"))
		Handle_HomingRocket(boss);
	else if(!strcmp(Ability_Name, "special_weapons_multiple"))
		Handle_MultiRockets(boss);
}

public Action FF2_OnAbility_RealityWrap(int boss) 
{
	int client = BossToClient(boss);
	return Handle_RandomTeleport(client);
}

public void FF2_OnAbility_Upgrade(int boss)
{
	int client = BossToClient(boss);
	Handle_UpgradeThink(client);
}

public Action Post_TakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	int boss = FF2_GetBossIndex(victim);
	if(boss < 0)
		return Plugin_Continue;
	
	if(!FF2_HasAbility(boss, this_plugin_name, "energy_upgrade"))
		return Plugin_Continue;
	
	if(damage <= 0.0)
	return Plugin_Continue;
	Tracker[boss].DmgSince = GetGameTime();
	return Plugin_Continue;
}


static float flBackToSanity[MAXCLIENTS];
public void HookBackToSanity(int client, float duration)
{
	flBackToSanity[client] = duration + GetGameTime();
	SDKHook(client, SDKHook_PreThink, CheckBackToSanity);
}

public void CheckBackToSanity(int client)
{
	if(!IsRoundActive())
		SDKUnhook(client, SDKHook_PreThink, CheckBackToSanity);
	else if(flBackToSanity[client] <= GetGameTime()) {
		static char snd[128];
		int boss = FF2_GetBossIndex(client);
		if(FF2_RandomSound("sound_rage_end", snd, sizeof(snd), boss))
			FF2_EmitVoiceToAll2(snd);
		Tracker[boss].IsRaging = false;
		int weapon = GetCurrentWeapon(boss);
		if(IsValidEntity(weapon))
		{
			int slot = GetWeaponSlot(weapon);
			TF2_RemoveWeaponSlot(client, slot);
			RemoveFromCurrentWeapon(boss);
			if(IsPlayerAlive(client))
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
		}
		iWeapon = Inactive;
		SDKUnhook(client, SDKHook_PreThink, CheckBackToSanity);
	}
}

public void SpawnSpecialWeapon(int boss, WeaponType Type)
{
	Tracker[boss].IsRaging = true;
	
	FF2Prep Boss = FF2Prep(boss, false);
	
	int index = Boss.GetArgI(this_plugin_name, SpecialAb[Type], "index", 1, -1);
	
	static char cls[64], att[128];
	Boss.GetArgS(this_plugin_name, SpecialAb[Type], "classname", 2, cls, sizeof(cls));
	Boss.GetArgS(this_plugin_name, SpecialAb[Type], "attributes", 3, att, sizeof(att));
	
	int client = Boss.Index;
	bIsBRSWeapon = true;
	iWeapon = Type;
	int weapon = FF2_SpawnWeapon(client, cls, index, 39, 5, att, false);
	bIsBRSWeapon = false;
	SetAsCurrentWeapon(boss, weapon);
	
	if(Type != Healing) {
		index = Boss.GetArgI(this_plugin_name, SpecialAb[Type], "weapon ammo", 4, 5);
		FF2_SetAmmo(client, weapon,index, Boss.GetArgI(this_plugin_name, SpecialAb[Type], "weapon clip", 5, -1));
	}
	
	switch(Type)
	{
		case StunGun : {
			if(FF2_RandomSound("sound_stun_start", att, sizeof(att), boss))
				FF2_EmitVoiceToAll2(att);
		}
		case Healing : {
			if(FF2_RandomSound("sound_medigun_start", att, sizeof(att), boss))
				FF2_EmitVoiceToAll2(att);
		}
		case Homing : {
			if(FF2_RandomSound("sound_homing_start", att, sizeof(att), boss))
				FF2_EmitVoiceToAll2(att);
		}
	}
	
	static float Position[3];
	float duration = Boss.GetArgF(this_plugin_name, SpecialAb[Type], "duration", 6, 25.0);
	HookBackToSanity(client, duration);
	
	Boss.GetArgS(this_plugin_name, SpecialAb[Type], "print text", 11, att, sizeof(att));
	if(Boss.PrepareString(0, att, sizeof(att)))
		PrintHintTextToAll(att);
	
	Boss.GetArgS(this_plugin_name, SpecialAb[Type], "particles", 12, att, sizeof(att));
	if(strlen(att) > 3) {
		FixParticlesName(att, sizeof(att), TF2_GetClientTeam(client));
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", Position);
		CreateTimedParticle(client, att, Position, duration);
	}
}
