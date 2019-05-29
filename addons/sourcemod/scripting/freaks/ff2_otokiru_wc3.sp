#pragma semicolon 1

#include <sourcemod>
#include <tf2items>
#include <tf2_stocks>
#include <ff2_ams>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <sdkhooks>

#define MAXPLAYERSCUSTOM 66
#define entangleSound "war3source/entanglingrootsdecay1.wav"
#define teleportSound "war3source/blinkarrival.wav"
#define lightningSound "war3source/lightningbolt.wav"
#define DMG_ENERGYBEAM			(1 << 10)

new Handle: teleHUD, Handle: lightningHUD, Handle: entangleHUD;
// The original code wasn't multi-boss friendly, so this should fix it.

new bool:Teleport_TriggerAMS[MAXPLAYERS+1];
new bTeleports[MAXPLAYERS+1];
new Float:bTeleportDistance[MAXPLAYERS+1];
new bTeleportButton[MAXPLAYERS+1];

new bool:ChainLightning_TriggerAMS[MAXPLAYERS+1];
new bChainLightningButton[MAXPLAYERS+1];
new bChainLightnings[MAXPLAYERS+1];
new bChainLightningDamage[MAXPLAYERS+1];
new Float:bChainLightningDistance[MAXPLAYERS+1];

new bool:Entangle_TriggerAMS[MAXPLAYERS+1];
new bEntangleButton[MAXPLAYERS+1];
new bEntangles[MAXPLAYERS+1];
new Float:bEntangleDuration[MAXPLAYERS+1];

#define ENTANGLECFG "entangle_config"
#define TELEPORTCFG "teleport_config"
#define LIGHTNINGCFG "chainlightning_config"
new BeamSprite,HaloSprite,BloodSpray,BloodDrop;

new ignoreClient;
new Float:emptypos[3];
new Float:oldpos[MAXPLAYERSCUSTOM][3];
new Float:teleportpos[MAXPLAYERSCUSTOM][3];
new bool:inteleportcheck[MAXPLAYERSCUSTOM];
new bool:bBeenHit[MAXPLAYERSCUSTOM][MAXPLAYERSCUSTOM];

public Plugin:myinfo = {
	name = "Freak Fortress 2: WC3 Ability Pack",
	author = "Otokiru, SHADoW NiNE TR3S",
	version = "1.2.4",
};

public OnPluginStart2()
{
	AddFileToDownloadsTable("sound/war3source/entanglingrootsdecay1.wav");
	AddFileToDownloadsTable("sound/war3source/blinkarrival.wav");
	AddFileToDownloadsTable("sound/war3source/lightningbolt.wav");
	BeamSprite=PrecacheModel("materials/sprites/lgtning.vmt");
	HaloSprite=PrecacheModel("materials/sprites/halo01.vmt");
	BloodDrop=PrecacheModel("sprites/blood.vmt");
	BloodSpray=PrecacheModel("sprites/bloodspray.vmt");
	PrecacheSound(entangleSound,true);
	PrecacheSound(teleportSound,true);
	PrecacheSound(lightningSound,true);
	HookEvent("arena_round_start", event_round_start);
	teleHUD=CreateHudSynchronizer();
	lightningHUD=CreateHudSynchronizer();
	entangleHUD=CreateHudSynchronizer();
	if(FF2_GetRoundState()==1)
	{
		HookAbilities();
	}
}

