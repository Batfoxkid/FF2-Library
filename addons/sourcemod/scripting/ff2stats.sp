/*

freak fortress 2 status, written by nitros


that big TODO: list
Easy/ Med/ Hard gamemodes?
*/


#pragma semicolon 1

#include <sourcemod>
#include <freak_fortress_2>
#include <clientprefs>

#define PLUGIN_VERSION "0.2.1"

#define STATS_COOKIE "ff2stats_enabledforuser"
#define STATS_TABLE "player_stats"
#define FF2STATS_MINPLAYERS 8


public Plugin myinfo = {
    name="Freak Fortress Stats",
    author="Nitros",
    description="Boss stats for freak fortress 2",
    version=PLUGIN_VERSION,
    url="ben@bensimms.moe"
};


char selectedBoss[MAXPLAYERS+1][255];

Handle g_bossStatsCookie;
Handle db;

ConVar g_ff2statsenabled;


public void OnPluginStart() {
    g_bossStatsCookie = RegClientCookie(STATS_COOKIE, "Enable stats for user", CookieAccess_Public);
    InitDB(db);
    HookEvent("teamplay_round_start", OnRoundStart);
    HookEvent("teamplay_round_win", OnRoundEnd);
    HookEvent("teamplay_round_stalemate", OnRoundStalemate);
    RegConsoleCmd("ff2stats", StatsToggleCmd, "Toggle boss stats for yourself");
    RegConsoleCmd("ff2clearstats", FF2StatsClearSpecific, "Clear stats for a specific boss");
    RegConsoleCmd("ff2clearstats_all", FF2StatsClearAll, "Clear stats for all your bosses");
    RegConsoleCmd("ff2stats_debug", FF2StatsDebug, "ff2stats debugstuff");
    LoadTranslations("ff2stats.phrases");
    g_ff2statsenabled = CreateConVar("ff2stats_enabled", "1.0", "enables or disables ff2stats globally", FCVAR_PROTECTED, true, 0.0, true, 1.0);
}


