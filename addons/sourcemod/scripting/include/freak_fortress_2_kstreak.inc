#if defined _freak_fortress_2_kstreak_included
 #endinput
#endif
#define _freak_fortress_2_kstreak_included

/**
 * Get client's cookie value
 *
 * @param client		The client to check for
 * @param index		The cookie's index
 * @return			The cookie's value. If could not get cookie's value, returns -2
 */
native int FF2_KStreak_GetCookies(int client, int index=0);

/**
 * Sets client's cookie value
 *
 * @param client		The client to check for
 * @param toggle		The new toggle cookie's value
 * @param sheen		The new sheen cookie's value
 * @param effect		The new killstreaker cookie's value
 * @return			True if the new values are set, false otherwise
 */
native int FF2_KStreak_SetCookies(int client, int cookie0=-2, int cookie1=-2, int cookie2=-2);

/**
 * If to add an menu option to boss preference in Unofficial FF2
 *
 * @return			True if merge cvar is enabled, false otherwise
 */
native bool FF2_KStreak_Merge();

/**
 * Display a menu to a client
 *
 * @param client		The client to show
 * @param menu		The menu type
 *				0 - Main Menu
 *				1 - Toggle Menu
 *				2 - Sheen Menu
 *				3 - Killstreaker Menu
 * @noreturn
 */
native void FF2_KStreak_Menu(int client, int menu=0);

public SharedPlugin __pl_freak_fortress_2_kstreak =
{
	name="ff2_kstreak_pref",
	file="ff2_kstreak_pref.smx",
	#if defined REQUIRE_PLUGIN
		required = 1,
	#else
		required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_freak_fortress_2_kstreak_SetNTVOptional()
{
	MarkNativeAsOptional("FF2_KStreak_SetCookies");
	MarkNativeAsOptional("FF2_KStreak_GetCookies");
	MarkNativeAsOptional("FF2_KStreak_Merge");
	MarkNativeAsOptional("FF2_KStreak_Menu");
}
#endif

#file "FF2 Include: Killstreak Preferences"