public Action:FF2_OnAbility2(boss,const String:plugin_name[],const String:ability_name[],action)
{
	new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	if (!strcmp(ability_name,"charge_weightdown_fix"))
	{
		decl Float:oldGravity;
		if(GetEntityGravity(client)!=6.0)
		{
			oldGravity=GetEntityGravity(client);
		}
		if (GetClientButtons(client) & IN_DUCK)
		{
			if (!(GetEntityFlags(client) & FL_ONGROUND))
			{
				decl Float:ang[3];
				GetClientEyeAngles(client, ang);
				if (ang[0]>60.0)
				{
					new Float:fVelocity[3];
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
					fVelocity[2] = -5000.0;
					TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
					SetEntityGravity(client, 6.0);
				}
			}
			SetEntityGravity(client, oldGravity);
		}
	}
	
	// Entangle
	else if (!strcmp(ability_name, ENTANGLECFG))
	{
		if(Entangle_TriggerAMS[client]) // Prevent normal 100% RAGE activation if using AMS
		{
			if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
			{
				Entangle_TriggerAMS[client]=false;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		ENT_Invoke(client);
	}
	else if (!strcmp(ability_name,"entangle_activator"))
		Entangle_Activator(client);
		
	// Teleport
	else if (!strcmp(ability_name, TELEPORTCFG))
	{
		if(Teleport_TriggerAMS[client]) // Prevent normal 100% RAGE activation if using AMS
		{
			if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
			{
				Teleport_TriggerAMS[client]=false;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		OTP_Invoke(client);
	}
	else if (!strcmp(ability_name,"teleport_activator"))
		Teleport_Activator(client);
		
	// Chain Lightning
	else if (!strcmp(ability_name, LIGHTNINGCFG))
	{
		if(ChainLightning_TriggerAMS[client]) // Prevent normal 100% RAGE activation if using AMS
		{
			if(!FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability")) // Fail state?
			{
				ChainLightning_TriggerAMS[client]=false;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		CLT_Invoke(client);
	}
	else if (!strcmp(ability_name,"chainlightning_activator"))
		ChainLightning_Activator(client);

	return Plugin_Continue;
}

public Action:event_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	HookAbilities();
}

public HookAbilities()
{
	for(new client=1;client<=MaxClients;client++)
	{
		if(!IsValidClient(client))
			continue;
		
		// Make these multi-boss friendly
		bChainLightningDamage[client]=0;
		bEntangles[client]=bChainLightnings[client]=bTeleports[client]=0;
		bEntangleDuration[client]=bChainLightningDistance[client]=bTeleportDistance[client]=0.0;
		bEntangleButton[client]=bChainLightningButton[client]=bTeleportButton[client]=0;
		Entangle_TriggerAMS[client]=ChainLightning_TriggerAMS[client]=Teleport_TriggerAMS[client]=false;
		
		new boss=FF2_GetBossIndex(client);
		if(boss>=0 && (FF2_HasAbility(boss, this_plugin_name, ENTANGLECFG) || FF2_HasAbility(boss, this_plugin_name, TELEPORTCFG) || FF2_HasAbility(boss, this_plugin_name, LIGHTNINGCFG)))
		{
			if(FF2_HasAbility(boss, this_plugin_name, ENTANGLECFG))
			{
				Entangle_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, ENTANGLECFG);
				if(Entangle_TriggerAMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, ENTANGLECFG, "ENT");
				}
			}
			if(FF2_HasAbility(boss, this_plugin_name, TELEPORTCFG))
			{
				Teleport_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, TELEPORTCFG);
				if(Teleport_TriggerAMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, TELEPORTCFG, "OTP");
				}
			}
			if(FF2_HasAbility(boss, this_plugin_name, LIGHTNINGCFG))
			{
				ChainLightning_TriggerAMS[client]=AMS_IsSubabilityReady(boss, this_plugin_name, LIGHTNINGCFG);
				if(ChainLightning_TriggerAMS[client])
				{
					AMS_InitSubability(boss, client, this_plugin_name, LIGHTNINGCFG, "CLT");
				}
			}
			CreateTimer(1.0,ShowAbilityStatus, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

// HUD

public Action:ShowAbilityStatus(Handle:timer, any:client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client) || FF2_GetRoundState()!=1)
		return Plugin_Stop;
		
	decl String:HUDStatus[128];
	if(bTeleports[client])
	{
		SetHudTextParams(-1.0, 0.21, 1.1, 255 , 255 , 255, 255);
		Format(HUDStatus, sizeof(HUDStatus), "Teleports Left: %i", bTeleports[client]);
		ShowSyncHudText(client, teleHUD, HUDStatus);
	}
	
	if(bChainLightnings[client])
	{
		SetHudTextParams(-1.0, (!bTeleports[client] ? 0.21 : 0.24), 1.1, 255 , 255 , 255, 255);
		Format(HUDStatus, sizeof(HUDStatus), "Chain Lightnings Left: %i", bChainLightnings[client]);
		ShowSyncHudText(client, lightningHUD, HUDStatus);		
	}
	
	if(bEntangles[client])
	{
		SetHudTextParams(-1.0, (!bTeleports[client] && !bChainLightnings[client] ? 0.21 : (!bTeleports[client] && bChainLightnings[client] || bTeleports[client] && !bChainLightnings[client]) ? 0.24 : 0.27), 1.1, 255 , 255 , 255, 255);
		Format(HUDStatus, sizeof(HUDStatus), "Entangles Left: %i", bEntangles[client]);
		ShowSyncHudText(client, entangleHUD, HUDStatus);	
	}
	
	return Plugin_Continue;
}

// Entangle Ability
public bool:ENT_CanInvoke(client)
{
	return true;
}

public ENT_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	bEntangleButton[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ENTANGLECFG, 1);	//Activation Key
	switch(bEntangleButton[client])
	{
		case 2: bEntangleButton[client] = IN_ATTACK2; // alt-fire
		case 3: bEntangleButton[client] = IN_RELOAD;  // reload
		case 4: bEntangleButton[client] = IN_ATTACK3; // special
		case 5: // use (requires server to have "tf_allow_player_use" set to 1)
		{
			bEntangleButton[client] = IN_USE;
			if(!GetConVarBool(FindConVar("tf_allow_player_use")))
			{
				LogMessage("[War3 Abilities] WARNING! Boss requires '+use' as part of its abilities, please set 'tf_allow_player_use' to 1 on your server.cfg!");
				bEntangleButton[client] = IN_ATTACK3;
			}
		}
		default: bEntangleButton[client] = IN_ATTACK; // primary fire
	}
	new bEntangleCt=FF2_GetAbilityArgument(boss, this_plugin_name, ENTANGLECFG, 2);	//No of times skill can be used per rage
	bEntangleDuration[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ENTANGLECFG,3,5.0); //Entangle Time	
	if(!FF2_GetAbilityArgument(boss, this_plugin_name, ENTANGLECFG, 4)) // Stack skills or reset to fixed amount?
	{
		bEntangles[client]=bEntangleCt; // ALWAYS RESET
	}
	else
	{
		bEntangles[client]+=bEntangleCt; // ALLOW STACKING
	}
}

Entangle_Activator(client)
{	
	if(bEntangles[client]>0)
	{
		if (GetClientButtons(client) & bEntangleButton[client])
		{
			new Float:distance=0.0;
			new target;	
			new Float:our_pos[3];
			GetClientAbsOrigin(client,our_pos);
			target=War3_GetTargetInViewCone(client,distance);
			if(IsValidClient(target))
			{
				bEntangles[client] = (bEntangles[client]>0 ? bEntangles[client]-1 : 0);
				new Float:fVelocity[3] = {0.0,0.0,0.0};
				TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, fVelocity);
				SetEntityMoveType(target, MOVETYPE_NONE);
				
				if(view_as<bool>(FF2_GetAbilityArgument(FF2_GetBossIndex(client), this_plugin_name, ENTANGLECFG, 6)))
				{
					new weapon=GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
					if(weapon && IsValidEdict(weapon))
					{
						SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime()+bEntangleDuration[client]);
					}
					SetEntPropFloat(target, Prop_Send, "m_flNextAttack", GetGameTime()+bEntangleDuration[client]);
					SetEntPropFloat(target, Prop_Send, "m_flStealthNextChangeTime", GetGameTime()+bEntangleDuration[client]);
				}
				
				new rgba[4];
				rgba[0]=FF2_GetAbilityArgument(FF2_GetBossIndex(client), this_plugin_name, ENTANGLECFG, 7, 80);
				rgba[1]=FF2_GetAbilityArgument(FF2_GetBossIndex(client), this_plugin_name, ENTANGLECFG, 8, 255);
				rgba[2]=FF2_GetAbilityArgument(FF2_GetBossIndex(client), this_plugin_name, ENTANGLECFG, 9, 90);
				rgba[3]=FF2_GetAbilityArgument(FF2_GetBossIndex(client), this_plugin_name, ENTANGLECFG, 10, 255);
				
				CreateTimer(bEntangleDuration[client],StopEntangle,target);
				new Float:effect_vec[3];
				GetClientAbsOrigin(target,effect_vec);
				effect_vec[2]+=15.0;
				TE_SetupBeamRingPoint(effect_vec,45.0,44.0,BeamSprite,HaloSprite,0,15,bEntangleDuration[client],5.0,0.0,rgba,10,0);
				TE_SendToAll();
				effect_vec[2]+=15.0;
				TE_SetupBeamRingPoint(effect_vec,45.0,44.0,BeamSprite,HaloSprite,0,15,bEntangleDuration[client],5.0,0.0,rgba,10,0);
				TE_SendToAll();
				effect_vec[2]+=15.0;
				TE_SetupBeamRingPoint(effect_vec,45.0,44.0,BeamSprite,HaloSprite,0,15,bEntangleDuration[client],5.0,0.0,rgba,10,0);
				TE_SendToAll();
				our_pos[2]+=25.0;
				TE_SetupBeamPoints(our_pos,effect_vec,BeamSprite,HaloSprite,0,50,4.0,6.0,25.0,0,12.0,rgba,40);
				TE_SendToAll();
				PrintHintText(target,"You got Entangled!");

				
				EmitSoundToAll(entangleSound);
				EmitSoundToAll(entangleSound);
			}
			else
			{
				PrintHintText(client,"No target found!");
			}
		}
	}
}

public Action:StopEntangle(Handle:timer,any:client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
		SetEntityMoveType(client, MOVETYPE_WALK);	
}

// Otokiri Teleport (should use dynamic_point_teleport tbh instead of this)
public bool:OTP_CanInvoke(client)
{
	return true;
}

public OTP_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	bTeleportButton[client]=FF2_GetAbilityArgument(boss,this_plugin_name,TELEPORTCFG, 1);	//Activation Key
	switch(bTeleportButton[client])
	{
		case 2: bTeleportButton[client] = IN_ATTACK2; // alt-fire
		case 3: bTeleportButton[client] = IN_RELOAD;  // reload
		case 4: bTeleportButton[client] = IN_ATTACK3; // special
		case 5: // use (requires server to have "tf_allow_player_use" set to 1)
		{
			bTeleportButton[client] = IN_USE;
			if(!GetConVarBool(FindConVar("tf_allow_player_use")))
			{
				LogMessage("[War3 Abilities] WARNING! Boss requires '+use' as part of its abilities, please set 'tf_allow_player_use' to 1 on your server.cfg!");
				bTeleportButton[client] = IN_ATTACK3;
			}
		}
		default: bTeleportButton[client] = IN_ATTACK; // primary fire
	}
	new bTeleportCt=FF2_GetAbilityArgument(boss,this_plugin_name,TELEPORTCFG, 2);	//No of times skill can be used per rage
	bTeleportDistance[client]=FF2_GetAbilityArgumentFloat(boss,this_plugin_name,TELEPORTCFG,3,9999.0); //Teleport Distance
	if(!FF2_GetAbilityArgument(boss, this_plugin_name, TELEPORTCFG, 4)) // Stack skills or reset to fixed amount?
	{
		bTeleports[client]=bTeleportCt; // ALWAYS RESET
	}
	else
	{
		bTeleports[client]+=bTeleportCt; // ALLOW STACKING
	}
}