public OnMapStart() {
    CreateTimer(45.0, Timer_CommandNotificationLoop, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}


int count_players() {
    int count = 0;
    for(int client = 1; client <= MaxClients; client++) {
        if (IsClientInGame(client) && !IsFakeClient(client)) {
            count++;
        }
    }
    return count;
}

bool ff2stats_enough_players() {
    return (count_players() >= FF2STATS_MINPLAYERS);
}


bool FF2Stats_IsEnabled() {
    return (FF2_IsFF2Enabled() && GetConVarBool(g_ff2statsenabled) && ff2stats_enough_players());
}

public Action OnRoundStart(Handle event, char[] name, bool dontBroadcast) {
    if (!FF2Stats_IsEnabled())  {
        if (!ff2stats_enough_players()) {
            CPrintToChatAll("{olive}[FF2stats]{default} Less than %d players, stats are disabled for this round.", FF2STATS_MINPLAYERS);
        }

        return Plugin_Continue;
    }

    CreateTimer(1.2, SetBossHealthTimer, _, TIMER_FLAG_NO_MAPCHANGE); //idk
    return Plugin_Continue;
}


public Action OnRoundStalemate(Handle event, char[] name, bool dontBroadcast) {
    if (!FF2Stats_IsEnabled())  {
        return Plugin_Continue;
    }
    for (int client = 1; client <= MaxClients; client++) {
        if (!IsValidClient(client) || !StatsEnabledForClient(client)) {
            continue;
        }

        int boss = FF2_GetBossIndex(client);
        if (boss != -1) {
            CPrintToChat(client, "{olive}[FF2stats]{default} A stalemate was encountered, your stats will remain the same.");
        }
    }
    return Plugin_Continue;
}


public Action OnRoundEnd(Handle event, char[] name, bool dontBroadcast) {
    if (!FF2Stats_IsEnabled())  {
        return Plugin_Continue;
    }
    bool bossWin = false;
    if ((GetEventInt(event, "team") == FF2_GetBossTeam())) {
        bossWin=true; // boss won
    }
    char bossName[255];
    for (int client = 1; client <= MaxClients; client++) {
        if (!IsValidClient(client) || !StatsEnabledForClient(client)) {
            continue;
        } // dont add if not counting stats

        int boss = FF2_GetBossIndex(client);
        if (boss != -1) { // we have a boss
            int bossSteamID = GetSteamAccountID(client); // steamid
            if (bossSteamID == 0) {
                continue;
            } // dont break on invalid steamid

            FF2_GetBossSpecial(boss, bossName, sizeof(bossName));
            CPrintToChatAll("{olive}[FF2stats]{default} FF2stats was enabled for %N, and a %s was counted for %s.", client, bossWin ? "win" : "loss", bossName);
            AddGameToDB(bossSteamID, bossName, bossWin);
        }
    }

    return Plugin_Continue;
}


// If a boss leaves mid-game, count as a loss
public OnClientDisconnect(int client) {
    if (!FF2Stats_IsEnabled())  {
        return;
    }

    if (!StatsEnabledForClient(client)) {
        return;
    }

    char bossName[255];
    int boss = FF2_GetBossIndex(client);
    if (boss != -1) {
        int boss_steamid = GetSteamAccountID(client);
        if (boss_steamid == 0) {
            return;
        }

        FF2_GetBossSpecial(boss, bossName, sizeof(bossName));
        CPrintToChatAll("{olive}[FF2stats]{default} A boss left the game while it was their turn and a loss was counted.");
        AddGameToDB(boss_steamid, bossName, false);
    }
}


public Action Timer_CommandNotificationLoop(Handle timer) {
    static int print_loop = 0;

    if (print_loop > 2) {
        print_loop = 0;
    }

    if (print_loop == 0) {
        CPrintToChatAll("{olive}[FF2stats]{default} Use the command !ff2stats to toggle boss stats for yourself.");
    } else if (print_loop == 1) {
        CPrintToChatAll("{olive}[FF2stats]{default} Use the command !ff2clearstats to clear your boss stats.");
    } else if (print_loop == 2) {
        CPrintToChatAll("{olive}[FF2stats]{default} Use the command !ff2clearstats_all to clear all your boss stats.");
    }

    print_loop++;

    return Plugin_Continue;
}



//  Calculate hp modifier
//
//
//    win <int>: win count for player
//    loss <int>: loss count for player
//    baseHp <int>: base hp to calculate off
int CalcHpMod(int win, int loss, int baseHp) {
    // The greater the distance between win and loss, the greater the increase
    // The greater the difference between win and loss, the greater the increase


    // if no wins and no losses, no modification
    if ((win + loss) <= 0) {
        return baseHp;
    }

    // more wins -> lose hp, more losses -> gain hp
    float sign = win > loss ? -1.0 : 1.0;


    float modifier_max = 0.3; // 30% max mod
    float modifier_fac = 1.0 / 200.0;

    float win_pct_fac = Pow(float(win - loss) / float(win + loss), 2.0);
    float win_diff_fac = FloatAbs(float(win - loss));

    float multiplier = win_pct_fac * win_diff_fac * modifier_fac * sign;
    float clamped_multiplier = F_CLAMP(multiplier, -modifier_max, modifier_max);

    int modifier = RoundFloat(baseHp * clamped_multiplier);

    return baseHp + modifier;
}


float F_CLAMP(float val, float min, float max) {
    if (val < min) {
        return min;
    } else if (val > max) {
        return max;
    } else {
        return val;
    }
}


// float F_SIGN(float val) {
//     return val>0.0 ? 1.0 : -1.0;
// }


public Action FF2StatsDebug(int client, int args) {
    int num_players = count_players();
    int enough_players = ff2stats_enough_players();
    bool enabled = FF2Stats_IsEnabled();
    PrintToChat(client, "ff2stats debug: num players: %d, enough_players: %d, enabled: %d", num_players, enough_players, enabled);

    for (int iclient = 1; iclient <= MaxClients; iclient++) {
        if (!IsValidClient(iclient)) {
            continue;
        }

        int boss = FF2_GetBossIndex(iclient);
        int steamid = GetSteamAccountID(iclient);
        bool statsenabled = StatsEnabledForClient(iclient);

        PrintToChat(client, "Client: %d %L, boss: %d, steamid: %d, stats: %d", iclient, iclient, boss, steamid, statsenabled);
    }
    return Plugin_Handled;
}


//
//
// Specific boss clearing
public Action FF2StatsClearSpecific(int client, int args) {
    if (!FF2_IsFF2Enabled() || !IsValidClient(client))
        return Plugin_Continue;

    int steamid = GetSteamAccountID(client);
    if (steamid == 0) {
        return Plugin_Handled;
    }

    char bossName[255];
    char menuItem[255];
    Handle bossKV;

    // display boss menu
    Menu statsSelectMenu = new Menu(FF2StatsClearSpecificH);
    statsSelectMenu.SetTitle("Select the boss you wish to clear stats for");

    for (int boss; (bossKV=FF2_GetSpecialKV(boss, true)); boss++) {
        if(KvGetNum(bossKV, "blocked", 0)) continue;
        if(KvGetNum(bossKV, "hidden",  0)) continue;  // blatantly copied from ff2_boss_prefs
        KvGetString(bossKV, "name", bossName, 255);

        int wins, losses;
        GetPlayerWinsAsBoss(steamid, bossName, wins, losses);
        Format(menuItem, sizeof(menuItem), "%s (%d wins, %d losses)", bossName, wins, losses);

        statsSelectMenu.AddItem(bossName, menuItem);
    }
    statsSelectMenu.ExitBackButton = true;
    statsSelectMenu.Display(client, 20);
    return Plugin_Handled;
}

public FF2StatsClearSpecificH(Handle menu, MenuAction action, int client, int selection) {
    switch (action) {
        case MenuAction_End: {
            delete menu;
        }
        case MenuAction_Select: {
            GetMenuItem(menu, selection, selectedBoss[client], sizeof(selectedBoss[]));
            Menu selectConfirmMenu = new Menu(FF2StatsClearSpecificConfirmH);
            selectConfirmMenu.SetTitle("Are you sure you want to clear stats for: %s?", selectedBoss[client]);
            selectConfirmMenu.AddItem("Yes", "Yes");
            selectConfirmMenu.AddItem("No", "No");
            selectConfirmMenu.Display(client, 20);
        }
    }
}

public FF2StatsClearSpecificConfirmH(Handle menu, MenuAction action, int client, int selection) {
    switch (action) {
        case MenuAction_End: {
            delete menu;
        }
        case MenuAction_Select: {
            if (selection==0) { // Yes
                RemoveUserStatsBossSpecific(GetSteamAccountID(client), selectedBoss[client]);
                CPrintToChat(client, "{olive}[FF2stats]{default} Your boss stats for %s have been reset!", selectedBoss[client]);
            } else {
                CPrintToChat(client, "{olive}[FF2stats]{default} Your boss stats have NOT been cleared!");
            }
        }
    }
}
//
//
//


//
//
// All boss clearing
public Action FF2StatsClearAll(int client, int args) {
    if (!FF2_IsFF2Enabled() || !IsValidClient(client)) {
        return Plugin_Continue;
    }

    // display confirm menu
    Menu statsSelectMenu = new Menu(FF2StatsClearAllConfirmH);
    statsSelectMenu.SetTitle("Confirm deleting all stats");

    statsSelectMenu.AddItem("Yes", "Yes");
    statsSelectMenu.AddItem("No", "No");
    statsSelectMenu.Display(client, 20);
    return Plugin_Handled;
}

public FF2StatsClearAllConfirmH(Handle menu, MenuAction action, int client, int selection) {
    switch (action) {
        case MenuAction_End: {
            delete menu;
        }
        case MenuAction_Select: {
            if (selection==0) { // Yes
                RemoveAllUserStats(GetSteamAccountID(client));
                CPrintToChat(client, "{olive}[FF2stats]{default} Your boss stats for ALL bosses have been reset!");
            } else {
                CPrintToChat(client, "{olive}[FF2stats]{default} Your boss stats have NOT been cleared!");
            }
        }
    }
}

//
//
//

//
//      STATS TOGGLE MENU
//
public Action StatsToggleCmd(int client, int args) {
    if (!IsValidClient(client)) {
        return Plugin_Handled;
    }

    StatsTogglePanel(client);
    return Plugin_Handled;
}


public Action StatsTogglePanel(int client) {
    Menu statsTogglePanel = new Menu(StatsTogglePanelH);
    char message[255];

    bool current_state = StatsEnabledForClient(client);

    Format(message, sizeof(message), "Enable or disable boss stats (Currently %s)", current_state ? "On" : "Off");

    statsTogglePanel.SetTitle(message);
    statsTogglePanel.AddItem("On", "On");
    statsTogglePanel.AddItem("Off", "Off");
    statsTogglePanel.Display(client, 20);
    return Plugin_Handled;
}


public StatsTogglePanelH(Handle menu, MenuAction action, int client, int selection) {
    switch (action) {
        case MenuAction_End: {
            delete menu;
        }
        case MenuAction_Select: {
            if (selection == 0) { // On
                SetStatsCookie(client, true);
            } else { // off
                SetStatsCookie(client, false);
            }
            CPrintToChat(client, "{olive}[FF2stats]{default} FF2stats are now %t for you!", selection == 0 ? "off" : "on");
        }
    }
}
//
//
//


InitDB(Handle &DBHandle) {
    char Error[255];
    DBHandle = SQL_Connect("default", true, Error, sizeof(Error));

    if (DBHandle == INVALID_HANDLE) {
        SetFailState(Error);
    }
    char Query[255];
    Format(Query, sizeof(Query), "CREATE TABLE IF NOT EXISTS %s (steamid INT, bossname TEXT, win INT)", STATS_TABLE);
    SQL_LockDatabase(DBHandle);
    SQL_FastQuery(DBHandle, Query);
    SQL_UnlockDatabase(DBHandle);
}


//  set stats cookie for client, type: bool
SetStatsCookie(int client, bool val) {
    if (!IsValidClient(client) || IsFakeClient(client) || !AreClientCookiesCached(client)) {
        return;
    }
    char cookieVal[8];
    IntToString(val, cookieVal, sizeof(cookieVal));
    SetClientCookie(client, g_bossStatsCookie, cookieVal);
}


//  Get val of stats cookie for client
bool StatsEnabledForClient(int client) {
    if (!AreClientCookiesCached(client)) { // not loaded? dont run
        return false;
    }
    char sValue[4];
    GetClientCookie(client, g_bossStatsCookie, sValue, sizeof(sValue));
    return (sValue[0] != '\0' && StringToInt(sValue));
}


// insert game into database
//
//    steamID <int>: Steamid of client
//    bossName <char[]>: name of boss (Only thing that is garunteed to not change often)
//    win <bool>:  true -> boss won, false -> boss lost
void AddGameToDB(int steamID, const char[] bossName, bool win) {
    char Query[255];

    /* Create enough space to make sure our string is quoted properly  */
    int bufferLen = strlen(bossName) * 2 + 1;
    char[] newName = new char[bufferLen];

    /* Ask the SQL driver to make sure our string is safely quoted */
    SQL_EscapeString(db, bossName, newName, bufferLen);

    /* Build the Query */
    Format(Query, sizeof(Query), "INSERT INTO %s (steamid, bossname, win) VALUES (%d, '%s', %d);", STATS_TABLE, steamID, newName, win);
    /* Execute the Query */
    SQL_LockDatabase(db);
    SQL_FastQuery(db, Query);
    SQL_UnlockDatabase(db);
}


//      Gets player win - loss stats as a certain boss
//
//    steamID <int>: steamid of player
//    bossName <char[]>: name of boss
//    win <&int>: pointer to win variable to insert win count into
//    loss <&int>: pointer to loss variable to insert loss count into
void GetPlayerWinsAsBoss(int steamID, const char[] bossName, int &win, int &loss) {
    DBResultSet hQuery;
    char Query[255];

    int bufferLen = strlen(bossName) * 2 + 1;
    char[] newName = new char[bufferLen];

    SQL_EscapeString(db, bossName, newName, bufferLen);

    Format(Query, sizeof(Query), "SELECT sum(win), count(win) - sum(win) FROM %s WHERE steamid=%d and bossname='%s';", STATS_TABLE, steamID, newName);
    if ((hQuery = SQL_Query(db, Query)) == null) {
        win = 0;  // if it errors, return 1:1 ratio
        loss = 0;
        return;
    }

    SQL_FetchRow(hQuery);
    win = SQL_FetchInt(hQuery, 0);
    loss = SQL_FetchInt(hQuery, 1);

    delete hQuery;
}


//    Gets boss win - loss stats for all players
//
//    bossName <char[]>: name of boss
//    win <&int>: pointer to win variable to insert win count into
//    loss <&int>: pointer to loss variable to insert loss count into
void GetTotalBossWins(const char[] bossName, int &win, int &loss) {
    DBResultSet hQuery;
    char Query[255];

    int bufferLen = strlen(bossName) * 2 + 1;
    char[] newName = new char[bufferLen];

    SQL_EscapeString(db, bossName, newName, bufferLen);

    Format(Query, sizeof(Query), "SELECT sum(win), count(win) - sum(win) FROM %s WHERE bossname='%s';", STATS_TABLE, newName);
    if ((hQuery = SQL_Query(db, Query)) == null) {
        win = 0;  // if it errors, return 1:1 ratio
        loss = 0;
        return;
    }

    SQL_FetchRow(hQuery);
    win = SQL_FetchInt(hQuery, 0);
    loss = SQL_FetchInt(hQuery, 1);

    delete hQuery;
}


//    Clears users stats for all bosses
RemoveAllUserStats(int steamID) {
    char Query[255];

    Format(Query, sizeof(Query), "DELETE FROM %s WHERE steamid=%d;", STATS_TABLE, steamID);

    SQL_LockDatabase(db);
    SQL_FastQuery(db, Query);
    SQL_UnlockDatabase(db);
}

//    Clears all stats for a specific boss of a player
RemoveUserStatsBossSpecific(int steamID, char[] bossName) {
    char Query[255];

    int bufferLen = strlen(bossName) * 2 + 1;
    char[] newName = new char[bufferLen];

    SQL_EscapeString(db, bossName, newName, bufferLen);

    Format(Query, sizeof(Query), "DELETE FROM %s WHERE steamid=%d AND bossname='%s';", STATS_TABLE, steamID, newName);

    SQL_LockDatabase(db);
    SQL_FastQuery(db, Query);
    SQL_UnlockDatabase(db);
}


void apply_hp_mod(int client, int boss) {
    int bossSteamID = GetSteamAccountID(client); // steamid
    if (bossSteamID == 0) {  // dont break on invalid steamid
        return;
    }

    char bossName[255];
    FF2_GetBossSpecial(boss, bossName, sizeof(bossName));

    int win, loss;
    GetPlayerWinsAsBoss(bossSteamID, bossName, win, loss);
    int bossHp = FF2_GetBossMaxHealth(boss);
    int newHp = CalcHpMod(win, loss, bossHp);

    CPrintToChatAll("{olive}[FF2stats]{default} %N has FF2stats enabled and was given a health modifier of %d (old hp: %d, new_hp: %d)! (%d wins, %d losses)", client, newHp-bossHp, bossHp, newHp, win, loss);
    // DEBUG: PrintToChatAll("Base hp: %d, new hp: %d, lives: %d", bossHp, newHp, FF2_GetBossLives(boss));
    FF2_SetBossMaxHealth(boss, newHp);
    FF2_SetBossHealth(boss, newHp*FF2_GetBossLives(boss)); // also set boss health, because it likes to break it somewhere else
}


//    Timer to hande the boss health mod after boss generation (pray this doesn't grab the last boss's hp or some garbage)
public Action SetBossHealthTimer(Handle timer) {
    for (int client; client <= MaxClients; client++) {
        if (!IsValidClient(client) || !StatsEnabledForClient(client)) {
            continue;
        }

        int boss = FF2_GetBossIndex(client);
        if (boss == -1) {
            continue;
        }

        apply_hp_mod(client, boss);
    }
}


stock bool IsValidClient(int client, bool replaycheck=true) {
    if (client<=0 || client>MaxClients) {
        return false;
    }

    if (!IsClientInGame(client)) {
        return false;
    }

    if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) {
        return false;
    }

    if (replaycheck) {
        if (IsClientSourceTV(client) || IsClientReplay(client)) {
            return false;
        }
    }
    return true;
}
