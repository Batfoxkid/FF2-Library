/*
**
*/
#if defined _FF2AMS_Redux
 #endinput
#endif
#define _FF2AMS_Redux

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
 * @param index	: AMS index
 * @param result	: new action to overwrite
 *
 * @return	Plugin_Stop will stop the rage from happening
 *				Any value other than Plugin_Continue will overwrite the index
 *				return Plugin_Handled with new AMSResult to confirm the operation
 *
 * @call		PREFIX_CanInvoke()
 */
forward Action FF2AMS_PreAbility(int client, int &index, AMSResult &result);

/**
 *	void FF2AMS_OnAbility(int, int, const char[], const char[]);
 *
 *	@brief			: called right after FF2AMS_PreAbility() when the action taken was success
 *
 * @param client	: client index
 * @param index	: AMS index
 * @param plugin	: plugin_name
 * @param ability	: ability_name
 *
 * @noreturn
 *
 * @call		PREFIX_Invoke()
 */
forward void FF2AMS_OnAbility(int client, int index, const char[] plugin, const char[] ability);

/**
 *	Action FF2AMS_OnForceEnd(int, int&, AMSResult&);
 *
 *	@brief			: Called when an ability is about to be manually deactivated
 *
 * @param client	: client index
 * @param index	: AMS index
 * @param plugin	: plugin_name
 * @param ability	: ability_name
 *
 * @return	Plugin_Stop or AMSResult <= AMS_Deny will stop this event from happening
 *				Any value other than Plugin_Continue will overwrite the index
 *
 * @call		PREFIX_EndAbility()
 */
forward Action FF2AMS_OnForceEnd(int client, int &index, AMSResult &result);

/**
 *	Action FF2AMS_PreRoundStart(int);
 *
 *	@brief			: Called before round start & when player successfully acquire pass ams checks
 *
 * @param client	: client index
 *
 * @noreturn	
 */
forward void FF2AMS_PreRoundStart(int client);


/**
 *	bool FF2AMS_InitSubAbility(int, char[], const char[], const char[]);
 *
 *	@brief			: Push an ability to AMS-StringHashMap, and initialize the AMS-rage
 *
 * @param client	: client index
 * @param plugin	: plugin_name
 * @param ability	: ability_name
 * @param prefix	: prefix name
 *
 * @return			: true on success, false on failure
 */
native bool FF2AMS_InitSubAbility(int client, char[] plugin, const char[] ability, const char[] prefix);

/**
 *	bool FF2AMS_PushToAMS(int, char[], const char[], const char[]);
 *
 *	@brief			: Push an ability to AMS-StringHashMap, and initialize the AMS-rage
 *
 * @param client	: client index
 * @param plugin	: plugin_name
 * @param ability	: ability_name
 * @param prefix	: prefix name
 *
 * @return			: true on success, false on failure
 */
native bool FF2AMS_PushToAMS(int client, char[] plugin, const char[] ability, const char[] prefix);

/**
 *	int FF2AMS_GetTotalAbilities(int);
 *
 *	@brief			: gets max number of abilities that were pushed to the following client
 *
 * @param client	: client index
 *
 * @return
 */
native int FF2AMS_GetTotalAbilities(int client);

/**
 *	StringMap FF2AMS_GetAMSHashMap(int, int);
 *
 *	@brief			: given the client and ability index, return ability's StringHashMap pointer
 *
 * @param client	: client index
 * @param index	: ability index
 *
 * @return			a valid string-hashmap on success, null on failure
 */
native StringMap FF2AMS_GetAMSHashMap(int client, int index);

/**
 *	StringMap FF2AMS_GetGlobalAMSHashMap(int);
 *
 *	@brief			: given a client index, return global AMS-StringHashMap pointer
 *
 * @param client	: client index
 *
 * @return			a valid string-hashmap on success, null on failure
 */
native StringMap FF2AMS_GetGlobalAMSHashMap(int client);

/**
 *	bool FF2AMS_IsAMSActivatedFor(int);
 *
 *	@brief			: return true if the following client has an AMS-rage
 *
 * @param client	: client index
 *
 * @return
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
 *	@brief			: called to check if boos can block/overwrite an ability
 *
 * @return			: AMS_Result==AMS_Overwrite will call PREFIX_OverWrite();
 *							any value other than AMS_Accept will block the ability
 */
typedef CanInvoke = function AMSResult(int client, int index);

/**
 *	void PREFIX_Invoke(int, int);
 *
 *	@brief			: called after _CanInvoke() retun AMS_Accept
 *
 * @noreturn
 */
typedef DoInvoke = function void(int client, int index);

/**
 *	void PREFIX_Overwrite(int, int);
 *
 *	@brief			: called after _CanInvoke() retun AMS_Overwrite
 *
 * @noreturn
 */
typedef DoOverwrite = function void(int client, int index);

/**
 *	void PREFIX_EndAbility(int, int);
 *
 *	@brief			: called when player attempt to exit from rage
 *
 * @noreturn
 */
typedef EndAbility = function void(int client, int index);

#if !defined REQUIRE_PLUGIN
public __pl_INTERFACE_SetNTVOptional()
{
	MarkNativeAsOptional("Native_InitSubAbility");
	MarkNativeAsOptional("FF2AMS_PushToAMS");
	MarkNativeAsOptional("FF2AMS_GetTotalAbilities");
	MarkNativeAsOptional("FF2AMS_GetAMSHashMap");
	MarkNativeAsOptional("FF2AMS_GetGlobalAMSHashMap");
	MarkNativeAsOptional("FF2AMS_IsAMSActivatedFor");
	MarkNativeAsOptional("FF2AMS_IsAMSActive");
}
#endif

public SharedPlugin __FF2_AMS =
{
	name = "FF2AMS",
	file = "ams-redux.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
