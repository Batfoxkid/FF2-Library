/**
 * Ability Management System Include
 *
 * Due to load order issues, need to use reflection for these accessor methods.
 **/


#if defined _ff2_ams_included
 #endinput
#endif
#define _ff2_ams_included

#include <freak_fortress_2>

/**
 *	Retrieves the plugin's handle
 *	Useful for calling other subplugins, if using the reflective method.
 *	
 *	@param pluginName		Plugin Name
 *	@return 				Handle of plugin
 **/
stock Handle FindPlugin(char[] pluginName)
{
	char buffer[256];
	char path[PLATFORM_MAX_PATH];
	Handle iter=GetPluginIterator();
	Handle pl=null;
	while(MorePlugins(iter))
	{
		pl=ReadPlugin(iter);
		Format(path, sizeof(path), "%s", pluginName);
		GetPluginFilename(pl, buffer, sizeof(buffer));
		if(StrContains(buffer, path, false) >= 0)
		{
			break;
		}
		else
		{
			pl=null;
		}
	}
	delete iter;
	return pl;
}

/**
 *	Check if plugin exists
 *	
 *	@param pluginName		Plugin Name
 *	@return					True if plugin exists, false otherwise.
 **/
stock bool PluginExists(char[] pluginName)
{
	Handle plugin=FindPlugin(pluginName);
	if(plugin!=null) return true;
	return false;
}

/**
 *	Check if function exists
 *
 *	@param pluginName		Plugin Name
 *	@param functionName		Function name of public analogue
 *	@return					True if function exists, false otherwise.
 **/
stock bool FunctionExists(char[] pluginName, char[] functionName)
{
	Handle plugin=FindPlugin(pluginName);
	if(plugin!=null)
	{
		Function func=GetFunctionByName(plugin, functionName);
		if(func!=INVALID_FUNCTION)
		{
			return true;
		}
		return false;
	}
	else
	{
		return false;
	}
}

/**
 *	Autodetect whether AMS will be used for managing RAGE, or a normal E / G RAGE.
 *
 *	@param bossIdx			Boss Index
 *	@param pluginName		Plugin Name
 *	@param abilityName		Ability Name
 *	@return 				True if ability is ready to be used with AMS, otherwise false
 **/
stock bool AMS_IsSubabilityReady(int bossIdx, char[] pluginName, char[] abilityName)
{
	return FunctionExists("ff2_sarysapub3.ff2", "AMS_InitSubability") && FF2_HasAbility(bossIdx, "ff2_sarysapub3", "ability_management_system") && !FF2_GetAbilityArgument(bossIdx, pluginName, abilityName, 0);
}

/**
 *	Initialize the AMS-supported ability or AMS sub-ability
 *
 *	@param bossIdx			Boss Index
 *	@param clientIdx		Client Index
 *	@param pluginName		Plugin Name
 *	@param abilityName		Ability Name
 *	@param prefix			Prefix (up to 5 characters long) used for <prefix>_CanInvoke(clientIdx) && <prefix>_Invoke(clientIdx) analogues
 *	@noreturn
 **/
stock void AMS_InitSubability(int bossIdx, int clientIdx, const char[] pluginName, const char[] abilityName, const char[] prefix)
{
	Handle plugin=FindPlugin("ff2_sarysapub3.ff2");
	if(plugin!=null)
	{
		Function func=GetFunctionByName(plugin, "AMS_InitSubability");
		if(func!=INVALID_FUNCTION)
        {
			Call_StartFunction(plugin, func);
			Call_PushCell(bossIdx);
			Call_PushCell(clientIdx);
			Call_PushString(pluginName);
			Call_PushString(abilityName);
			Call_PushString(prefix);
			Call_Finish();
		}
		else
		{
			LogError("ERROR: Unable to initialize ff2_sarysapub3:AMS_InitSubability()");
		}
	}
	else
	{
		LogError("ERROR: Unable to initialize ff2_sarysapub3:AMS_InitSubability(). Make sure this plugin exists!");
	}
}