Teleport_Activator(client)
{	
	if(bTeleports[client]>0)
	{
		if (GetClientButtons(client) & bTeleportButton[client])
		{
			War3_Teleport(client,bTeleportDistance[client]);
		}
	}
}

// Otokiru Chain Lightning
public bool:CLT_CanInvoke(client)
{
	return true;
}

public CLT_Invoke(client)
{
	new boss=FF2_GetBossIndex(client);
	bChainLightningButton[client]=FF2_GetAbilityArgument(boss,this_plugin_name,LIGHTNINGCFG, 1);	//Activation Key
	switch(bChainLightningButton[client])
	{
		case 2: bChainLightningButton[client] = IN_ATTACK2; // alt-fire
		case 3: bChainLightningButton[client] = IN_RELOAD;  // reload
		case 4: bChainLightningButton[client] = IN_ATTACK3; // special
		case 5: // use (requires server to have "tf_allow_player_use" set to 1)
		{
			bChainLightningButton[client] = IN_USE;
			if(!GetConVarBool(FindConVar("tf_allow_player_use")))
			{
				LogMessage("[War3 Abilities] WARNING! Boss requires '+use' as part of its abilities, please set 'tf_allow_player_use' to 1 on your server.cfg!");
				bChainLightningButton[client] = IN_ATTACK3;
			}
		}
		default: bChainLightningButton[client] = IN_ATTACK; // primary fire
	}
	new bChainLightningCt=FF2_GetAbilityArgument(boss,this_plugin_name,LIGHTNINGCFG, 2);	//No of times skill can be used per rage
	bChainLightningDistance[client]=FF2_GetAbilityArgumentFloat(boss,this_plugin_name,LIGHTNINGCFG,3,9999.0); //Chain Lightning Distance
	bChainLightningDamage[client]=FF2_GetAbilityArgument(boss,this_plugin_name,LIGHTNINGCFG, 4);	//Damage
	if(!FF2_GetAbilityArgument(boss, this_plugin_name, LIGHTNINGCFG, 5)) // Stack skills or reset to fixed amount?
	{
		bChainLightnings[client]=bChainLightningCt; // ALWAYS RESET
	}
	else
	{
		bChainLightnings[client]+=bChainLightningCt; // ALLOW STACKING
	}
}

