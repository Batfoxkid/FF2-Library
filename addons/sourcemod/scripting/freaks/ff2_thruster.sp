
#include <sdkhooks>
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1"

int string_hud = 128;
int string_path = 256;

int RoundActive;

//aoe effects
int FF2ThrustAOEFlags[MAXPLAYERS+1]=0;
float FF2ThrustAOEDmg[MAXPLAYERS+1]=0.0;
float FF2ThrustAOE[MAXPLAYERS+1]=300.0;
int FF2LandAOEFlags[MAXPLAYERS+1]=0;
float FF2LandAOEDmg[MAXPLAYERS+1]=0.0;
float FF2LandAOE[MAXPLAYERS+1]=300.0;
int FF2DmgFix[MAXPLAYERS+1]=1;

//stun and addcond during thrust
int FF2ThrustStunType[MAXPLAYERS+1]=0;
float FF2ThrustStunDur[MAXPLAYERS+1]=0.0;
char FF2ThrustCond[MAXPLAYERS+1][128];

//how thrusting is controlled
int FF2ThrustAir[MAXPLAYERS+1]=0;
float FF2ThrustDiminishRate[MAXPLAYERS+1]=0.0;
float FF2ThrustDiminishMin[MAXPLAYERS+1]=450.0;
float FF2ThrustVertPower[MAXPLAYERS+1]=900.0;
float FF2ThrustHoriPower[MAXPLAYERS+1]=600.0;
float FF2ThrustSmalPower[MAXPLAYERS+1]=400.0;
float FF2ThrustEMult[MAXPLAYERS+1]=2.0;

//resource reqs for thruster
float FF2ThrustCooldown[MAXPLAYERS+1]=15.0;
float FF2ThrustCost[MAXPLAYERS+1]=5.0;
int FF2ThrustCharges[MAXPLAYERS+1]=0;
int FF2ThrustChargesMax[MAXPLAYERS+1]=1;

//graphical and sound
char FF2ThrustSmallSound[MAXPLAYERS+1][128];
char FF2ThrustLargeSound[MAXPLAYERS+1][128];
char FF2ThrustBlastEffect[MAXPLAYERS+1][128];
char FF2ThrustExhaustEffect[MAXPLAYERS+1][128];
int FF2ThrustEffectStyle[MAXPLAYERS+1];
float FF2ThrustEffectOffset[MAXPLAYERS+1];

bool FF2ThrustEnable[MAXPLAYERS+1]=false;
int FF2ThrustButton[MAXPLAYERS+1]=1;

//hud
int HUDThrustStyle[MAXPLAYERS+1]=0;
float HUDThrustOffset[MAXPLAYERS+1]=0.77;

float NextThrust[MAXPLAYERS+1];
float NextCharge[MAXPLAYERS+1];
float GraceTimer[MAXPLAYERS+1];
float PanicMode[MAXPLAYERS+1];
float WorldDmg[MAXPLAYERS+1];
int AirDashCount[MAXPLAYERS+1];
int LastButtons[MAXPLAYERS+1];
bool AddcondAirList[MAXPLAYERS+1][128];

//graphical stuff
bool TrailActive[MAXPLAYERS+1]; //used for graphics but is also used to determine if in mid flight
int RT_EntRef[MAXPLAYERS+1][2];
float LastFallSpeed[MAXPLAYERS+1];
Handle JetPackHUD;

Handle hTrace; //for wall checks

public Plugin myinfo=
{
	name="Freak Fortress 2: Thruster",
	author="kking117",
	description="Adds a thermal thruster like ability for ff2 bosses.",
	version=PLUGIN_VERSION,
};

public void OnPluginStart2()
{
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Pre);
	JetPackHUD=CreateHudSynchronizer();
}

public void OnClientPutInServer(int client)
{
	ClearVariables(client);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	RoundActive=1;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			if(IsBoss(client) && FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, "thruster_ability"))
			{
				RegisterBossAbility(client, "thruster_ability");
			}
			else
			{
				ClearVariables(client);
			}
		}
	}
	CreateTimer(0.2, ClientTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RoundActive=0;
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			ClearVariables(client);
		}
	}
	return Plugin_Continue;
}

