#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

/*
passive_painis
Arg 1=회복 최대량
Arg 2=사운드 경로 (먹는 사운드)

rage_painis
Arg 1=사운드 경로
//



passive_painis
Arg 1=Heal amount (int)
Arg 2=sound path (string)

rage_painis
Arg 1=sound path (string)
//
*/

bool playingSound;
bool UseEnglish = true;

char RageSoundPath[PLATFORM_MAX_PATH];
char sName[48];

public Plugin myinfo=
{
	name="Freak Fortress 2: Painis Cupcake's Abilities*",
	author="Nopied",
	description="",
	version="wat.*",
};


static const char g_strTF2ClassKo[][] =
{
	"알 수 없음",
	"스카웃",
	"스나이퍼",
	"솔져",
	"데모맨",
	"메딕",
	"헤비",
	"파이로",
	"스파이",
	"엔지니어"
};

static const char g_strTF2ClassEng[][] = {
	"UNKNOWN",
	"Scout",
	"Sniper",
	"Soldier",
	"Demoman",
	"Medic",
	"Heavy",
	"Pyro",
	"Spy",
	"Engineer"
};

public void OnPluginStart2()
{
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("arena_round_start", Post_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
}

public Action Post_RoundStart(Event event, const char[] name, bool dont)
{
	KeyValues kv = null;
	for(int boss = 0; GetClientOfUserId(FF2_GetBossUserId(boss)) != -1; boss++)
	{
		if (FF2_HasAbility(boss, this_plugin_name, "passive_painis")) {
			kv = view_as<KeyValues>(FF2_GetSpecialKV(boss));
			kv.Rewind();
			kv.GetString("name", sName, sizeof(sName), "ERROR NAME");
		}
	}
	kv = null;
}

public Action Post_RoundEnd(Event event, const char[] name, bool dont)
{
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsValidClient(target))
			StopSound(target, SNDCHAN_AUTO, RageSoundPath);
	}
}

public Action OnPlayerDeath(Event event, const char[] name, bool dont)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));

	if(!IsBossTeam(victim) && FF2_HasAbility(FF2_GetBossIndex(attacker), this_plugin_name, "passive_painis") && !(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER))
	{
		int boss = FF2_GetBossIndex(attacker);
		int healHp = FF2_GetClientDamage(victim)/2;
		char sound[PLATFORM_MAX_PATH];
		int integerClass = view_as<int>(TF2_GetPlayerClass(victim));

		FF2_GetAbilityArgumentString(boss, this_plugin_name, "passive_painis", 2, sound, sizeof(sound));

		if(healHp > FF2_GetAbilityArgument(boss, this_plugin_name, "passive_painis", 1, 500))
			healHp=FF2_GetAbilityArgument(boss, this_plugin_name, "passive_painis", 1, 500);

		FF2_SetBossHealth(boss, FF2_GetBossHealth(boss)+healHp);
		if(FF2_GetBossHealth(boss) > FF2_GetBossMaxHealth(boss))
			FF2_SetBossHealth(boss, FF2_GetBossMaxHealth(boss));
		
		TF2_StunPlayer(attacker, 2.2, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT); // TODO: 커스터마이즈

		EmitSoundToAll(sound);
		CPrintToChatAll(UseEnglish? 
						"{olive}[FF2]{default} {blue}%s{default}Ate {green}%N (%s){default}. (+%dHP)": //thanks translator
						"{olive}[FF2]{default} {blue}%s{default}(이)가 {green}%N (%s){default}님을 먹었습니다. (+%dHP)", 
						sName,
						victim,
						UseEnglish ? g_strTF2ClassEng[integerClass]:g_strTF2ClassKo[integerClass],
						healHp);

		/*
		if(FF2_GetAbilityDuration(boss) > 0.0)
		{
			PainisRage(boss);
		}
	
		if(FF2_GetAbilityDuration(boss) > 0.0)
		{
			float attackerPos[3];
			float clientPos[3];
	
			GetClientEyePosition(attacker, attackerPos);
	
			for(int client=1; client<=MaxClients; client++)
			{
				if(!IsClientInGame(client) || GetClientTeam(attacker) == GetClientTeam(client) || client == victim)
					continue;
	
				GetClientEyePosition(client, clientPos);
				if(CanSeeTarget(clientPos, attackerPos, attacker, GetClientTeam(attacker)))
				{
					TF2_StunPlayer(client, 4.0, 0.9, TF_STUNFLAGS_GHOSTSCARE);
				}
			}
		}
		*/
	
		float attackerPos[3];
		float clientPos[3];
	
		GetClientEyePosition(attacker, attackerPos);
	
		for(int client=1; client<=MaxClients; client++)
		{
			if(!IsClientInGame(client) || GetClientTeam(attacker) == GetClientTeam(client) || client == victim)
				continue;
	
			GetClientEyePosition(client, clientPos);
			if(CanSeeTarget(clientPos, attackerPos, attacker, GetClientTeam(attacker)))
			{
				TF2_StunPlayer(client, 4.0, 0.9, TF_STUNFLAGS_GHOSTSCARE);
			}
		}
	}
	return Plugin_Continue;
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{
	if(!strcmp(ability_name, "rage_painis"))
	{
		// Debug("Userid: %d, client: %d", FF2_GetBossUserId(boss), GetClientOfUserId(FF2_GetBossUserId(boss)));
		PainisRage(boss);
	}
	return Plugin_Continue;
}