ChainLightning_Activator(client)
{	
	if(bChainLightnings[client] > 0)
	{
		if (GetClientButtons(client) & bChainLightningButton[client])
		{
			for(new x=1;x<=MaxClients;x++)
					bBeenHit[client][x]=false;
			DoChain(client,bChainLightningDistance[client],bChainLightningDamage[client],0);
		}
	}
}

stock IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	return IsClientInGame(client);
}

stock bool:ValidPlayer(client,bool:check_alive=false,bool:alivecheckbyhealth=false){
	if(client>0 && client<=MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		if(check_alive && !IsPlayerAlive(client))
		{
			return false;
		}
		if(alivecheckbyhealth&&GetClientHealth(client)<1){
			return false;
		}
		return true;
	}
	return false;
}

public bool:AimTargetFilter(entity,mask)
{
	return !(entity==ignoreClient);
}

public War3_GetTargetInViewCone(client,Float:max_distance)
{
	if(IsValidClient(client))
	{
		ignoreClient=client;
		if(max_distance<0.0)
			max_distance=0.0;
		new Float:PlayerEyePos[3];
		new Float:PlayerAimAngles[3];
		GetClientEyePosition(client,PlayerEyePos);
		GetClientEyeAngles(client,PlayerAimAngles);
		new Float:PlayerAimVector[3];
		GetAngleVectors(PlayerAimAngles,PlayerAimVector,NULL_VECTOR,NULL_VECTOR);
		new bestTarget=0;
		new Float:endpos[3];
		if(max_distance>0.0){
			ScaleVector(PlayerAimVector,max_distance);
		}
		else{
			ScaleVector(PlayerAimVector,56756.0);
			AddVectors(PlayerEyePos,PlayerAimVector,endpos);
			TR_TraceRayFilter(PlayerEyePos,endpos,MASK_ALL,RayType_EndPoint,AimTargetFilter);
			if(TR_DidHit())
			{
				new entity=TR_GetEntityIndex();
				if(entity>0 && entity<=MaxClients && IsClientConnected(entity) && IsPlayerAlive(entity) && GetClientTeam(client)!=GetClientTeam(entity) )
					bestTarget=entity;
			}
		}
		return bestTarget;
	}
	return 0;
}