void RegisterBossAbility(int client, char[] ability_name)
{
	int boss=FF2_GetBossIndex(client);
	if(boss>-1)
	{
		if(!strcmp(ability_name, "thruster_ability"))
		{
			FF2ThrustEnable[client] = true;
			FF2ThrustButton[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 1, 0);
			FF2ThrustCooldown[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 2, 15.0);
			if (FF2ThrustCooldown[client]<1.5)
			{
				FF2ThrustCooldown[client]=1.5;
			}
			NextCharge[client] = FF2ThrustCooldown[client];
			FF2ThrustCost[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3, 0.0);
			FF2ThrustChargesMax[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 4, 1);
			FF2ThrustCharges[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 5, 0)-1;
			FF2ThrustAir[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 6, 0);
			FF2ThrustDiminishRate[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 7, 0.0);
			FF2ThrustDiminishMin[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 8, 450.0);
			FF2ThrustVertPower[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 9, 900.0);
			FF2ThrustHoriPower[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 10, 600.0);
			FF2ThrustSmalPower[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 11, 400.0);
			FF2ThrustEMult[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 12, 2.0);
			FF2ThrustStunType[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 13, 0);
			FF2ThrustStunDur[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 14, 0.0);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 15, FF2ThrustCond[client], string_path);
			FF2ThrustAOEFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 16, 0);
			FF2LandAOEFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 17, 0);
			FF2ThrustAOEDmg[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 18, 0.0);
			FF2LandAOEDmg[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 19, 0.0);
			FF2DmgFix[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 20, 1);
			FF2ThrustAOE[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 21, 0.0);
			FF2LandAOE[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 22, 0.0);
			
			//graphics n sound
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 23, FF2ThrustSmallSound[client], string_path);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 24, FF2ThrustLargeSound[client], string_path);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 25, FF2ThrustBlastEffect[client], string_path);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 26, FF2ThrustExhaustEffect[client], string_path);
			FF2ThrustEffectStyle[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 27, 0);
			FF2ThrustEffectOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 28, 1.0);
			
			HUDThrustStyle[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 30, 0);
			HUDThrustOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 31, 0.77);
		}
	}
}

