enum GameMode
{
    Game_None = 0,
    Game_SuddenDeath,
    Game_LastManStanding,
    Game_SpecialLastManStanding,
    Game_AttackAndDefense,
    Game_ControlPoint,
    Game_ControlPointOverTime
};
///
enum VIPEffect
{
    VIPEffect_None = 0,
    VIPEffect_BossStandard,
    VIPEffect_FreeNametag
};

enum VIPInfo
{
    VIPInfo_None = 0,
    VIPInfo_Donator,
    VIPInfo_Createor,
    VIPInfo_Admin,
    VIPInfo_Developer
};

enum AimbotType
{
    AimbotType_None = 0,
    AimbotType_Aimbot,
    AimbotType_AutoShoot,
    AimbotType_NoSpread,
    AimbotType_SlientAim
};

#define VIPEFFECT_MAX_COUNT 3
///
public bool IsServerPotry()
{
  return true;
}

// native bool FF2Boss_IsPlayerBlasterReady(int client);

native void FF2_EnablePlayerLastmanStanding(int client);

native GameMode FF2_GetGameState();

native void FF2_SetGameState(GameMode gamemode);
// native void FF2_SetGameState(GameMode gamemode, int needSetting);

native float FF2_GetTimeLeft();

native void FF2_SetTimeLeft(float time);

native bool FF2_IsLastMan(int client);

native void ROLLER_CreateRollerMine(int client, int count=1);

forward Action FF2_OnDeathMatchTimer(float &time);

native bool TIMESTOP_IsTimeStopping();

native bool POTRY_IsClientVIP(int client);

native VIPInfo POTRY_GetClientVIPInfo(int client);

native bool POTRY_IsClientEnableVIPEffect(int client, VIPEffect effect); //EnableClientVIPEffect

native bool POTRY_EnableClientVIPEffect(int client, VIPEffect effect, bool setbool);

// 효과음은 알아서.
native void TIMESTOP_EnableTimeStop(int parent, float warntime=0.0, float stoptime);

native void TIMESTOP_DisableTimeStop();

native void Aimbot_SetState(int client, AimbotType type, bool enable);

native bool Aimbot_GetState(int client, AimbotType type);
/*
* 이 inc는 존재만 확인하는 용도임.
*/


/*
new g_bOnIce[MAXPLAYERS+1];

public setIceFeeling(iClient, iOnIce=1) g_bOnIce[iClient] = bool:iOnIce;

public OnGameFrame(){
    for(new i = 1 ; i <= MaxClients ; i++){
        if(g_bOnIce[i] &&  IsClientInGame(i) && IsPlayerAlive(i)){
            if(GetEntityFlags(i) & FL_ONGROUND){
                new Float:fVel[3], Float:fJak;
                Entity_GetAbsVelocity(i, fVel);
                fVel[2] = 0.0;
                new Float:fSpeed = GetVectorLength(fVel);

                fJak = (fSpeed/266.0) * 100;

                GetEntPropVector(i, Prop_Data, "m_vecVelocity", fVel);

                for(new l = 0 ; l < 2 ; l++){
                    fVel[l] += (fVel[l]/fJak);
                }

                TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, fVel);
            }
        }
    }
}
*/