public War3_Teleport(client,Float:distance)
{
	if(client>0)
	{
		if(IsPlayerAlive(client)&&!inteleportcheck[client])
		{
			new Float:angle[3];
			GetClientEyeAngles(client,angle);
			new Float:endpos[3];
			new Float:startpos[3];
			GetClientEyePosition(client,startpos);
			new Float:dir[3];
			GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
			ScaleVector(dir, distance);
			AddVectors(startpos, dir, endpos);
			GetClientAbsOrigin(client,oldpos[client]);
			ignoreClient=client;
			TR_TraceRayFilter(startpos,endpos,MASK_ALL,RayType_EndPoint,AimTargetFilter);
			TR_GetEndPosition(endpos);
			new Float:distanceteleport=GetVectorDistance(startpos,endpos);
			GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);///get dir again
			ScaleVector(dir, distanceteleport-33.0);
			
			AddVectors(startpos,dir,endpos);
			emptypos[0]=0.0;
			emptypos[1]=0.0;
			emptypos[2]=0.0;
			
			endpos[2]-=30.0;
			getEmptyLocationHull(client,endpos);
			
			if(GetVectorLength(emptypos)<1.0){
				PrintHintText(client,"Cannot teleport there!");
				return false; //it returned 0 0 0
			}

			TeleportEntity(client,emptypos,NULL_VECTOR,NULL_VECTOR);
			EmitSoundToAll(teleportSound);
			EmitSoundToAll(teleportSound);

			teleportpos[client][0]=emptypos[0];
			teleportpos[client][1]=emptypos[1];
			teleportpos[client][2]=emptypos[2];		
			inteleportcheck[client]=true;
			CreateTimer(0.14,checkTeleport,client);
			
			decl Float:partpos[3];
			GetClientEyePosition(client, partpos);
			partpos[2]-=20.0;	
			TeleportEffects(partpos);
			emptypos[2]+=40.0;
			TeleportEffects(emptypos);

			return true;
		}
	}
	return false;
}