//this has no real business being here, but I left it anyway just in case
public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status){
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, 
							float velocity[3], float angles[3], int& weapon, 
							int &subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if(IsValidClient(client) && IsBoss(client))
	{
		if(IsPlayerAlive(client))
		{
			if(FF2ThrustEnable[client])
			{
				if(FF2ThrustCharges[client]<FF2ThrustChargesMax[client])
				{
					if(NextCharge[client]<=GetGameTime())
					{
						FF2ThrustCharges[client]+=1;
						if(FF2ThrustCharges[client]<FF2ThrustChargesMax[client])
						{
							NextCharge[client]=GetGameTime()+FF2ThrustCooldown[client];
						}
					}
				}
				if(CanThrust(client)==0)
				{
					if(FF2ThrustButton[client]==1)
					{
						if((LastButtons[client] & IN_ATTACK3) == 0 && (buttons & IN_ATTACK3))
						{
							if(PanicMode[client]>=GetGameTime())
							{
								TTLaunchBig(client);
							}
							else
							{
								FF2_SetBossCharge(FF2_GetBossIndex(client), 0, FF2_GetBossCharge(FF2_GetBossIndex(client), 0) - FF2ThrustCost[client]);
								TTLaunchSmall(client);
							}
						}
					}
					else if(FF2ThrustButton[client]==2)
					{
						if((LastButtons[client] & IN_RELOAD) == 0 && (buttons & IN_RELOAD))
						{
							if(PanicMode[client]>=GetGameTime())
							{
								TTLaunchBig(client);
							}
							else
							{
								FF2_SetBossCharge(FF2_GetBossIndex(client), 0, FF2_GetBossCharge(FF2_GetBossIndex(client), 0) - FF2ThrustCost[client]);
								TTLaunchSmall(client);
							}
						}
					}
					else
					{
						if((LastButtons[client] & IN_ATTACK2) == 0 && (buttons & IN_ATTACK2))
						{
							if(PanicMode[client]>=GetGameTime())
							{
								TTLaunchBig(client);
							}
							else
							{
								FF2_SetBossCharge(FF2_GetBossIndex(client), 0, FF2_GetBossCharge(FF2_GetBossIndex(client), 0) - FF2ThrustCost[client]);
								TTLaunchSmall(client);
							}
						}
					}
				}
				if(TrailActive[client])
				{
					
					if((GetEntityFlags(client) & FL_ONGROUND))
					{
						if(GraceTimer[client]<=GetGameTime())
						{
							KillRocketTrails(client);
							AirDashCount[client] = 0;
							RemoveAddconds(client);
							if(FF2LandAOEFlags[client]>0 && LastFallSpeed[client]<-550.0)
							{
								TTBlastAOE(client, LastFallSpeed[client]*-1.0, FF2LandAOE[client], FF2LandAOEFlags[client], FF2LandAOEDmg[client]);
							}
						}
					}
					else
					{
						float vPos[3];
						float vel[3]; //this was already declared, but I don't give a damn
						GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
						GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
						int trail1 = EntRefToEntIndex(RT_EntRef[client][0]);
						int trail2 = EntRefToEntIndex(RT_EntRef[client][1]);
						TF2_AddCondition(client, TFCond_RocketPack, 0.5);
						if(FF2ThrustEffectStyle[client]==1)
						{
							if(IsValidEntity(trail1))
							{
								float vAng[3];
								GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
								GetEntPropVector(client, Prop_Send, "m_angRotation", vAng);
								GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
								vPos[0] -= vAng[0]*7.5;
								vPos[1] -= vAng[1]*7.5;
								vPos[2] += GetEntityHeight(client, FF2ThrustEffectOffset[client]);
								TeleportEntity(trail1, vPos, NULL_VECTOR, NULL_VECTOR);
							}	
						}
						else if(FF2ThrustEffectStyle[client]==2)
						{
							if(IsValidEntity(trail1))
							{
								float vAng[3];
								GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
								GetEntPropVector(client, Prop_Send, "m_angRotation", vAng);
								vAng[0] =0.0;
								vAng[1]+=90.0;
								GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
								vPos[0] += vAng[0]*10.0;
								vPos[1] += vAng[1]*10.0;
								vPos[2] += vAng[2]*10.0;
								GetEntPropVector(client, Prop_Send, "m_angRotation", vAng);
								GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
								vPos[0] -= vAng[0]*7.5;
								vPos[1] -= vAng[1]*7.5;
								vPos[2] += GetEntityHeight(client, FF2ThrustEffectOffset[client]);
								TeleportEntity(trail1, vPos, NULL_VECTOR, NULL_VECTOR);
								
								if(IsValidEntity(trail2))
								{
									GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
									GetEntPropVector(client, Prop_Send, "m_angRotation", vAng);
									vAng[0] =0.0;
									vAng[1]-=90.0;
									GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
									vPos[0] += vAng[0]*10.0;
									vPos[1] += vAng[1]*10.0;
									vPos[2] += vAng[2]*10.0;
									GetEntPropVector(client, Prop_Send, "m_angRotation", vAng);
									GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
									vPos[0] -= vAng[0]*7.5;
									vPos[1] -= vAng[1]*7.5;
									vPos[2] += GetEntityHeight(client, FF2ThrustEffectOffset[client]);
									TeleportEntity(trail2, vPos, NULL_VECTOR, NULL_VECTOR);
								}
							}
						}
						LastFallSpeed[client] = vel[2];
					}
				}
				LastButtons[client]=buttons;
			}
		}
		else if(TrailActive[client])
		{
			KillRocketTrails(client);
		}
	}
    return Plugin_Changed;
}

