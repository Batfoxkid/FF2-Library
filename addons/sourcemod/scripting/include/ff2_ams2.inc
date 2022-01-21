#if defined _FF2AMS_Redux
 #endinput
#endif
#define _FF2AMS_Redux

#include <freak_fortress_2>

#define ToAMSUser(%0)		view_as<AMSUser>(%0)
#define INVALID_AMS_INDEX	-1

typedef AMSCallbackPrototype = function void(int client, StringMap infos);

enum AMSResult {
	AMS_INVALID = -1,
	AMS_Ignore,
	AMS_Deny,
	AMS_Accept,
	AMS_Overwrite
};

/**
 *	Action FF2AMS_PreAbility(int, int&, AMSResult&);
 *
 *	@brief			: Called whenever an ams rage attempt to start
 *
 * @param client	: client index
 * @param index		: Current Data
 * @param result	: new action to overwrite
 *
 * @return	Plugin_Stop will stop the rage from happening
 *				Any value other than Plugin_Continue will overwrite the indexPushTo
 *				return Plugin_Handled with new AMSResult to confirm the operation
 *
 * @call		PREFIX_CanInvoke()
 */
forward Action FF2AMS_PreAbility(int client, StringMap& data, AMSResult& result);

/**
 *	void FF2AMS_OnAbility(int, int, const char[], const char[]);
 *
 *	@brief			: called right after FF2AMS_PreAbility() when the action taken was success
 *
 * @param client	: client index
 * @param index	: Current Data
 *
 * @noreturn
 *
 * @call		AMS_REGPREFIX_Invoke()
 */
forward void FF2AMS_OnAbility(int client, const StringMap data);

/**
 *	Action FF2AMS_OnForceEnd(int, int&, AMSResult&);
 *
 *	@brief			: Called when an ability is about to be manually deactivated
 *
 * @param client	: client index
 * @param index	: Current data
 * @param plugin	: plugin_name
 * @param ability	: ability_name
 *
 * @return	Plugin_Stop or AMSResult <= AMS_Deny will stop this event from happening
 *				Any value other than Plugin_Continue will overwrite the index
 *
 * @call		PREFIX_EndAbility()
 */
forward Action FF2AMS_OnForceEnd(int client, StringMap& data, AMSResult& result);

/**
 *	void FF2AMS_PreRoundStart(int)
 *
 *	@brief			: Called before round start & when player successfully acquire pass ams checks
 *
 * @noreturn	
 */
forward void FF2AMS_PreRoundStart(int client);

/**
 *	int FF2AMS_PushToAMSEx(int, char[], const char[], const char[]);
 *
 *	@brief			: Push an ability to AMS-StringHashMap, and initialize the AMS-rage
 *
 * @param client	: client index
 * @param plugin	: plugin_name
 * @param ability	: ability_name
 * @param callbacks...
 *
 * @return			: AMS index, -1 on failure
 * @error			: invalid client index, or any empty string
 */
native int FF2AMS_PushToAMSEx(
				int client, 
				const char[] plugin, const char[] ability, 
				AMSCallbackPrototype can_invoke = INVALID_FUNCTION,
				AMSCallbackPrototype do_invoke = INVALID_FUNCTION,
				AMSCallbackPrototype do_overwrite = INVALID_FUNCTION,
				AMSCallbackPrototype do_end = INVALID_FUNCTION
			);

/**
 *	bool FF2AMS_PushToAMS(int, char[], const char[], const char[]);
 *
 *	@brief			: Push an ability to AMS-StringHashMap, and initialize the AMS-rage
 *
 * @param client	: client index
 * @param plugin	: plugin_name
 * @param ability	: ability_name
 * @param prefix	: prefix name
 * @param index		: optional: stores ability index
 *
 * @return			: true on success, false on failure
 * @error			: invalid client index, or any empty string
 */
native bool FF2AMS_PushToAMS(int client, const char[] plugin, const char[] ability, const char[] prefix);

/**
 *	ArrayList FF2AMS_GetAMSAbilities(int);
 *
 *	@brief			: given the client and ability index, return ability's StringHashMap pointer
 *
 * @param client	: client index
 *
 * @return			: a valid arraylist on success, null if player doesn't have ams
 * @error			: invalid client index
 */
native ArrayList FF2AMS_GetAMSAbilities(int client);

/**
 *	bool FF2AMS_IsAMSActivatedFor(int);
 *
 *	@brief			: return true if the following client has an AMS-rage
 *
 * @param client	: client index
 *
 * @return
 * @error			: invalid client index
 */
native bool FF2AMS_IsAMSActivatedFor(int client);

/**
 *	bool FF2AMS_IsAMSActive();
 *
 *	@brief			: return true if any boss with AMS has been initialized
 *
 * @return
 */
native bool FF2AMS_IsAMSActive();


/**
 *	AMSResult PREFIX_CanInvoke(int, int);
 *
 *	@brief			: called to check if boss can block/overwrite an ability
 *
 * @return			: AMS_Result==AMS_Overwrite will call PREFIX_OverWrite();
 *						any value other than AMS_Accept will block the ability
 */
typedef CanInvokefn = function AMSResult(int client, StringMap data);