public Action:checkTeleport(Handle:h,any:client){
	inteleportcheck[client]=false;
	new Float:pos[3];
	
	GetClientAbsOrigin(client,pos);
	
	if(GetVectorDistance(teleportpos[client],pos)<0.001)//he didnt move in this 0.1 second
	{
		TeleportEntity(client,oldpos[client],NULL_VECTOR,NULL_VECTOR);
		PrintHintText(client,"Cannot teleport there!");
	}
	else{
		bTeleports[client]=(bTeleports[client]>0 ? bTeleports[client]-1 : 0);
	}
}

new absincarray[]={0,4,-4,8,-8,12,-12,18,-18,22,-22,25,-25};//,27,-27,30,-30,33,-33,40,-40}; //for human it needs to be smaller

public bool:getEmptyLocationHull(client,Float:originalpos[3]){
	new Float:mins[3];
	new Float:maxs[3];
	GetClientMins(client,mins);
	GetClientMaxs(client,maxs);
	new absincarraysize=sizeof(absincarray);
	new limit=5000;
	for(new x=0;x<absincarraysize;x++){
		if(limit>0){
			for(new y=0;y<=x;y++){
				if(limit>0){
					for(new z=0;z<=y;z++){
						new Float:pos[3]={0.0,0.0,0.0};
						AddVectors(pos,originalpos,pos);
						pos[0]+=float(absincarray[x]);
						pos[1]+=float(absincarray[y]);
						pos[2]+=float(absincarray[z]);
						TR_TraceHullFilter(pos,pos,mins,maxs,MASK_SOLID,CanHitThis,client);
						//new ent;
						if(!TR_DidHit(_))
						{
							AddVectors(emptypos,pos,emptypos); ///set this gloval variable
							limit=-1;
							break;
						}
						if(limit--<0){
							break;
						}
					}
					if(limit--<0){
						break;
					}
				}
			}
			if(limit--<0){
				break;
			}
		}
	}
} 