public Action ClientTimer(Handle timer)
{
	if(RoundActive!=1)
	{
	    return Plugin_Stop;
	}
	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && IsBoss(client) && FF2ThrustEnable[client])
		{
			if(IsPlayerAlive(client))
			{
				if(FF2ThrustEMult[client]!=0.0 && WorldDmg[client]>0.0)
				{
					WorldDmg[client]-=20.0;
					if(WorldDmg[client] < 0.0)
					{
						WorldDmg[client] = 0.0;
					}
					else if(WorldDmg[client]>=100.0)
					{
						WorldDmg[client] = 0.0;
						PanicMode[client]=GetGameTime()+5.0;
					}
				}
				if(PanicMode[client]>=GetGameTime())
				{
					float chargeprcnt = NextThrust[client]-GetGameTime();
					char HudMsg[129];
					if(HUDThrustStyle[client]==1)
					{
						chargeprcnt = 100.0 - (((NextThrust[client]-GetGameTime()) / 1.5)*100.0);
						//so it doesn't say -0% sometimes
						if (chargeprcnt<0.0)
						{
							chargeprcnt=0.0;
						}
					}
					if(CanThrust(client)>1)
					{
						FF2_GetAbilityArgumentString(FF2_GetBossIndex(client), this_plugin_name, "thruster_ability", 36, HudMsg, string_hud);
						ReplaceString(HudMsg, string_hud, "\\n", "\n");
						SetHudTextParams(-1.0, HUDThrustOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
						ShowSyncHudText(client, JetPackHUD, HudMsg, chargeprcnt);
					}
					else //fully charged and ready to use
					{
						FF2_GetAbilityArgumentString(FF2_GetBossIndex(client), this_plugin_name, "thruster_ability", 37, HudMsg, string_hud);
						ReplaceString(HudMsg, string_hud, "\\n", "\n");
						SetHudTextParams(-1.0, HUDThrustOffset[client], 0.35, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
						ShowSyncHudText(client, JetPackHUD, HudMsg);
					}
				}
				else
				{
					float chargeprcnt = NextCharge[client]-GetGameTime();
					char HudMsg[129];
					if(HUDThrustStyle[client]==1)
					{
						chargeprcnt = 100.0 - (((NextCharge[client]-GetGameTime()) / FF2ThrustCooldown[client])*100.0);
						//so it doesn't say -0% sometimes
						if (chargeprcnt<0.0)
						{
							chargeprcnt=0.0;
						}
					}
					if(CanThrust(client)>0) //unavaliable and or no charges to use
					{
						if(FF2ThrustCharges[client]<FF2ThrustChargesMax[client])
						{
							FF2_GetAbilityArgumentString(FF2_GetBossIndex(client), this_plugin_name, "thruster_ability", 34, HudMsg, string_hud);
							ReplaceString(HudMsg, string_hud, "\\n", "\n");
							SetHudTextParams(-1.0, HUDThrustOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
							ShowSyncHudText(client, JetPackHUD, HudMsg, FF2ThrustCharges[client], chargeprcnt, FF2ThrustCost[client]);
						}
						else
						{
							FF2_GetAbilityArgumentString(FF2_GetBossIndex(client), this_plugin_name, "thruster_ability", 32, HudMsg, string_hud);
							ReplaceString(HudMsg, string_hud, "\\n", "\n");
							SetHudTextParams(-1.0, HUDThrustOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
							ShowSyncHudText(client, JetPackHUD, HudMsg, FF2ThrustCharges[client], FF2ThrustCost[client]);
						}
						
					}
					else //has at least 1 charge it can use and is valid to use right now
					{
						if(FF2ThrustCharges[client]<FF2ThrustChargesMax[client])
						{
							FF2_GetAbilityArgumentString(FF2_GetBossIndex(client), this_plugin_name, "thruster_ability", 35, HudMsg, string_hud);
							ReplaceString(HudMsg, string_hud, "\\n", "\n");
							SetHudTextParams(-1.0, HUDThrustOffset[client], 0.35, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
							ShowSyncHudText(client, JetPackHUD, HudMsg, FF2ThrustCharges[client], chargeprcnt, FF2ThrustCost[client]);
						}
						else
						{
							FF2_GetAbilityArgumentString(FF2_GetBossIndex(client), this_plugin_name, "thruster_ability", 33, HudMsg, string_hud);
							ReplaceString(HudMsg, string_hud, "\\n", "\n");
							SetHudTextParams(-1.0, HUDThrustOffset[client], 0.35, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
							ShowSyncHudText(client, JetPackHUD, HudMsg, FF2ThrustCharges[client], FF2ThrustCost[client]);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client=GetClientOfUserId(event.GetInt("userid"));
	int attacker=GetClientOfUserId(event.GetInt("attacker"));
	int damage=event.GetInt("damageamount");
	if(IsBoss(client))
	{
		if(!IsValidClient(attacker) && FF2ThrustEMult[client] != 0.0)
		{
			WorldDmg[client] += damage*1.0;
		}
	}
}

//used to activate the first weaker blast from the tt
void TTLaunchSmall(int client)
{
	float vLoc[3]; //position
	float vVel[3]; //velocity
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	if ((GetEntityFlags(client) & FL_ONGROUND))
	{
		if(GetDiminishForce(client, 2)>=0.0)
		{
			vVel[2] = GetDiminishForce(client, 2);
		}
	}
	else
	{
		if(GetDiminishForce(client, 2)>=0.0)
		{
			vVel[2] = GetDiminishForce(client, 2)*0.75;
		}
		CreateTimer(0.1, Timer_DeployParachute, GetClientUserId(client));
	}
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", vLoc);
	vLoc[2] += GetEntityHeight(client, 0.25);
	EmitSoundToAll(FF2ThrustSmallSound[client], client, _, _, _, 0.65);
	CreateParticleBlast(client, FF2ThrustBlastEffect[client], vLoc);
	if(PanicMode[client]<GetGameTime())
	{
		FF2ThrustCharges[client]-=1;
		NextCharge[client]=GetGameTime()+FF2ThrustCooldown[client];
	}
	NextThrust[client]=GetGameTime()+1.5;
	GraceTimer[client]=GetGameTime()+0.9;
	CreateTimer(0.65, Timer_BigBlast, GetClientUserId(client));
	if(FF2ThrustAOEFlags[client]>0)
	{
		TTBlastAOE(client, GetDiminishForce(client, 0)*0.5, FF2ThrustAOE[client], FF2ThrustAOEFlags[client], FF2ThrustAOEDmg[client]);
	}
}

public Action Timer_DeployParachute(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		TF2_AddCondition(client, TFCond_Parachute, 0.5);
	}
}

public Action Timer_BigBlast(Handle timer, int client)
{
	client = GetClientOfUserId(client);
	if(IsValidClient(client) && IsPlayerAlive(client))
	{
		TTLaunchBig(client);
	}
}

//used to activate the second stronger blast from the tt
void TTLaunchBig(int client)
{
	float vLoc[3]; //position
	float vAng[3]; //position
	float vVel[3]; //velocity
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", vLoc);
	vLoc[2] += GetEntityHeight(client, 0.25);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	GetClientEyeAngles(client, vAng);
	GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
	if((LastButtons[client] & IN_FORWARD) == 0 && (LastButtons[client] & IN_BACK))
	{
		if(GetDiminishForce(client, 1)>=0.0)
		{
			vVel[0] = (vAng[0]*GetDiminishForce(client, 1))*-1.0;
			vVel[1] = (vAng[1]*GetDiminishForce(client, 1))*-1.0;
		}
		if(PanicMode[client]>=GetGameTime())
		{
			vVel[2] = (vAng[2]*(GetDiminishForce(client, 0)+GetDiminishForce(client, 2)))*-1.0;
		}
		else
		{
			if(GetDiminishForce(client, 0)>=0.0)
			{
				vVel[2] = (vAng[2]*GetDiminishForce(client, 0))*-1.0;
			}
		}
	}
	else
	{
		if(GetDiminishForce(client, 1)>=0.0)
		{
			vVel[0] = vAng[0]*GetDiminishForce(client, 1);
			vVel[1] = vAng[1]*GetDiminishForce(client, 1);
		}
		if(PanicMode[client]>=GetGameTime())
		{
			vVel[2] = vAng[2]*(GetDiminishForce(client, 0)+GetDiminishForce(client, 2));
		}
		else
		{
			if(GetDiminishForce(client, 0)>=0.0)
			{
				vVel[2] = vAng[2]*GetDiminishForce(client, 0);
			}
		}
	}
	LastFallSpeed[client]=vVel[2];
	if(PanicMode[client]>=GetGameTime())
	{
		NextThrust[client] = GetGameTime()+1.5;
		GraceTimer[client] = GetGameTime()+0.62;
		AirDashCount[client]=0;
	}
	else
	{
		if((GetEntityFlags(client) & FL_ONGROUND)==0)
		{
			AirDashCount[client] += 1;
		}
	}
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	KillRocketTrails(client);
	if(FF2ThrustEffectStyle[client]==1)
	{
		CreateRocketTrail(client, FF2ThrustExhaustEffect[client], false);
	}
	else if(FF2ThrustEffectStyle[client]==2)
	{
		CreateRocketTrail(client, FF2ThrustExhaustEffect[client], true);
	}
	else
	{
		CreateParticleBlast(client, FF2ThrustExhaustEffect[client], vLoc);		
	}
	TrailActive[client]=true;
	EmitSoundToAll(FF2ThrustLargeSound[client], client, _, _, _, 0.7);
	float stundur = FF2ThrustStunDur[client];
	if(FF2ThrustStunType[client]>0)
	{
		if(stundur<0.0)
		{
			stundur*=-1.0;
		}
		else if(stundur == 0.0)
		{
			stundur = 9999.0;
		}
		if(FF2ThrustStunType[client]==4)
		{
			TF2_StunPlayer(client, stundur, 0.0, TF_STUNFLAG_CHEERSOUND|TF_STUNFLAG_BONKSTUCK, client);
		}
		else if(FF2ThrustStunType[client]==3)
		{
			TF2_StunPlayer(client, stundur, 0.0, TF_STUNFLAG_THIRDPERSON|TF_STUNFLAG_SLOWDOWN, client);
		}
		else if(FF2ThrustStunType[client]==2)
		{
			TF2_StunPlayer(client, stundur, 0.0, TF_STUNFLAG_SLOWDOWN|TF_STUNFLAG_NOSOUNDOREFFECT|TF_STUNFLAG_THIRDPERSON, client);
		}
		else if(FF2ThrustStunType[client]==1)
		{
			TF2_StunPlayer(client, stundur, 0.0, TF_STUNFLAG_SLOWDOWN|TF_STUNFLAG_NOSOUNDOREFFECT, client);
		}
		AddcondAirList[client][TFCond_Dazed]=true;
	}
	SetPlayerCondition(client, FF2_GetBossIndex(client), FF2ThrustCond[client]);
}

void TTBlastAOE(int client, float power, float dist, int aoeflags, float dmg)
{
	float clientPosition[3];
	float targetPosition[3];
	float buffer[3];
	if (power > 3500.0)
	{
		power = 3500.0;
	}
	else if (power < 0.0)
	{
		power = 0.0;
	}
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientPosition);
	clientPosition[2] += GetEntityHeight(client, 0.5);
	for(int target=1; target<=MaxClients; target++)
	{
		if(IsValidClient(target) && IsPlayerAlive(target) && client!=target)
		{
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPosition);
			targetPosition[2] += GetEntityHeight(client, 0.5);
			if(GetVectorDistance(clientPosition, targetPosition)<=dist && InClearView(clientPosition, targetPosition, target))
			{
				float DistDif = GetVectorDistance(clientPosition, targetPosition);
				if((aoeflags & 1) && GetClientTeam(target) != GetClientTeam(client))
				{
					TF2_IgnitePlayer(target, client);
				}
				if((aoeflags & 2) && GetClientTeam(target) == GetClientTeam(client))
				{
					TF2_RemoveCondition(target, TFCond_OnFire);
				}
				if((GetEntityFlags(target) & FL_ONGROUND) && (aoeflags & 4))
				{
					float kb = ((75.0+power)*50.0) / (100.0+(DistDif*0.5));
					TF2_AddCondition(target, TFCond_LostFooting, 1.0, client);
					
					
					SubtractVectors(targetPosition, clientPosition, buffer);
					NormalizeVector(buffer, buffer);
					//GetVectorAngles(buffer, buffer);
					buffer[0] *= kb;
					buffer[1] *= kb;
					buffer[2] = 225.0 + (kb*0.5);
					TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, buffer);			
				}
				if(dmg>0.0 && GetClientTeam(target) != GetClientTeam(client))
				{
					float FallOff = ((DistDif+(dist*0.25))/dist)*0.5;
					if (FallOff>0.5)
					{
						FallOff = 0.5;
					}
					FallOff = 1.0 - FallOff;
					float aoedmg = dmg * FallOff;
					if(FF2DmgFix[client]!=0)
					{
						if(aoedmg<=160.0)
						{
							aoedmg*=0.34;
						}
					}
					DamageEntity(target, client, aoedmg, DMG_PLASMA);
				}
			}
		}
	}
}

void DamageEntity(int client, int attacker = 0, float dmg, int dmg_type = DMG_GENERIC)
{
	if(IsValidClient(client) || IsValidEntity(client))
	{
		int damage = RoundToNearest(dmg);
		char dmg_str[16];
		IntToString(damage,dmg_str,16);
		char dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		int pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(client,"targetname","targetsname");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			DispatchSpawn(pointHurt);
			if(IsValidEntity(attacker))
			{
				float AttackLocation[3];
				GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", AttackLocation);
				TeleportEntity(pointHurt, AttackLocation, NULL_VECTOR, NULL_VECTOR);
			}
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(client,"targetname","war3_donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

stock void SetPlayerCondition(int client, int boss, char[] cond)
{
	char conds[32][32];
	int count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		float dur;
		int id;
		for (int i = 0; i < count; i+=2)
		{
			if(!TF2_IsPlayerInCondition(client, view_as<TFCond>(StringToInt(conds[i]))))
			{
				dur = StringToFloat(conds[i+1]);
				id = StringToInt(conds[i]);
				if(dur <= 0.0)
				{
					AddcondAirList[client][id]=true;
				}
				if(dur<0.0)
				{
					dur*=-1.0;
				}
				else if(dur == 0.0)
				{
					dur=9999.0;
				}
				TF2_AddCondition(client, view_as<TFCond>(id), dur); ///says this is a tag match but works as intended
			}
		}
	}
}

void KillRocketTrails(int client)
{
	if (RT_EntRef[client][0]!=0)
	{
		int trail1 = EntRefToEntIndex(RT_EntRef[client][0]);
		if(IsValidEntity(trail1))
		{
			RemoveEntity(trail1);
			TrailActive[client]=false;
		}
		RT_EntRef[client][0]=0;
	}
	if (RT_EntRef[client][1]!=0)
	{
		int trail2 = EntRefToEntIndex(RT_EntRef[client][1]);
		if(IsValidEntity(trail2))
		{
			RemoveEntity(trail2);
			TrailActive[client]=false;
		}
		RT_EntRef[client][1]=0;
	}
	TrailActive[client]=false;
}

void CreateRocketTrail(int client, char[] particlename, bool dotwo)
{
    if(IsValidClient(client))
	{
		int particle = CreateEntityByName("info_particle_system");
		if (IsValidEntity(particle))
		{
			DispatchKeyValue(particle, "targetname", "tf2particle");
			DispatchKeyValue(particle, "effect_name", particlename);
			DispatchKeyValue(particle, "angles", "-90.0, 0.0, 0.0"); 
			DispatchSpawn(particle);
			ActivateEntity(particle);
			AcceptEntityInput(particle, "start");
			RT_EntRef[client][0] = EntIndexToEntRef(particle);
		}
		if(dotwo)
		{
			particle = CreateEntityByName("info_particle_system");
			if (IsValidEntity(particle))
			{
				DispatchKeyValue(particle, "targetname", "tf2particle");
				DispatchKeyValue(particle, "effect_name", particlename);
				DispatchKeyValue(particle, "angles", "-90.0, 0.0, 0.0"); 
				DispatchSpawn(particle);
				ActivateEntity(particle);
				AcceptEntityInput(particle, "start");
				RT_EntRef[client][1] = EntIndexToEntRef(particle);
			}
		}
	}
}

void CreateParticleBlast(int entity, char[] particlename, float vloc[3])
{
	int particle = CreateEntityByName("info_particle_system");
	char tName[128];
	if (IsValidEdict(particle))
    {
		Format(tName, sizeof(tName), "target%i", entity);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		TeleportEntity(particle, vloc, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(15.0, Timer_RemoveParticle, EntIndexToEntRef(particle));
    }
}

public Action Timer_RemoveParticle(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(IsValidEntity(entity))
	{
		RemoveEntity(entity);
	}
}

void ClearVariables(int client)
{
	FF2ThrustAOEFlags[client]=0;
	FF2ThrustAOEDmg[client]=0.0;
	FF2ThrustAOE[client]=300.0;
	
	FF2LandAOEFlags[client]=0;
	FF2LandAOEDmg[client]=0.0;
	FF2LandAOE[client]=300.0;
	
	FF2DmgFix[client] = 1;

	FF2ThrustStunType[client]=0;
	FF2ThrustStunDur[client]=0.0;
	
	FF2ThrustChargesMax[client]=1;
	FF2ThrustCharges[client]=0;
	FF2ThrustAir[client]=0;
	FF2ThrustDiminishRate[client]=0.0;
	FF2ThrustDiminishMin[client]=450.0;
	FF2ThrustVertPower[client]=900.0;
	FF2ThrustHoriPower[client]=600.0;
	FF2ThrustSmalPower[client]=325.0;
	FF2ThrustEMult[client]=2.0;

	FF2ThrustCooldown[client]=15.0;
	FF2ThrustCost[client]=5.0;

	FF2ThrustEnable[client]=false;
	FF2ThrustButton[client] = 1;
	FF2ThrustEffectStyle[client] = 0;
	FF2ThrustEffectOffset[client] = 1.0;
	
	HUDThrustStyle[client]=0;
	HUDThrustOffset[client] = 0.77;

	NextCharge[client]=0.0;
	NextThrust[client]=0.0;
	PanicMode[client] = 0.0;
	WorldDmg[client] = 0.0;
	AirDashCount[client] = 0;
	LastButtons[client]=0;
	
	KillRocketTrails(client);
	TrailActive[client]=false;
	//RT_EntRef[client][0]=0;
	//RT_EntRef[client][1]=0;
	ClearAddcondList(client);
}

void ClearAddcondList(int client)
{
	for(int id=0; id<=127; id++)
	{
		AddcondAirList[client][id] = false;
	}
}

//does the same as clearaddcondlist but also removes the addconds from the client
void RemoveAddconds(int client)
{
	for(int id=0; id<=127; id++)
	{
		if(AddcondAirList[client][id]==true)
		{
			TF2_RemoveCondition(client, view_as<TFCond>(id)); //says it's a tag mismatch but works fine
		}
		AddcondAirList[client][id] = false;
	}
}

stock int CanThrust(int client)
{
	//reasons
	//0 = can use
	//1 = no charges to use
	//2 = airdash count maxed out
	//3 = not enough rage
	//4 = diminish value too low
	//5 = cooldown (the 1.5 fire rate cooldown that is)
	if(FF2ThrustCharges[client]>0)
	{
		if(PanicMode[client]<GetGameTime() && FF2_GetBossCharge(FF2_GetBossIndex(client), 0) < FF2ThrustCost[client])
		{
			return 3;
		}
		else if(NextThrust[client]>GetGameTime())
		{
			return 5;
		}
		else
		{
			if(FF2ThrustAir[client]>0)
			{
				if(AirDashCount[client]<FF2ThrustAir[client])
				{
					return 0;
				}
				else
				{
					return 2;
				}
			}
			else if(FF2ThrustDiminishRate[client]!=0.0 || FF2ThrustDiminishMin[client]>=0.0)
			{
				if(GetDiminishForce(client, 0)<FF2ThrustDiminishMin[client])
				{
					return 4;
				}
			}
		}
		return 0;
	}
	else
	{
		if(PanicMode[client]<GetGameTime())
		{
			return 1;
		}
		else
		{
			if(NextThrust[client]>GetGameTime())
			{
				return 5;
			}
			else
			{
				return 0;
			}
		}
	}
}

stock float GetDiminishForce(int client, int type)
{
	float Reduce = FF2ThrustDiminishRate[client]*AirDashCount[client];
	float ForceTotalOG = FF2ThrustVertPower[client] + FF2ThrustHoriPower[client] + FF2ThrustSmalPower[client];
	float ForceTotal = ForceTotalOG;
	float EMult = FF2ThrustEMult[client];
	if(PanicMode[client]<GetGameTime())
	{
		EMult = 1.0;
	}
	else if(EMult==0.0)
	{
		EMult = 1.0;
	}
	ForceTotal -= Reduce;
	switch(type)
	{
		case 0:
		{
			return EMult*(ForceTotalOG*(FF2ThrustVertPower[client]/ForceTotal));
		}
		case 1:
		{
			return EMult*(ForceTotalOG*(FF2ThrustHoriPower[client]/ForceTotal));
		}
		case 2:
		{
			return EMult*(ForceTotalOG*(FF2ThrustSmalPower[client]/ForceTotal));
		}
	}
	return 0.0;
}

stock float GetEntityHeight(int entity, float mult)
{
	if(IsValidEntity(entity))
	{
		if(HasEntProp(entity, Prop_Send, "m_vecMaxs"))
		{
			float height[3];
			GetEntPropVector(entity, Prop_Send, "m_vecMaxs", height);
			return height[2]*mult;
		}
	}
	return -1.0;
}

stock bool IsBoss(int client)
{
	if(IsValidClient(client))
	{
		if(FF2_GetBossIndex(client) >= 0)
		{
			return true;
		}
	}
	return false;
}

stock bool IsValidClient(int client, bool replaycheck=true)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}

stock bool InClearView(float pos2[3], float pos[3], int entity)
{
	hTrace = TR_TraceRayFilterEx(pos2, pos, MASK_SOLID, RayType_EndPoint, TraceFilterThroughNpc, entity);
	if(hTrace != INVALID_HANDLE)
	{
        if(TR_DidHit(hTrace))//if there's an obstruction
		{
		    CloseHandle(hTrace);
		    return false;
		}
		else//if there isn't a wall between them
		{
			CloseHandle(hTrace);
			return true;
		}
	}
	return false;
}

stock bool TraceFilterThroughNpc(int entity, int contentsMask, any ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidClient(entity))
	{
		return false;
	}
	else if(IsValidEntity(entity))
	{
		char entname[256];
		GetEntityClassname(entity, entname, sizeof(entname));
		if(StrEqual(entname, "tank_boss", false) || StrEqual(entname, "tf_zombie", false) || StrEqual(entname, "tf_robot_destruction_robot", false) || StrEqual(entname, "merasmus", false) || StrEqual(entname, "headless_hatman", false) || StrEqual(entname, "eyeball_boss", false))
		{
			return false;
		}
		else if(StrEqual(entname, "obj_sentrygun", false) || StrEqual(entname, "obj_dispenser", false) || StrEqual(entname, "obj_teleporter", false))
		{
			return false;
		}
		else if(StrContains(entname, "tf_projectile")>=0)
		{
			return false;
		}
	}
	return true;
}