// EmitSoundToAll
void PainisRage(int boss)
{
	int client = GetClientOfUserId(FF2_GetBossUserId(boss));
	float abilityDuration = view_as<KeyValues>(FF2_GetSpecialKV(boss)).GetFloat("ability_duration", 10.0);

	FF2_GetAbilityArgumentString(boss, this_plugin_name, "rage_painis", 1, RageSoundPath, sizeof(RageSoundPath));

	if(playingSound)
	{
		for(int target=1; target<=MaxClients; target++)
		{
			if(IsValidClient(target))
				StopSound(target, SNDCHAN_AUTO, RageSoundPath);
		}
	}

	EmitSoundToAll(RageSoundPath); // KvGetFloat
	TF2_AddCondition(client, TFCond_Ubercharged, abilityDuration);

	//FF2_SetAbilityDuration(boss, abilityDuration);
	playingSound=true;
}

stock bool CanSeeTarget(float startpos[3], float targetpos[3], int target, int bossteam)		// Tests to see if vec1 > vec2 can "see" target
{
	TR_TraceRayFilter(startpos, targetpos, MASK_SOLID, RayType_EndPoint, TraceRayFilterClients, target);

	if(TR_GetEntityIndex() == target)
	{
		if(TF2_GetPlayerClass(target) == TFClass_Spy)							// if they are a spy, do extra tests (coolrocket stuff?)
		{
			if(TF2_IsPlayerInCondition(target, TFCond_Cloaked))				// if they are cloaked
			{
				if(TF2_IsPlayerInCondition(target, TFCond_CloakFlicker)		// check if they are partially visible
					|| TF2_IsPlayerInCondition(target, TFCond_OnFire)
					|| TF2_IsPlayerInCondition(target, TFCond_Jarated)
					|| TF2_IsPlayerInCondition(target, TFCond_Milked)
					|| TF2_IsPlayerInCondition(target, TFCond_Bleeding))
				{
					return true;
				}

				return false;
			}
			if(TF2_IsPlayerInCondition(target, TFCond_Disguised) && GetEntProp(target, Prop_Send, "m_nDisguiseTeam") == bossteam)
			{
				return false;
			}

			return true;
		}

		return true;
	}

	return false;
}
public bool TraceRayFilterClients(int entity, int mask, any data)
{
	if(entity > 0 && entity <=MaxClients)					// only hit the client we're aiming at
	{
		if(entity == data)
		{
			return true;
		}
		else
		{
			return false;
		}
	}

	return true;
}

stock bool IsValidClient(int client)
{
	return (0<client && client<=MaxClients && IsClientInGame(client));
}

stock bool IsBossTeam(int client)
{
	return FF2_GetBossTeam() == GetClientTeam(client);
}