public bool:CanHitThis(entityhit, mask, any:data)
{
	if(entityhit == data )
	{// Check if the TraceRay hit the itself.
		return false; // Don't allow self to be hit, skip this result
	}
	if(IsValidClient(entityhit)&&IsValidClient(data)&&GetClientTeam(entityhit)==GetClientTeam(data)){
		return false; //skip result, prend this space is not taken cuz they on same team
	}
	return true; // It didn't hit itself
}      

public Action:DeleteParticles(Handle:timer, any:particle)
{
    if (IsValidEntity(particle))
    {
        new String:classname[32];
        GetEdictClassname(particle, classname, sizeof(classname));
        if (StrEqual(classname, "info_particle_system", false))
        {
            RemoveEdict(particle);
        }
    }
}

TeleportEffects(Float:pos[3])
{
	ShowParticle(pos, "pyro_blast", 1.0);
	ShowParticle(pos, "pyro_blast_lines", 1.0);
	ShowParticle(pos, "pyro_blast_warp", 1.0);
	ShowParticle(pos, "pyro_blast_flash", 1.0);
	ShowParticle(pos, "burninggibs", 0.5);
}

ShowParticle(Float:possie[3], String:particlename[], Float:time)
{
    new particle = CreateEntityByName("info_particle_system");
    if (IsValidEdict(particle))
    {
        TeleportEntity(particle, possie, NULL_VECTOR, NULL_VECTOR);
        DispatchKeyValue(particle, "effect_name", particlename);
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        CreateTimer(time, DeleteParticles, particle);
    }  
}

public DoChain(client,Float:distance,dmg,last_target)
{
	new target=0;
	new Float:target_dist=distance+1.0; // just an easy way to do this
	new caster_team=GetClientTeam(client);
	new Float:start_pos[3];
	if(last_target<=0)
		GetClientAbsOrigin(client,start_pos);
	else
		GetClientAbsOrigin(last_target,start_pos);
	for(new x=1;x<=MaxClients;x++)
	{
		if(ValidPlayer(x,true)&&!bBeenHit[client][x]&&caster_team!=GetClientTeam(x))
		{
			new Float:this_pos[3];
			GetClientAbsOrigin(x,this_pos);
			new Float:dist_check=GetVectorDistance(start_pos,this_pos);
			if(dist_check<=target_dist)
			{
				// found a candidate, whom is currently the closest
				target=x;
				target_dist=dist_check;
			}
		}
	}
	if(target<=0)
	{
		PrintHintText(client,"No target found!");
	}
	else
	{
		// found someone
		bBeenHit[client][target]=true; // don't let them get hit twice
		War3_DealDamage(target,dmg,client,DMG_ENERGYBEAM,"ChainLightning");
		PrintHintText(target,"You got hit by Chain Lightning!");
		start_pos[2]+=30.0; // offset for effect
		decl Float:target_pos[3],Float:vecAngles[3];
		GetClientAbsOrigin(target,target_pos);
		target_pos[2]+=30.0;
		TE_SetupBeamPoints(start_pos,target_pos,BeamSprite,HaloSprite,0,35,1.0,25.0,25.0,0,10.0,{255,100,255,255},40);
		TE_SendToAll();
		GetClientEyeAngles(target,vecAngles);
		TE_SetupBloodSprite(target_pos, vecAngles, {200, 20, 20, 255}, 28, BloodSpray, BloodDrop);
		TE_SendToAll();
		EmitSoundToAll( lightningSound , target,_,SNDLEVEL_TRAIN);
		new new_dmg=RoundFloat(float(dmg)*0.66);
		
		DoChain(client,distance,new_dmg,target);
		bChainLightnings[client]=(bChainLightnings[client]>0 ? bChainLightnings[client]-1 : 0);
	}
}

public War3_DealDamage(victim,damage,attacker,dmg_type,String:weapon[64])
{
	if(victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage>0)
	{
		new String:dmg_str[16];
		IntToString(damage,dmg_str,16);
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(victim,"targetname","war3_hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","war3_hurtme");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(victim,"targetname","war3_donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}