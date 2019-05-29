#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <ff2_ams>
#include <ff2_dynamic_defaults>
#include <tf2attributes>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

// Rage
#define RAGE "special_voorhees_rage"
#define RAGEALIAS "RAG"
new Float:NewSpeedRage[MAXPLAYERS+1];
new Float:NewSpeedDurationRage[MAXPLAYERS+1];
new bool:NewSpeedRage_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
new bool:DSM_SpeedOverrideRage[MAXPLAYERS+1];

// Shift
#define SHIFT "special_voorhees_shift"
#define SHIFTALIAS "SHI"
new Float:NewSpeedShift[MAXPLAYERS+1];
new Float:NewSpeedDurationShift[MAXPLAYERS+1];
new bool:NewSpeedShift_TriggerAMS[MAXPLAYERS+1]; // global boolean to use with AMS
new bool:DSM_SpeedOverrideShift[MAXPLAYERS+1];

#define INACTIVE 100000000.0

public Plugin:myinfo = {
	name	= "Abilities for Jason Voorhees",
	author	= "M7",
	version = "1.5",
};

public OnPluginStart2()
{
	HookEvent("teamplay_round_start", event_round_start, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", event_round_end, EventHookMode_PostNoCopy);
	
	for(new i=1; i<=MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
        }
    }
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrepareAbilities();
}

public PrepareAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			DSM_SpeedOverrideRage[client]=NewSpeedRage_TriggerAMS[client]=DSM_SpeedOverrideShift[client]=NewSpeedShift_TriggerAMS[client]=false;
			NewSpeedRage[client]=NewSpeedShift[client]=0.0;
			NewSpeedDurationRage[client]=NewSpeedDurationShift[client]=INACTIVE;
			
			new boss=FF2_GetBossIndex(client);
			if(boss>=0)
			{
				if(FF2_HasAbility(boss, this_plugin_name, RAGE))
				{
					NewSpeedRage_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, RAGE);
					if(NewSpeedRage_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, RAGE, RAGEALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
				if(FF2_HasAbility(boss, this_plugin_name, SHIFT))
				{
					NewSpeedShift_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, SHIFT);
					if(NewSpeedShift_TriggerAMS[client])
					{
						AMS_InitSubability(boss, client, this_plugin_name, SHIFT, SHIFTALIAS); // Important function to tell AMS that this subplugin supports it
					}
				}
			}
		}
	}
}

public event_round_end(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1;client<=MaxClients;client++)
	{
		if (IsValidClient(client))
		{
			DSM_SpeedOverrideRage[client]=false;
			NewSpeedRage_TriggerAMS[client]=false; // Cleanup
			SDKUnhook(client, SDKHook_PreThink, Rage_Prethink);
			NewSpeedRage[client]=0.0;
			NewSpeedDurationRage[client]=INACTIVE;
			
			DSM_SpeedOverrideShift[client]=false;
			NewSpeedShift_TriggerAMS[client]=false; // Cleanup
			SDKUnhook(client, SDKHook_PreThink, Shift_Prethink);
			NewSpeedShift[client]=0.0;
			NewSpeedDurationShift[client]=INACTIVE;
		}
	}
}

public Action:FF2_OnAbility2(boss, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
		return Plugin_Continue; // Because some FF2 forks still allow RAGE to be activated when the round is over....
	
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	
	if(!strcmp(ability_name, RAGE))
	{
		Special_JasonRage(client);
	}
	else if(!strcmp(ability_name, SHIFT))
	{
		Special_JasonShift(client);
	}
	
	return Plugin_Continue;
}


public bool:RAG_CanInvoke(client)
{
	return true;
}

Special_JasonRage(client)
{
	if(NewSpeedRage_TriggerAMS[client]) // Prevent normal 100% RAGE activation if using AMS
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			NewSpeedRage_TriggerAMS[client]=false;
		}
		else
		{
			return;
		}
	}
	RAG_Invoke(client); // Activate RAGE normally, if ability is configured to be used as a normal RAGE.
}

public RAG_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	decl String:RageSpeed[10], String:RageDuration[10]; // Foolproof way so that args always return floats instead of ints
	FF2_GetAbilityArgumentString(boss, this_plugin_name, RAGE, 1, RageSpeed, sizeof(RageSpeed));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, RAGE, 2, RageDuration, sizeof(RageDuration));
	
	if(NewSpeedRage_TriggerAMS[client])
	{
		new String:snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_jason_rage_start", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
	
	if(RageSpeed[0]!='\0' || RageDuration[0]!='\0')
	{
		if(RageSpeed[0]!='\0')
		{
			NewSpeedRage[client]=StringToFloat(RageSpeed); // Boss Move Speed
		}
		if(RageDuration[0]!='\0')
		{
			if(NewSpeedDurationRage[client]!=INACTIVE)
			{
				NewSpeedDurationRage[client]+=StringToFloat(RageDuration); // Add time if rage is active?
			}
			else
			{
				NewSpeedDurationRage[client]=GetEngineTime()+StringToFloat(RageDuration); // Boss Move Speed Duration
			}
		}
		
		DSM_SpeedOverrideRage[client]=FF2_HasAbility(boss, "ff2_dynamic_defaults", "dynamic_speed_management");
		if(DSM_SpeedOverrideRage[client])
		{
			DSM_SetOverrideSpeed(client, NewSpeedRage[client]);
		}
		
		TF2_AddCondition(client, TFCond_CritHype, FF2_GetAbilityArgumentFloat(boss,this_plugin_name,RAGE,2,5.0));
		TF2_AddCondition(client, TFCond_MegaHeal, FF2_GetAbilityArgumentFloat(boss,this_plugin_name,RAGE,2,5.0));
		
		SDKHook(client, SDKHook_PreThink, Rage_Prethink);
	}
}

