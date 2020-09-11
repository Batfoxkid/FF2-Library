#if defined _MenuManager_included
 #endinput
#endif
#define _MenuManager_included

/**
 * @param variable	Variable index to set:
 *				0 - Is plugin enabled this round
 *				1 - Is Unofficial FF2 running
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetBool(int variable, bool value);

/**
 * @param variable	Variable index to set:
 *				0 - Is plugin enabled this round
 *				1 - Is Unofficial FF2 running
 *
 * @return		Value of variable
 */
native bool MA_GetBool(int variable);

/**
 * @param variable	Variable index to set:
 *				3 - Starting amount of players
 *				4 - Current amount of players
 *				5 - Current amount of players on the BossTeam
 *				6 - Current amount of players on the MercTeam
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetInteger(int variable, int value);

/**
 * @param variable	Variable index to set:
 *				0 - Maximum spells per a boss
 *				1 - Maximum manas per a boss
 *				2 - Maximum abilities per a spell
 *				3 - Starting amount of players
 *				4 - Current amount of players
 *				5 - Current amount of players on the BossTeam
 *				6 - Current amount of players on the MercTeam
 *
 * @return		Value of variable
 */
native int MA_GetInteger(int variable);

/**
 * @param boss		Boss index
 * @param variable	Variable index to set:
 *				0 - Is the boss using the ability
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetBossBool(int boss, int variable, bool value);

/**
 * @param boss		Boss index
 * @param variable	Variable index to set:
 *				0 - Is the boss using the ability
 *
 * @return		Value of variable
 */
native bool MA_GetBossBool(int boss, int variable);

/**
 * @param boss		Boss index
 * @param variable	Variable index to set:
 *				0 - Amount of spells the boss have
 *				1 - Weapon slot/index the boss have to hold to show the menu
 *				2 - Amount of spells to show at a time
 *				3 - When to refresh the amount of spells
 *				4 - Wether to block and/or hide the RAGE HUD
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetBossInteger(int boss, int variable, int value);

/**
 * @param boss		Boss index
 * @param variable	Variable index to set:
 *				0 - Amount of spells the boss have
 *				1 - Weapon slot/index the boss have to hold to show the menu
 *				2 - Amount of spells to show at a time
 *				3 - When to refresh the amount of spells
 *				4 - Wether to block and/or hide the RAGE HUD
 *
 * @return		Value of variable
 */
native int MA_GetBossInteger(int boss, int variable);

/**
 * @param boss		Boss index
 * @param variable	Variable index to set:
 *				0 - Menu interval
 *				1 - When the next menu pops up (Engine Time)
 *				2 - Spell cooldowns effected by Jarate
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetBossFloat(int boss, int variable, float value);

/**
 * @param boss		Boss index
 * @param variable	Variable index to set:
 *				0 - Menu interval
 *				1 - When the next menu pops up (Engine Time)
 *				2 - Spell cooldowns effected by Jarate
 *
 * @return		Value of variable
 */
native float MA_GetBossFloat(int boss, int variable);

/**
 * @param boss		Boss index
 * @param variable	Variable index to set:
 *				0 - Boss's default name
 *				1 - Boss's name of the client's language
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetBossString(int boss, int variable, char[] value);

/**
 * @param boss		Boss index
 * @param variable	Variable index to set:
 *				0 - Boss's default name
 *				1 - Boss's name of the client's language
 * @param value		Value of variable
 * @param valueLength	Length of string to set
 *
 * @return		Length of variable
 */
native int MA_GetBossString(int boss, int variable, char[] value, int valueLength);

/**
 * @param mana		Mana index
 * @param variable	Variable index to set:
 *				0 - Maximum amount of mana
 *				1 - Current amount of mana
 *				2 - Displayed amount of mana
 *				3 - Maximum change in displayed mana every menu tick
 *				4 - Amount gained on kill
 *				5 - Amount gained per damage dealt
 *				6 - Amount gained per damage taken
 *				7 - Amount every menu tick
 *				8 - Amount gained upon being airblasted
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetManaFloat(int boss, int mana, int variable, float value);

/**
 * @param mana		Mana index
 * @param variable	Variable index to set:
 *				0 - Maximum amount of mana
 *				1 - Current amount of mana
 *				2 - Displayed amount of mana
 *				3 - Maximum change in displayed mana every menu tick
 *				4 - Amount gained on kill
 *				5 - Amount gained per damage dealt
 *				6 - Amount gained per damage taken
 *				7 - Amount every menu tick
 *				8 - Amount gained upon being airblasted
 *
 * @return		Value of variable
 */
