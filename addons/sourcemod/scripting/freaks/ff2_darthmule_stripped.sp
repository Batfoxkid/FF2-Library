
#include <tf2_stocks>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

#pragma semicolon 1
#pragma newdecls required

int BossTeam=view_as<int>(TFTeam_Blue);

public Plugin myinfo = {
    name = "Freak Fortress 2: Completely Stripped Version of Darth's Ability Pack Fix",
    author = "Darthmule, edit by Deathreus",
    version = "1.2",
};

public void OnPluginStart2()
{
}

public Action FF2_OnAbility2(int index, const char[] plugin_name, const char[] ability_name, int action)
{
    if (!strcmp(ability_name, "rage_condition"))
        Rage_Condition(ability_name, index);
}

void Rage_Condition(const char[] ability_name, int index)
{
    int Boss        =   GetClientOfUserId(FF2_GetBossUserId(index));
    int cEffect     =   FF2_GetAbilityArgument(index,this_plugin_name,ability_name, 1);        // Effect (cases)
    float fDuration   =   FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name, 2);        // Duration (if valid)
    float Range =   FF2_GetAbilityArgumentFloat(index,this_plugin_name,ability_name, 3);   // Range
    
    static float pos[3];
    static float pos2[3];
    static float distance;
    int i;
    
    GetEntPropVector(Boss, Prop_Send, "m_vecOrigin", pos);
    for(i=1; i<=MaxClients; i++)
    {
        if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)!=BossTeam && !TF2_IsPlayerInCondition(i,TFCond_Ubercharged))
        {
            GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
            distance = GetVectorDistance( pos, pos2 );
            if (distance < Range && GetClientTeam(i)!=BossTeam)
			{
                SetVariantInt(0);
                AcceptEntityInput(i, "SetForcedTauntCam");
                
                switch(cEffect)
                {
                    case 0:
                        TF2_IgnitePlayer(i, Boss);
                    case 1: 
                        TF2_MakeBleed(i, Boss, fDuration);
                    case 2:
                        TF2_AddCondition(i, TFCond_RestrictToMelee, fDuration);
                    case 3:
                        TF2_AddCondition(i, TFCond_MarkedForDeath, fDuration);
                    case 4:
                        TF2_AddCondition(i, TFCond_Milked, fDuration);
                    case 5:
                        TF2_AddCondition(i, TFCond_Jarated, fDuration);
					case 6:
						TF2_StunPlayer(i, fDuration, 0.0, TF_STUNFLAG_BONKSTUCK, Boss);
					case 7:
						TF2_AddCondition(Boss, TFCond_DefenseBuffed, fDuration);
					case 8:
						TF2_AddCondition(Boss, TFCond_SpeedBuffAlly, fDuration);
						
                }
            }
        }    
    }
}
