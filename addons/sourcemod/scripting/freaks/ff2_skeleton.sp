#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

int clientSkeleton[MAXPLAYERS+1][MAXPLAYERS+1];

public Plugin myinfo=
{
    name="Freak Fortress 2 : Skeleton's abilities",
    author="Nopied",
    description="....",
    version="?",
};

public void OnPluginStart2()
{
  HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dont)
{
    if(FF2_GetRoundState() != 1) return Plugin_Continue;
    
    int client=GetClientOfUserId(GetEventInt(event, "userid"));
    // int attacker=GetClientOfUserId(GetEventInt(event, "attacker"));

    if(!(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER))
    {
      for(int target = 1; target <= MaxClients; target++)
      {
          if(FF2_HasAbility(FF2_GetBossIndex(target), this_plugin_name, "skeleton_spawner"))
          {
              clientSkeleton[target][client]=SpawnSkeleton(target);
              if(IsValidEntity(clientSkeleton[target][client]))
              {
                float skPos[3];
                GetClientEyePosition(target, skPos);

                skPos[2] -= 10.0;
                SDKHook(clientSkeleton[target][client], SDKHook_OnTakeDamage, OnTakeDamage);
                TeleportEntity(clientSkeleton[target][client], skPos, NULL_VECTOR, NULL_VECTOR);
              }
          }
      }
    }
}

public Action:OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
  if(IsValidClient(attacker) || IsValidEntity(inflictor))
    return Plugin_Handled;

  return Plugin_Continue;
}


public Action FF2_OnAbility2(int boss, const char[] pluginName, const char[] abilityName, int status)
{
  if(!strcmp(abilityName, "comeon_skeleton"))
  {
    ComeOnSkeleton(boss);
  }
}

void ComeOnSkeleton(int boss)
{
  int client=GetClientOfUserId(FF2_GetBossUserId(boss));

  float skPos[3];
  GetClientEyePosition(client, skPos);

  for(int target=1; target<=MaxClients; target++)
  {
    if(clientSkeleton[client][target] && IsValidEntity(clientSkeleton[client][target]))
    {
      TeleportEntity(clientSkeleton[client][target], skPos, NULL_VECTOR, NULL_VECTOR);
    }
  }
}

stock int SpawnSkeleton(int owner)
{
  int ent = CreateEntityByName("tf_zombie");
  if(!IsValidEntity(ent))
  {
    return -1;
  }

  SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", owner);
  SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(owner));

  DispatchSpawn(ent);
  return ent;
}

stock bool IsValidClient(int client)
{
    return (0<client && client<=MaxClients && IsClientInGame(client));
}