native float MA_GetManaFloat(int boss, int mana, int variable);

/**
 * @param mana		Mana index
 * @param variable	Variable index to set:
 *				0 - Name of mana
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetManaString(int boss, int mana, int variable, char[] value);

/**
 * @param mana		Mana index
 * @param variable	Variable index to set:
 *				0 - Name of mana
 * @param value		Value of variable
 * @param valueLength	Length of string to set
 *
 * @return		Length of variable
 */
native int MA_GetManaString(int boss, int mana, int variable, char[] value, int valueLength);

/**
 * @param spell		Spell index
 * @param variable	Variable index to set:
 *				0 - Unique index value
 *				1 - If disabled spell
 * @param value		Value to set variable
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetSpellBool(int boss, int spell, int variable, bool value);

/**
 * @param spell		Spell index
 * @param variable	Variable index to set:
 *				0 - Is the unique index used
 *				1 - If disabled spell
 *
 * @return		Value of variable
 */
native bool MA_GetSpellBool(int boss, int spell, int variable);

/**
 * @param spell		Spell index
 * @param variable	Variable index to set:
 *				0 - Ability slot (Uses slot param)
 *				1 - Ability buttonmode (Uses slot param)
 *				2 - Spell casting rules
 *				3 - Unique index value
 * @param value		Value to set variable
 * @param slot		Slot of ability to use
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetSpellInteger(int boss, int spell, int variable, int value, int slot=0);

/**
 * @param spell		Spell index
 * @param variable	Variable index to set:
 *				0 - Ability slot (Uses slot param)
 *				1 - Ability buttonmode (Uses slot param)
 *				2 - Spell casting rules
 *				3 - Unique index value
 * @param slot		Slot of ability to use
 *
 * @return		Value of variable
 */
native int MA_GetSpellInteger(int boss, int spell, int variable, int slot=0);

/**
 * @param spell		Spell index
 * @param variable	Variable index to set:
 *				0 - Cost of spell (Uses slot param)
 *				1 - When the spell can be used again (Engine Time)
 *				2 - Cooldown when spell is used
 *				3 - Cooldown of all other spells when used
 * @param value		Value to set variable
 * @param slot		Mana to use
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetSpellFloat(int boss, int spell, int variable, float value, int slot=0);

/**
 * @param spell		Spell index
 * @param variable	Variable index to set:
 *				0 - Cost of spell (Uses slot param)
 *				1 - When the spell can be used again (Engine Time)
 *				2 - Cooldown when spell is used
 *				3 - Cooldown of all other spells when used
 * @param slot		Mana to use
 *
 * @return		Value of variable
 */
native float MA_GetSpellFloat(int boss, int spell, int variable, int slot=0);

/**
 * @param spell		Spell index
 * @param variable	Variable index to set:
 *				0 - Spell name
 *				1 - Ability name (Uses slot param)
 *				2 - Plugin name (Uses slot param)
 *				3 - Particle effect
 *				4 - Particle attachment location
 * @param value		Value to set variable
 * @param slot		Slot of ability to use
 *
 * @return		true if variable found, false otherwise
 */
native bool MA_SetSpellString(int boss, int spell, int variable, char[] value, int slot=0);

/**
 * @param spell		Spell index
 * @param variable	Variable index to set:
 *				0 - Spell name
 *				1 - Ability name (Uses slot param)
 *				2 - Plugin name (Uses slot param)
 *				3 - Particle effect
 *				4 - Particle attachment location
 * @param value		Value of variable
 * @param valueLength	Length of string to set
 * @param slot		Slot of ability to use
 *
 * @return		Length of variable
 */
native int MA_GetSpellString(int boss, int spell, int variable, char[] value, int valueLength, int slot=0);

/**
 * Refreshes the boss's current spell list
 *
 * @param boss		Boss index
 * @param spells	Amount of spells given
 * @param call		Call the MA_OnRefresh forwards
 *
 * @noreturn
 */
native void MA_Refresh(int boss, int spells, bool call=true);

/**
 * Sets up boss casting (make sure the boss has the menu manager ability)
 *
 * @param boss		Boss index
 * @param call		Call the MA_OnMakeBoss forwards
 *
 * @noreturn
 */
native void MA_MakeBoss(int boss, bool call=true);

