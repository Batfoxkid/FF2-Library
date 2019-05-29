#pragma semicolon 1

#include <sourcemod>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>

public Plugin:myinfo = {
	name	= "Freak Fortress 2: Server Wide Rage Sound",
	author	= "Deathreus",
	version = "1.2",
};

public OnPluginStart2()
{
	// Y u no let me compile without this
}

public Action:FF2_OnAbility2(iBoss, const String:pluginName[], const String:abilityName[], iStatus)
{
	if (!strcmp(abilityName, "rage_sound"))
	{
		decl String:sRageSound[5][PLATFORM_MAX_PATH];
		decl String:sBuffer[PLATFORM_MAX_PATH*5];
		FF2_GetAbilityArgumentString(iBoss, pluginName, abilityName, 1, sBuffer, sizeof(sBuffer));
		ExplodeString(sBuffer, " ; ", sRageSound, 5, PLATFORM_MAX_PATH);
		
		new iCount = 0;
		for (new i = 0; i < 5; i++)
		{
			if (strlen(sRageSound[i]) > 3)
			{
				PrecacheSound(sRageSound[i]);
				iCount++;
			}
			
			if (iCount == 0)
				return Plugin_Continue;
		}
		
		new iRand = GetRandomInt(0, iCount-1);
		EmitSoundToAll(sRageSound[iRand]);
	}
	return Plugin_Continue;
}