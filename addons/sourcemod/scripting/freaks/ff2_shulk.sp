#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <sdkhooks>

#pragma newdecls required

/*
    "shulk_monadoart"
    arg1 = 능력 설정 시간
    arg2 = 능력 지속 시간
    arg3 = 능력 과부화 시간
*/
enum MonadoArt
{
    Monado_Overloaded=-1,
    Monado_None=0,
    Monado_Jump,
    Monado_Speed,
    Monado_Shield,
    Monado_Buster,
    Monado_Smash // 5
};

bool ButtonPressed[MAXPLAYERS+1];
bool EnableMonado[MAXPLAYERS+1];
int ClientMonado[MAXPLAYERS+1];
int ClientPreMonado[MAXPLAYERS+1];

float MonadoPreloadTimer[MAXPLAYERS+1];
float MonadoOverloadTimer[MAXPLAYERS+1];
float MonadoSetTimer[MAXPLAYERS+1];

public Plugin myinfo=
{
    name="Freak Fortress 2 : Shulk's Abilities",
    author="Nopied",
    description="....",
    version="2016_07_21",
};

public void OnPluginStart2()
{
    HookEvent("arena_round_start", RoundStarted, EventHookMode_Post);
}

public Action RoundStarted(Handle event, const char[] name, bool dont)
{
    for(int client=1; client<=MaxClients; client++)
    {
        if(IsClientInGame(client) && FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, "shulk_monadoart"))
        {
        	static char name[48]; FF2_GetBossName(FF2_GetBossIndex(client), name, sizeof(name));
        	LogMessage("--------------------------------------------------------------------");
        	LogMessage("[FF2] A boss with unfinished rage ff2_shulk.ff2 is active this round\n" ... 
        				"Boss Name : %s", name);
        	LogMessage("--------------------------------------------------------------------");
            EnableMonado[client]=true;
            ClientMonado[client]=0;
            MonadoOverloadTimer[client]=0.0;
            CreateTimer(0.1, MonadoTimer, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public Action MonadoTimer(Handle timer, int client)
{
    if(!EnableMonado[client] || !IsClientInGame(client) || !IsPlayerAlive(client) || CheckRoundState() != 1)
    {
        EnableMonado[client]=false;
        ClientMonado[client]=0;
        MonadoOverloadTimer[client]=0.0;
        return Plugin_Stop;
    }

    Handle Hud=CreateHudSynchronizer();
    char message[120];
    char abilityString[40];
    int rgba[4];

    if(MonadoPreloadTimer[client] > 0.0)
    {
        MonadoPreloadTimer[client] -= 0.1;
        if(MonadoPreloadTimer[client] <= 0.0)
        {
            ClientMonado[client] = ClientPreMonado[client];
            ClientPreMonado[client] = 0;
            MonadoSetTimer[client] = FF2_GetAbilityArgumentFloat(FF2_GetBossIndex(client), this_plugin_name, "shulk_monadoart", 2, 20.0);

            SDKHook(client, SDKHook_PreThink, OnPlayerTink);

//            break;
        }

        GetColorOfMonado(view_as<MonadoArt>(0), rgba);
        GetAbilityStringOfMonado(view_as<MonadoArt>(ClientPreMonado[client]), abilityString, sizeof(abilityString));
        Format(message, sizeof(message), "모나도 아츠 준비 중: %s", abilityString);
    }
    else if(MonadoOverloadTimer[client] > 0.0)
    {
      MonadoOverloadTimer[client] -= 0.1;
      if(MonadoOverloadTimer[client] <= 0.0)
      {
        ClientMonado[client] = 0;
//        break;
      }

      GetColorOfMonado(view_as<MonadoArt>(0), rgba);
      Format(message, sizeof(message), "모나도 아츠 과부화!");
    }
    else if(MonadoSetTimer[client] > 0.0)
    {
        MonadoSetTimer[client] -= 0.1;
        if(MonadoSetTimer[client] <= 0.0)
        {
            ClientMonado[client] = -1;
            MonadoOverloadTimer[client] = FF2_GetAbilityArgumentFloat(FF2_GetBossIndex(client), this_plugin_name, "shulk_monadoart", 3, 10.0);
            SDKUnhook(client, SDKHook_PreThink, OnPlayerTink);
//            break;
        }

        GetColorOfMonado(GetClientMonadoStat(client), rgba);
        GetAbilityStringOfMonado(GetClientMonadoStat(client), abilityString, sizeof(abilityString));

        Format(message, sizeof(message), "모나도 아츠 활성화: %s", abilityString);
    }

    SetHudTextParams(-1.0, 0.65, 0.11, rgba[0], rgba[1], rgba[2], rgba[3], 0, 0.35, 0.0, 0.2);

    ShowSyncHudText(client, Hud, message);

    CloseHandle(Hud);
    return Plugin_Continue;
}

public void OnPlayerTink(int client)
{
    switch(GetClientMonadoStat(client))
    {
      case Monado_Jump:
      {
          TF2_AddCondition(client, TFCond_MarkedForDeath, 0.1);
//         if()
      }

      case Monado_Speed:
      {

      }

      case Monado_Shield:
      {

      }

      case Monado_Buster:
      {

      }

      case Monado_Smash:
      {

      }
    }
}

public Action FF2_OnAbility2(int boss, const char[] plugin_name, const char[] ability_name, int status)
{

}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!EnableMonado[client] || !IsBoss(client)) return Plugin_Continue;

	if(GetClientMonadoStat(client) == Monado_None && buttons & IN_RELOAD)
	{
		if(ButtonPressed[client])
			return Plugin_Continue;

		ButtonPressed[client]=true;

		ClientPreMonado[client]++;
		if(ClientPreMonado[client] > 5)
			ClientPreMonado[client] = 0;

		if(ClientPreMonado[client] == 0)
			MonadoPreloadTimer[client] = FF2_GetAbilityArgumentFloat(FF2_GetBossIndex(client), this_plugin_name, "shulk_monadoart", 1, 2.5);

    }
	else ButtonPressed[client] = false;
	return Plugin_Continue;
}

MonadoArt GetClientMonadoStat(int client)
{
    return view_as<MonadoArt>(ClientMonado[client]);
}

public void GetAbilityStringOfMonado(MonadoArt monado, char[] abilityString, int buffer)
{
    switch(monado)
    {
      case Monado_Overloaded:
      {
          Format(abilityString, buffer, "과부하");
      }
      case Monado_None:
      {
          Format(abilityString, buffer, "능력 없음");
      }
      case Monado_Jump:
      {
          Format(abilityString, buffer, "점프");
      }
      case Monado_Speed:
      {
          Format(abilityString, buffer, "스피드");
      }
      case Monado_Shield:
      {
          Format(abilityString, buffer, "쉴드");
      }
      case Monado_Buster:
      {
          Format(abilityString, buffer, "버스터");
      }
      case Monado_Smash:
      {
          Format(abilityString, buffer, "스매쉬");
      }
    }
}

public void GetColorOfMonado(MonadoArt monado, int rgba[4])
{
    switch(monado)
    {
      case Monado_Overloaded:
      {
          rgba[0]=140;
          rgba[1]=140;
          rgba[2]=140;
          rgba[3]=255;
      }
      case Monado_None:
      {
          rgba[0]=255;
          rgba[1]=255;
          rgba[2]=255;
          rgba[3]=255;
      }
      case Monado_Jump:
      {
          rgba[0]=171;
          rgba[1]=242;
          rgba[2]=0;
          rgba[3]=255;
      }
      case Monado_Speed:
      {
          rgba[0]=0;
          rgba[1]=216;
          rgba[2]=255;
          rgba[3]=255;
      }
      case Monado_Shield:
      {
          rgba[0]=255;
          rgba[1]=228;
          rgba[2]=0;
          rgba[3]=255;
      }
      case Monado_Buster:
      {
          rgba[0]=255;
          rgba[1]=0;
          rgba[2]=221;
          rgba[3]=255;
      }
      case Monado_Smash:
      {
          rgba[0]=255;
          rgba[1]=0;
          rgba[2]=0;
          rgba[3]=255;
      }
    }
}

public int CheckRoundState()
{
	switch(GameRules_GetRoundState())
	{
		case RoundState_Init, RoundState_Pregame:
		{
			return -1;
		}
		case RoundState_StartGame, RoundState_Preround:
		{
			return 0;
		}
		case RoundState_RoundRunning, RoundState_Stalemate:  //Oh Valve.
		{
			return 1;
		}
		default:
		{
			return 2;
		}
	}
//	return -1;  //Compiler bug-doesn't recognize 'default' as a valid catch-all
}

bool IsBoss(int client)
{
    return FF2_GetBossIndex(client) != -1;
}
