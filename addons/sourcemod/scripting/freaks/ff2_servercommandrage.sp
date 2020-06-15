
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Freak Fortress 2: ServerCommandRage",
	author = "frog",
	version = "1.1"
};


public void OnPluginStart2()
{
	LogMessage("-----------------------------------------------------------------------");
	LogMessage("-Warning : rage_servercommand.ff2 is enabled, use it for your own risk-");
	LogMessage("-----------------------------------------------------------------------");
}


public Action FF2_OnAbility2(int index, const char[] plugin_name, const char[] ability_name, int action)
{
	if(!strcmp(ability_name, "rage_servercommand"))		//Execute a server command
	{
		Rage_ServerCommand(index);
	}
	return Plugin_Continue;
}


void Rage_ServerCommand(int index)
{
	int Boss=GetClientOfUserId(FF2_GetBossUserId(index));
	int rageDistance=FF2_GetAbilityArgument(index, this_plugin_name, "rage_servercommand", 1);	//rage distance
	int rageDuration=FF2_GetAbilityArgument(index, this_plugin_name, "rage_servercommand", 2);	//rage duration
	char rageStartCommand[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(index, this_plugin_name, "rage_servercommand", 3, rageStartCommand, PLATFORM_MAX_PATH); //rage start command
	char rageStartCommandParameters[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(index, this_plugin_name, "rage_servercommand", 4, rageStartCommandParameters, PLATFORM_MAX_PATH); //rage start command parameters
	char rageEndCommand[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(index, this_plugin_name, "rage_servercommand", 5, rageEndCommand, PLATFORM_MAX_PATH); //rage end command
	char rageEndCommandParameters[PLATFORM_MAX_PATH];
	FF2_GetAbilityArgumentString(index, this_plugin_name, "rage_servercommand", 6, rageEndCommandParameters, PLATFORM_MAX_PATH); //rage end command parameters
	int rageCommandMode=FF2_GetAbilityArgument(index, this_plugin_name, "rage_servercommand", 7);	//rage command mode
	
	static float pos[3];
	static float pos2[3];
	static float distance;

	TeleportEntity(Boss, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 20.0, 0.0 }));
	GetEntPropVector(Boss, Prop_Send, "m_vecOrigin", pos);
	
	switch(rageCommandMode) {
		
		case 0: {
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != FF2_GetBossTeam())
				{
					GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
					distance = GetVectorDistance(pos, pos2);
					if(distance < rageDistance)
					{
						ServerCommand("%s #%i %s", rageStartCommand, GetClientUserId(i), rageStartCommandParameters);
						if(rageDuration)
						{
							DataPack pack;
							CreateDataTimer(view_as<float>(rageDuration), EndCommand_Timer, pack, TIMER_FLAG_NO_MAPCHANGE);
							pack.WriteCell(GetClientSerial(i));
							pack.WriteString(rageEndCommand);
							pack.WriteString(rageEndCommandParameters);
						}
					}
				}	
			}
		}
		
		case 1: {
			ServerCommand("%s", rageStartCommand);
			DataPack pack;
			CreateDataTimer(float(rageDuration), EndCommandGlobal, pack);		
			pack.WriteString(rageEndCommand);
			pack.WriteString(rageEndCommandParameters);
		}
		
		case 2: {
			ServerCommand("%s #%i %s", rageStartCommand, GetClientUserId(Boss), rageStartCommandParameters);
			if(rageDuration)
			{
				DataPack pack;
				CreateDataTimer(view_as<float>(rageDuration), EndCommand_Timer, pack);
				pack.WriteCell(GetClientSerial(Boss));
				pack.WriteString(rageEndCommand);
				pack.WriteString(rageEndCommandParameters);
			}
		}
		
		case 3: {
			FakeClientCommand(Boss, "%s %s", rageStartCommand, rageStartCommandParameters);
			if(rageDuration)
			{
				DataPack pack;
				CreateDataTimer(view_as<float>(rageDuration), EndCommandBoss_Timer, pack);
				pack.WriteCell(GetClientSerial(Boss));
				pack.WriteString(rageEndCommand);
				pack.WriteString(rageEndCommandParameters);
			}
		}
	}
}


public Action EndCommandGlobal(Handle timer, DataPack pack)
{
	pack.Reset();
	char rageEndCommand[PLATFORM_MAX_PATH];
	pack.ReadString(rageEndCommand, sizeof(rageEndCommand));
	char rageEndCommandParameters[PLATFORM_MAX_PATH];
	pack.ReadString(rageEndCommandParameters, sizeof(rageEndCommandParameters));
	ServerCommand("%s %s", rageEndCommand, rageEndCommandParameters);
}


public Action EndCommandBoss_Timer(Handle timer, DataPack pack)
{
	pack.Reset();
	int Boss = GetClientFromSerial(pack.ReadCell());
	char rageEndCommand[PLATFORM_MAX_PATH];
	pack.ReadString(rageEndCommand, sizeof(rageEndCommand));
	char rageEndCommandParameters[PLATFORM_MAX_PATH];
	pack.ReadString(rageEndCommandParameters, sizeof(rageEndCommandParameters));
	
	if(IsClientInGame(Boss))
	{
		FakeClientCommand(GetClientUserId(Boss),"%s %s", rageEndCommand, rageEndCommandParameters);
	}
}

public Action EndCommand_Timer(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientFromSerial(pack.ReadCell());
	char rageEndCommand[PLATFORM_MAX_PATH];
	pack.ReadString(rageEndCommand, sizeof(rageEndCommand));
	char rageEndCommandParameters[PLATFORM_MAX_PATH];
	pack.ReadString(rageEndCommand, sizeof(rageEndCommandParameters));
	
	if(IsClientInGame(client))
	{
		ServerCommand("%s #%i %s", rageEndCommand, GetClientUserId(client), rageEndCommandParameters);
	}
}
