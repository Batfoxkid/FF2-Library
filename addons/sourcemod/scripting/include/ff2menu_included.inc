#if defined FF2_MENU_INCLUDED
	#endinput
#endif
#define FF2_MENU_INCLUDED

/**
 * Called whenever a boss triggers a menu rage
 *
 * @param boss				boss' index
 * @param pts				current points
 * @param Plugin_Name	
 * @param Ability_Name
 *
 * @return 				Plugin_Stop, to completly block pts reduction and ability execution
 *					Plugin_Handled or Plugin_Changed to handle the rage execution
 *					Plugin_Continue to ignore everything and let the ability execute by itself
 *
 */
forward Action FF2MenuRage_OnStartRage(int boss, int &pts, const char[] Plugin_Name, const char[] Ability_Name);

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
forward Action FF2MenuRage_OnTakeDamageAlive(int client, int victim, float damage);

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
 * Retreive a StringMap value for a client 
 *
 * @param client			client's index
 * @param context			Key String 
 *
 * @return				the value inside the key. negative/false for failure
 *
 */
native any FF2MenuRage_PeekValue(int client, const char[] context);

/**
 * Set a StringMap value for a client 
 *
 * @param client			client's index
 * @param context			Key String 
 * @param newVal			value to set 
 *
 * @return				true on success, false otherwise.
 *
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
 *
 */
native void FF2MenuRage_SetCooldown(int client, int index, float newVal);

/**
 * Search for an ability index 
 *
 * @param boss				boss' index
 * @param Plugin_Name			rage's index
 * @param Ability_Name			value to set 
 *
 * @return				ability's index, -1 otherwise
 *
 */
native int FF2MenuRage_FindIndex(int boss = 0, const char[] Plugin_Name, const char[] Ability_Name);

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
 * @param buttonmode				button mode
 *
 * @return					true on success, false otherwise
 *
 */
native bool FF2MenuRage_DoAbiltiy(int client, int pts, const char[] Plugin_Name, const char[] Ability_Name, int slot, int buttonmode = 0);