public Rage_Prethink(client)
{
	if(!DSM_SpeedOverrideRage[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", NewSpeedRage[client]);
	}
	SpeedTickRage(client, GetEngineTime());
}

public SpeedTickRage(client, Float:gameTime)
{
	// Move Speed
	if(gameTime>=NewSpeedDurationRage[client])
	{
		if(DSM_SpeedOverrideRage[client])
		{
			DSM_SpeedOverrideRage[client]=false;
			DSM_SetOverrideSpeed(client, -1.0);
		}
		
		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			new String:snd[PLATFORM_MAX_PATH];
			if(FF2_RandomSound("sound_jason_rage_finish", snd, sizeof(snd), boss))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
	
		NewSpeedRage[client]=0.0;
		NewSpeedDurationRage[client]=INACTIVE;
		SDKUnhook(client, SDKHook_PreThink, Rage_Prethink);
	}
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
    if(victim != attacker && attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(attacker) == FF2_GetBossTeam() && TF2_IsPlayerInCondition(attacker, TFCond_CritHype))
    {
        FakeClientCommand(victim, "Explode");									// ff2's ontakedamage also hits here if we used ontakedamage....
    }
}


public bool:SHI_CanInvoke(client)
{
	return true;
}

Special_JasonShift(client)
{
	if(NewSpeedShift_TriggerAMS[client]) // Prevent normal 100% RAGE activation if using AMS
	{
		if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
		{
			NewSpeedShift_TriggerAMS[client]=false;
		}
		else
		{
			return;
		}
	}
	SHI_Invoke(client); // Activate RAGE normally, if ability is configured to be used as a normal RAGE.
}

public SHI_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	
	decl String:ShiftSpeed[10], String:ShiftDuration[10]; // Foolproof way so that args always return floats instead of ints
	decl Float:pos[3], Float:pos2[3];
	
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SHIFT, 1, ShiftSpeed, sizeof(ShiftSpeed));
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SHIFT, 2, ShiftDuration, sizeof(ShiftDuration));
	new Float:ShiftDistance=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, SHIFT, 3);	        //range
	
	if(NewSpeedShift_TriggerAMS[client])
	{
		new String:snd[PLATFORM_MAX_PATH];
		if(FF2_RandomSound("sound_jason_shift_start", snd, sizeof(snd), boss))
		{
			EmitSoundToAll(snd, client);
			EmitSoundToAll(snd, client);
		}		
	}
	
	if(ShiftSpeed[0]!='\0' || ShiftDuration[0]!='\0')
	{
		if(ShiftSpeed[0]!='\0')
		{
			NewSpeedShift[client]=StringToFloat(ShiftSpeed); // Boss Move Speed
		}
		if(ShiftDuration[0]!='\0')
		{
			if(NewSpeedDurationShift[client]!=INACTIVE)
			{
				NewSpeedDurationShift[client]+=StringToFloat(ShiftDuration); // Add time if rage is active?
			}
			else
			{
				NewSpeedDurationShift[client]=GetEngineTime()+StringToFloat(ShiftDuration); // Boss Move Speed Duration
			}
		}
		
		DSM_SpeedOverrideShift[client]=FF2_HasAbility(boss, "ff2_dynamic_defaults", "dynamic_speed_management");
		if(DSM_SpeedOverrideShift[client])
		{
			DSM_SetOverrideSpeed(client, NewSpeedShift[client]);
		}
	}
	
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!=FF2_GetBossTeam())
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
			if ((GetVectorDistance(pos,pos2)<ShiftDistance)) 
			{
				SetVariantInt(0);
				AcceptEntityInput(i, "SetForcedTauntCam");
				
				ClientCommand(i, "r_screenoverlay effects/tvscreen_noise002a.vmt"); // tv static transparent										
			}
		}	
	}
	SDKHook(client, SDKHook_PreThink, Shift_Prethink);
}

public Shift_Prethink(client)
{
	if(!DSM_SpeedOverrideShift[client])
	{
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", NewSpeedShift[client]);
	}
	SpeedTickShift(client, GetEngineTime());
}

public SpeedTickShift(client, Float:gameTime)
{
	// Move Speed
	if(gameTime>=NewSpeedDurationShift[client])
	{
		if(DSM_SpeedOverrideRage[client])
		{
			DSM_SpeedOverrideShift[client]=false;
			DSM_SetOverrideSpeed(client, -1.0);
		}
		
		new boss=FF2_GetBossIndex(client);
		if(boss>=0)
		{
			new String:snd[PLATFORM_MAX_PATH];
			if(FF2_RandomSound("sound_jason_shift_finish", snd, sizeof(snd), boss))
			{
				EmitSoundToAll(snd, client);
				EmitSoundToAll(snd, client);
			}
		}
		
		for(new i = 1; i <= MaxClients; i++ )
		{
			if(IsClientInGame(i))
			{
				ClientCommand(i, "r_screenoverlay 0");
			}
		}
	
		NewSpeedShift[client]=0.0;
		NewSpeedDurationShift[client]=INACTIVE;
		SDKUnhook(client, SDKHook_PreThink, Shift_Prethink);
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