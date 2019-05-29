#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma newdecls required 

#define	MAX_EDICT_BITS	11
#define	MAX_EDICTS		(1 << MAX_EDICT_BITS)
#define MAX_ABILITY_COUNT 16

int ppIndex[MAX_EDICTS];
bool ppCanUse[MAXPLAYERS+1]=false;
char ppName[MAXPLAYERS+1][MAX_ABILITY_COUNT][64];
char ppEffect[MAXPLAYERS+1][MAX_ABILITY_COUNT][64];
int	ppHolyness[MAXPLAYERS+1][MAX_ABILITY_COUNT];

bool PP_bol[MAXPLAYERS+1] = false;
char sParticles[MAXPLAYERS+1][64];
int iHolyness[MAXPLAYERS+1] = 1;

public Plugin myinfo = {
	name = "Freak Fortress 2: Projectile Particles",
	author = "Otokiru, SHADoW NiNE TR3S",
	description="Fancy projectile particles for bosses",
	version="1.3.1",
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", Event_RoundStart);
	if(FF2_GetRoundState()==1)
	{
		HookAbilities();
	}
}

public void HookAbilities()
{
	for(int clientIdx=1;clientIdx<=MaxClients;clientIdx++)
	{
		if(!IsValidClient(clientIdx))
			continue;
		PP_bol[clientIdx]=ppCanUse[clientIdx]=false;
		int bossIdx=FF2_GetBossIndex(clientIdx);
		if(bossIdx>=0)
		{
			char projectileTweak[64];
			for(int abilityIdx=0;abilityIdx<=MAX_ABILITY_COUNT;abilityIdx++)
			{
				Format(projectileTweak, sizeof(projectileTweak), "projectile_particle_%i", abilityIdx);
				if(FF2_HasAbility(bossIdx, this_plugin_name, projectileTweak))
				{
					FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, projectileTweak, 1, ppName[clientIdx][abilityIdx], sizeof(ppName[][]));		// Projectile Name
					FF2_GetAbilityArgumentString(bossIdx, this_plugin_name, projectileTweak, 2, ppEffect[clientIdx][abilityIdx], sizeof(ppName[][]));	// Projectile Particles
					ppHolyness[clientIdx][abilityIdx]=FF2_GetAbilityArgument(bossIdx, this_plugin_name, projectileTweak, 3, 1);							// Holyness Level
					
					if(!ppCanUse[clientIdx])
					{
						ppCanUse[clientIdx]=true;
					}
					
				}
			}
			
			if(FF2_HasAbility(bossIdx, this_plugin_name, "projectile_particles"))
			{
				FF2_GetAbilityArgumentString(bossIdx,this_plugin_name,"projectile_particles", 1, sParticles[clientIdx], sizeof(sParticles[]));
				iHolyness[clientIdx]=FF2_GetAbilityArgument(bossIdx,this_plugin_name,"projectile_particles", 2, 1);	
				if(sParticles[clientIdx][0])
				{
					PP_bol[clientIdx]=true;
				}
			}
		}
	}

}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	HookAbilities();
}

public void OnEntityCreated(int entity, const char[] classname)
{

	int clientIdx=GetEntityOwner(entity);
	if(IsValidClient(clientIdx, true) && !IsClientObserving(clientIdx))
	{
		if(PP_bol[clientIdx] && !StrContains(classname, "tf_projectile", false))
		{
			SDKHook(entity, SDKHook_Spawn, PrepareParticle);
		}
		
		if(ppCanUse[clientIdx])
		{
			for(int abilityNum=0; abilityNum<=MAX_ABILITY_COUNT; abilityNum++)
			{
				if(!StrContains(classname, ppName[clientIdx][abilityNum], false))
				{
					ppIndex[entity]=abilityNum;
					SDKHook(entity, SDKHook_Spawn, PrepareMultiParticle);
				}
			}
		}
	}
}

