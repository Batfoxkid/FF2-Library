#if defined _FF2_MANA_
 #endinput
#endif
#define _FF2_MANA_

/**
 * Adds the specified amount of mana to the desired boss
 * Use a negative amount to remove mana
 *
 * @param iBoss           The client index of the boss, not the boss index!
 * @param fAmount         Amount to add (or remove)
 * @noreturn
 * @error                 The client index was invalid
 */
native void FF2M_AddMana(int iBoss, float fAmount);

/**
 * Sets the mana pool directly to the value specified to the desired boss
 *
 * @param iBoss           The client index of the boss, not the boss index!
 * @param fAmount         Amount to add (or remove)
 * @noreturn
 * @error                 The client index was invalid
 */
native void FF2M_SetMana(int iBoss, float fAmount);

/**
 * Use this if you want to make abilities use the mana system
 * within a plugin if you need to, you should really do it by config though
 *
 * @param iBoss           The client index of the boss
 * @param iSlot           The slot you wish to assign it to (1-9)
 * @param pluginName      The name of the plugin we will be calling in to
 * @param abilityName     The name of the ability we will attempt to use
 * @param fCost           The amount of mana removed per cast, can be 0 or negative!
 * @return                True on success, false for various errors
 * @error                 Client index is invalid, slot is invalid, plugin name is empty, ability name is empty
 */
native bool FF2M_SetupAbility(int iBoss, int iSlot, const char[] pluginName, const char[] abilityName, float fCost);

/**
 * Called every 0.2 seconds just before the system adds 'mana' to the boss
 *
 * @param iBoss           The client index of the boss
 * @param flOldValue      The value before we changed
 * @param flNewValue      The value after we changed or are modifying
 * @return                Plugin_Changed to use your own value, higher to prevent mana regeneration
 */
forward Action FF2M_OnManaChanged(int iBoss, float flOldValue, float &flNewValue);

/**
 * Called after someone presses one of their keys to cast an ability
 *
 * @param iBoss           The client index of the boss
 * @param iSlot           The slot the ability is in as configured
 * @param pluginName      Plugin we are calling in to
 * @param abilityName     Name of ability to be cast
 * @param flCost          The mana cost of the ability, can be modified
 * @return                Plugin_Changed to modify cost, higher to prevent it from casting
 */
forward Action FF2M_OnAbilityCast(int iBoss, int iSlot, const char[] pluginName, const char[] abilityName, float &flCost);

public SharedPlugin __pl_FF2_Mana = {
	name = "FF2 Mana",
	file = "ff2_mana_system.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
}

#if !defined REQUIRE_PLUGIN
public void __pl_FF2_ManaSetNTVOptional()
{
	MarkNativeAsOptional("FF2M_AddMana");
	MarkNativeAsOptional("FF2M_SetMana");
	MarkNativeAsOptional("FF2M_SetupAbility");
}
#endif