/**
 *	void PREFIX_Invoke(int, int);
 *
 *	@brief			: called after _CanInvoke() retun AMS_Accept
 *
 * @noreturn
 */
typedef DoInvokefn = function void(int client, const StringMap data);

/**
 *	void PREFIX_Overwrite(int, int);
 *
 *	@brief			: called after _CanInvoke() retun AMS_Overwrite
 *
 * @noreturn
 */
typedef DoOverwritefn = function void(int client, const StringMap data);

/**
 *	void PREFIX_EndAbility(int, int);
 *
 *	@brief			: called when player attempt to exit from rage
 *
 * @noreturn
 */
typedef EndAbilityfn = function void(int client, const StringMap data);


methodmap AMSUser < FF2Player 
{
	public AMSUser(const int index, bool userid = false) {
		return ToAMSUser(FF2Player(index, userid));
	}
	
	property bool HasAMS {
		public get() {
			return FF2AMS_IsAMSActivatedFor(this.index);
		}
	}
	
	property ArrayList Abilities {
		public get() {
			return FF2AMS_GetAMSAbilities(this.index);
		}
	}
	
	public int Push(const char[] pl_name, const char[] ab_name, const char[] tag)
	{
		char func_str[48];
		FormatEx(func_str, sizeof(func_str), "%s_CanInvoke");
		Function can_invoke = GetFunctionByName(null, func_str);
		FormatEx(func_str, sizeof(func_str), "%s_Invoke");
		Function do_invoke = GetFunctionByName(null, func_str);
		FormatEx(func_str, sizeof(func_str), "%s_Overwrite");
		Function do_overwrite = GetFunctionByName(null, func_str);
		FormatEx(func_str, sizeof(func_str), "%s_EndAbility");
		Function on_end = GetFunctionByName(null, func_str);
		return FF2AMS_PushToAMSEx(
			this.index,
			pl_name,
			ab_name,
			view_as<AMSCallbackPrototype>(can_invoke),
			view_as<AMSCallbackPrototype>(do_invoke),
			view_as<AMSCallbackPrototype>(do_overwrite),
			view_as<AMSCallbackPrototype>(on_end)
		);
	}
}

#warning Boss is using deprecated function from AMS 'AMS_IsSubabilityReady'.
stock bool AMS_IsSubabilityReady(int boss_index, const char[] plugin_name, const char[] ability_name)
{
	int index = FF2_GetBossUserId(boss_index);
	return index == -1 ? false : AMSUser(index).HasAMS;
}

#warning Boss is using deprecated function from AMS 'AMS_InitSubability'.
stock bool AMS_InitSubability(int boss_index, int client_index, const char[] plugin_name, const char[] ability_name, const char[] prefix)
{
	if (!AMS_IsSubabilityReady(boss_index, "", ""))
		return false;
	return FF2AMS_PushToAMS(boss_index, plugin_name, ability_name, prefix);
}


static stock Handle AMS_FindPlugin(char[] plugin_name)
{
	char pl_name_iter[PLATFORM_MAX_PATH];
	Handle final_pl;
	Handle iter = GetPluginIterator();

	while (MorePlugins(iter))
	{
		Handle pl = ReadPlugin(iter);
		GetPluginFilename(pl, pl_name_iter, sizeof(pl_name_iter));
		if (StrContains(pl_name_iter, plugin_name, false) >= 0)
		{
			final_pl = pl;
			break;
		}
	}
	delete iter;
	return final_pl;
}

/**
 *	Check if plugin exists
 *	
 *	@param pluginName		Plugin Name
 *	@return					True if plugin exists, false otherwise.
 **/
stock bool PluginExists(char[] plugin_name)
{
	return AMS_FindPlugin(plugin_name);
}

/**
 *	Check if function exists
 *
 *	@param pluginName		Plugin Name
 *	@param functionName		Function name of public analogue
 *	@return					True if function exists, false otherwise.
 **/
#warning Boss is using deprecated function from AMS 'FunctionExists'.
stock bool FunctionExists(char[] plugin_name, char[] func_name)
{
	if (!strcmp(plugin_name, "ff2_sarysapub3.ff2") && !strcmp(func_name, "AMS_InitSubability"))
	{
		return FF2AMS_IsAMSActive();
	}
	else
	{
		Handle plugin = AMS_FindPlugin(plugin_name);
		return plugin ? GetFunctionByName(plugin, func_name) != INVALID_FUNCTION : false;
	}
}

#if !defined REQUIRE_PLUGIN
public __pl_INTERFACE_SetNTVOptional()
{
	MarkNativeAsOptional("FF2AMS_PushToAMS");
	MarkNativeAsOptional("FF2AMS_PushToAMSEx");
	MarkNativeAsOptional("FF2AMS_GetAMSAbilities");
	MarkNativeAsOptional("FF2AMS_IsAMSActivatedFor");
	MarkNativeAsOptional("FF2AMS_IsAMSActive");
}
#endif

#define AMS_REG(%0)(%1.%2) \
		FF2AMS_PushToAMS(%0, this_plugin_name, #%1, #%2)
		
public SharedPlugin __FF2_AMS =
{
	name = "FF2AMS",
	file = "ams_redux.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
