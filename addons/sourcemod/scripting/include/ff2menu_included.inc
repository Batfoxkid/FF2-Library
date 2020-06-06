#if defined _FF2MenuRage_INCLUDED
	#endinput
#endif
#define _FF2MenuRage_INCLUDED

#include <ff2ability>

/**
 * Called right before round start
 *
 * @param boss				client index
 *
 * @noreturn
 */
forward Action FF2MenuRage_PreRoundStart(int client);

/**
 * Called whenever a boss triggers a menu rage
 *
 * @param boss				boss' index
 * @param pts				current points
 * @param cd				cooldown that will soon be applied
 * @param Plugin_Name	
 * @param Ability_Name
 *
 * @return 				Plugin_Stop, to completly block pts reduction and ability execution
 *					Plugin_Handled or Plugin_Changed to handle the rage execution
 *					Plugin_Continue to ignore everything and let the ability execute by itself
 *
 */
forward Action FF2MenuRage_OnStartRage(int boss, int& pts, int& cd, const char[] Plugin_Name, const char[] Ability_Name);

/**
 * Called whenever a boss takes Damage
 *
 * @param client			boss with menu rage
 * @param victim			victim index
 * @param damage			current received damage	
 *
 * @return				Any value higher than Plugin_Continue to handle the call
 *
 */
forward Action FF2MenuRage_OnTakeDamageAlive(int client, int victim, int damage);

/**
 * Called whenever a victim dies 
 *
 * @param victim			current points
 * @param client			boss with menu rage
 *
 * @return				Any value higher than Plugin_Continue to handle the call
 *
 */
forward Action FF2MenuRage_OnPlayerDeath(int victim, int attacker);


/**
 * Gets player's MenuMap 
 *
 * @param client			client's index
 *
 * @return					Hashmap, null on failure
 * @error					Invalid client index
 */
native FF2Parse FF2MenuRage_GetHashMap(int client);

/**
 * Retreive a StringMap value for a client 
 *
 * @param client			client's index
 * @param context			Key String 
 *
 * @return					the value inside the key. negative/false for failure
 * @error					Invalid client index or context
 */
native any FF2MenuRage_PeekValue(int client, const char[] context);

/**
 * Set a StringMap value for a client 
 *
 * @param client			client's index
 * @param context			Key String 
 * @param newVal			value to set 
 *
 * @return					true on success, false otherwise.
 * @error					Invalid client index or context
 */
native bool FF2MenuRage_SetValue(int client, const char[] context, any newVal);

/**
 * Set a rage cooldown 
 *
 * @param client			client's index
 * @param index				rage's index
 * @param newVal			value to set 
 *
 * @noreturn
 * @error					Invalid client index or rage
 */
native void FF2MenuRage_SetCooldown(int client, int index, float newVal);

/**
 * @return					true if any boss with menu rage is active. false otherwise
 */
native bool FF2MenuRage_IsActive();

/**
 *
 * @param client				client's index	
 *
 * @return					if boss has a menu rage abiility
 *
 */
native bool FF2MenuRage_HasAbility(int client);

/**
 * force a player to provoke a rage according to the Menu rage rules
 *
 * @param client				client's index
 * @param pts					pts to use
 * @param Plugin_Name			
 * @param Ability_Name			
 * @param slot					rage slot 
 *
 * @return						true on success, false otherwise
 * @error						Invalid client index or string
 */
native bool FF2MenuRage_DoAbiltiy(int client, int pts, const char[] Plugin_Name, const char[] Ability_Name, int slot);


#if !defined REQUIRE_PLUGIN
public __pl_FF2MenuRage_SetNTVOptional()
{
	MarkNativeAsOptional("FF2MenuRage_GetHashMap");
	MarkNativeAsOptional("FF2MenuRage_PeekValue");
	MarkNativeAsOptional("FF2MenuRage_SetValue");
	MarkNativeAsOptional("FF2MenuRage_SetCooldown");
	MarkNativeAsOptional("FF2MenuRage_IsActive");
	MarkNativeAsOptional("FF2MenuRage_HasAbility");
	MarkNativeAsOptional("FF2MenuRage_DoAbiltiy");
}
#endif

public SharedPlugin __pl_FF2MenuRage =
{
	name = "FF2MenuRage",
	file = "menurage_platform.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