public void PrepareMultiParticle(int entity)
{
	int clientIdx=GetEntityOwner(entity);
	if(IsValidClient(clientIdx, true) && !IsClientObserving(clientIdx) && IsPlayerBoss(clientIdx))
	{
		AttachProjectileParticle(entity, ppHolyness[clientIdx][ppIndex[entity]], ppEffect[clientIdx][ppIndex[entity]]);
	}
	ppIndex[entity]=-1;
	SDKUnhook(entity, SDKHook_Spawn, PrepareMultiParticle);
}

public void PrepareParticle(int entity)
{
	int clientIdx=GetEntityOwner(entity);
	if(IsValidClient(clientIdx, true) && !IsClientObserving(clientIdx) && IsPlayerBoss(clientIdx))
	{
		AttachProjectileParticle(entity, iHolyness[clientIdx], sParticles[clientIdx]);
	}
	SDKUnhook(entity, SDKHook_Spawn, PrepareParticle);
}

void AttachProjectileParticle(int entity, int brightness, char[] particleEffect)
{
	for(int i=1; i <= brightness; i++)
	{
		CreateParticle(entity, particleEffect, true);
	}	
}

stock int CreateParticle(int iEntity, char[] strParticle, bool bAttach = false, char[] strAttachmentPoint="", float fOffset[3]={0.0, 0.0, 0.0})
{
    int iParticle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(iParticle))
    {
        float fPosition[3], fAngles[3], fForward[3], fRight[3], fUp[3];
        
        // Retrieve entity's position and angles
        GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPosition)
		
        // Determine vectors and apply offset
        GetAngleVectors(fAngles, fForward, fRight, fUp);
        fPosition[0] += fRight[0]*fOffset[0] + fForward[0]*fOffset[1] + fUp[0]*fOffset[2];
        fPosition[1] += fRight[1]*fOffset[0] + fForward[1]*fOffset[1] + fUp[1]*fOffset[2];
        fPosition[2] += fRight[2]*fOffset[0] + fForward[2]*fOffset[1] + fUp[2]*fOffset[2];
        
        // Teleport and attach to client
        TeleportEntity(iParticle, fPosition, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(iParticle, "effect_name", strParticle);

        if (bAttach)
        {
            SetVariantString("!activator");
            AcceptEntityInput(iParticle, "SetParent", iEntity, iParticle, 0);            
            
            if (!StrEqual(strAttachmentPoint, ""))
            {
                SetVariantString(strAttachmentPoint);
                AcceptEntityInput(iParticle, "SetParentAttachmentMaintainOffset", iParticle, iParticle, 0);                
            }
        }

        // Spawn and start
        DispatchSpawn(iParticle);
        ActivateEntity(iParticle);
        AcceptEntityInput(iParticle, "Start");
    }

    return iParticle;
}

stock int GetEntityOwner(int entity)
{
	return GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
}

stock bool IsValidOwner(int entity, bool lifecheck=false, bool replaycheck=false)
{
	int owner=GetEntityOwner(entity);
	return replaycheck ? IsValidClient(owner, lifecheck) && !IsClientObserving(owner) : IsValidClient(owner, lifecheck);
}

stock bool IsValidClient(int clientIdx, bool lifecheck=false)
{
	if(clientIdx<1 || clientIdx>MaxClients) return false;														 // Exclude invalid indexes
	return lifecheck ? IsClientInGame(clientIdx) && IsPlayerAlive(clientIdx) : IsClientInGame(clientIdx);		 // Also check if client is alive if bool is true
}

stock bool IsClientObserving(int clientIdx)
{
	return view_as<bool>(GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching")) || IsClientReplay(clientIdx) || IsClientSourceTV(clientIdx) || IsClientObserver(clientIdx);
}

stock bool IsPlayerBoss(int clientIdx)
{
	return FF2_GetBossIndex(clientIdx)<0 ? false : true;
}

public void FF2_OnAbility2(int bossIdx,const char[] plugin_name,const char[] ability_name,int status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return;
}