/**
 * Called when a boss casts a spell
 *
 * @param boss		Boss index
 * @param name   	Name of spell
 * @param spell		Spell index
 *
 * @return		Action output
 *				Plugin_Continue - Continues, nothing is changed
 *				Plugin_Changed - Continues, spell index is changed
 *				Plugin_Handled - Ignores using FF2_DoAbility, spell index is changed
 *				Plugin_Stop - Stops the casting, nothing is spent, no cooldowns given
 */
forward Action MA_OnCastSpell(int boss, char[] name, int &spell);

/**
 * Called after a boss casts a spell
 *
 * @param boss		Boss index
 * @param name   	Name of spell
 * @param spell		Spell index
 * @param blocked	If MA_OnCastSpell returned Plugin_Handled
 *
 * @noreturn
 */
forward void MA_OnCastSpellPost(int boss, char[] name, int spell, bool blocked);

/**
 * Called when a boss's spell list is refreshed
 *
 * @param boss		Boss index
 * @param spells	Amount of spells to give
 *
 * @return		Action output
 *				Plugin_Continue - Continues, nothing is changed
 *				Plugin_Changed - Continues, amount of spells is changed
 *				Plugin_Handled - Disables all spells
 *				Plugin_Stop - Keeps the same list of spells
 */
forward Action MA_OnRefresh(int boss, int &spells);

/**
 * Called after a boss's spell list is refreshed
 *
 * @param boss		Boss index
 * @param spells	Amount of spells given
 *
 * @noreturn
 */
forward void MA_OnRefreshPost(int boss, int spells);

/**
 * Called when a boss is about to set up for menu manager
 *
 * @param boss		Boss index
 * @param late		false if the boss was setup on arena_round_start or plugin just loaded, true otherwises
 *
 * @return		Action output
 *				Plugin_Continue - Continues
 *				Plugin_Handled - Setups boss but doesn't activate MenuThink
 *				Plugin_Stop - Stops making the boss
 */
forward Action MA_OnMakeBoss(int boss, bool late);

/**
 * Called after a boss has all settings set up for menu manager
 *
 * @param boss		Boss index
 * @param late		false if the boss was setup on arena_round_start or plugin just loaded, true otherwises
 *
 * @noreturn
 */
forward void MA_OnMakeBossPost(int boss, bool late);

/**
 * Called on every menu tick for the boss
 *
 * @param boss		Boss index
 * @param force		Ignore holding weapon requirement
 * @param nextMenu	Engine time for next menu tick
 *
 * @return		Action output
 *				Plugin_Continue - Continues, nothing is changed
 *				Plugin_Changed - Continues, variables changed
 *				Plugin_Handled - Disables all spells
 *				Plugin_Stop - Keeps the same list of spells
 */
forward Action MA_OnMenuThink(int boss, bool &force, float &nextMenu);

/**
 * Called after every menu tick for the boss
 *
 * @param boss		Boss index
 * @param nextMenu	Engine time for next menu tick
 *
 * @noreturn
 */
forward void MA_OnMenuThinkPost(int boss, float nextMenu);

public void __pl_MenuManager_SetNTVOptional()
{
	MarkNativeAsOptional("MA_SetBool");
	MarkNativeAsOptional("MA_GetBool");
	MarkNativeAsOptional("MA_SetInteger");
	MarkNativeAsOptional("MA_GetInteger");
	MarkNativeAsOptional("MA_SetBossBool");
	MarkNativeAsOptional("MA_GetBossBool");
	MarkNativeAsOptional("MA_SetBossInteger");
	MarkNativeAsOptional("MA_GetBossInteger");
	MarkNativeAsOptional("MA_SetBossFloat");
	MarkNativeAsOptional("MA_GetBossFloat");
	MarkNativeAsOptional("MA_SetBossString");
	MarkNativeAsOptional("MA_GetBossString");
	MarkNativeAsOptional("MA_SetManaFloat");
	MarkNativeAsOptional("MA_GetManaFloat");
	MarkNativeAsOptional("MA_SetManaString");
	MarkNativeAsOptional("MA_GetManaString");
	MarkNativeAsOptional("MA_SetSpellBool");
	MarkNativeAsOptional("MA_GetSpellBool");
	MarkNativeAsOptional("MA_SetSpellInteger");
	MarkNativeAsOptional("MA_GetSpellInteger");
	MarkNativeAsOptional("MA_SetSpellFloat");
	MarkNativeAsOptional("MA_GetSpellFloat");
	MarkNativeAsOptional("MA_SetSpellString");
	MarkNativeAsOptional("MA_GetSpellString");
	MarkNativeAsOptional("MA_Refresh");
	MarkNativeAsOptional("MA_MakeBoss");
}