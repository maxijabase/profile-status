#include <sourcemod>
#include <regex>
#include "multicolors"
#include "include/steamworks"
#include "include/stocksoup/version"
#include "include/profilestatus"
#include "include/autoexecconfig"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.3.5"

#define CHOICE1 "hoursTable"
#define CHOICE2 "bansTable"
#define CHOICE3 "levelTable"

public Plugin myinfo = {
	
	name = "[ANY] Profile Status", 
	author = "ratawar", 
	description = "Limits server entrance to players.", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?p=2697650"
};

// Global {

/* Handles */

ConVar
	g_cvEnable, 
	g_cvApiKey;
ConVar
	g_cvDatabase;
ConVar
	g_cvEnableHourCheck, 
	g_cvMinHours, 
	g_cvHoursWhitelistEnable, 
	g_cvHoursWhitelistAuto;
ConVar
	g_cvEnableBanDetection, 
	g_cvBansWhitelist, 
	g_cvVACDays, 
	g_cvVACAmount, 
	g_cvCommunityBan, 
	g_cvGameBans, 
	g_cvEconomyBan;
	
ConVar
	g_cvEnableLevelCheck,
	g_cvLevelWhitelistEnable,
	g_cvLevelWhitelistAuto,
	g_cvMinLevel,
	g_cvMaxLevel;
	
ConVar
	g_cvEnablePrivateProfileCheck;

Database
	g_Database;

/* Variables */

static char
	cAPIKey[64], 
	cvDatabase[64], 
	EcBan[10];
	
char DBDRIVER[16];
bool g_bIsLite;

int minHours, 
	vacDays, 
	vacAmount, 
	gameBans, 
	economyBan;
	
static int 
	c = 3;

//}

/* On Plugin Start */

public void OnPluginStart() {
	
	/* Setting file */
	
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("ProfileStatus");
	
	/* Plugin Version */
	AutoExecConfig_CreateConVar("sm_profilestatus_version", PLUGIN_VERSION, "Plugin version.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	/* Basic Data */
	g_cvEnable 				 = AutoExecConfig_CreateConVar("sm_profilestatus_enable", "1", "Enable the plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvApiKey  			 = AutoExecConfig_CreateConVar("sm_profilestatus_apikey", "", "Your Steam API key (https://steamcommunity.com/dev/apikey)", FCVAR_PROTECTED);
	
	/* Database Name */
	g_cvDatabase 			 = AutoExecConfig_CreateConVar("sm_profilestatus_database", "storage-local", "Database name. Change this value only if you're using another database set in databases.cfg");
	
	/* Hour Check Module */
	g_cvEnableHourCheck 	 = AutoExecConfig_CreateConVar("sm_profilestatus_hours_enable", "1", "Enable Hour Checking functions?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvMinHours 			 = AutoExecConfig_CreateConVar("sm_profilestatus_hours_minhours", "", "Minimum of hours requiered to enter the server.");
	g_cvHoursWhitelistEnable = AutoExecConfig_CreateConVar("sm_profilestatus_hours_whitelist_enable", "1", "Enable Hours Check Whitelist?");
	g_cvHoursWhitelistAuto   = AutoExecConfig_CreateConVar("sm_profilestatus_hours_whitelist_auto", "1", "Whitelist members that have been checked automatically?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	/* Ban Check Module */
	g_cvEnableBanDetection   = AutoExecConfig_CreateConVar("sm_profilestatus_bans_enable", "1", "Enable Ban Checking functions?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvBansWhitelist 		 = AutoExecConfig_CreateConVar("sm_profilestatus_bans_whitelist", "1", "Enable Bans Whitelist?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvVACDays 			 = AutoExecConfig_CreateConVar("sm_profilestatus_vac_days", "0", "Minimum days since the last VAC ban to be allowed into the server (0 for zero tolerance).");
	g_cvVACAmount 			 = AutoExecConfig_CreateConVar("sm_profilestatus_vac_amount", "0", "Amount of VAC bans tolerated until prohibition (0 for zero tolerance).");
	g_cvCommunityBan 		 = AutoExecConfig_CreateConVar("sm_profilestatus_community_ban", "0", "0- Don't kick if there's a community ban | 1- Kick if there's a community ban");
	g_cvGameBans 			 = AutoExecConfig_CreateConVar("sm_profilestatus_game_bans", "5", "Amount of game bans tolerated until prohibition (0 for zero tolerance).");
	g_cvEconomyBan 			 = AutoExecConfig_CreateConVar("sm_profilestatus_economy_bans", "0", "0- Don't check for economy bans | 1- Kick if user is economy \"banned\" only. | 2- Kick if user is in either \"banned\" or \"probation\" state.", _, true, 0.0, true, 2.0);
											
	/* Steam Level Check Module */
	g_cvEnableLevelCheck	 = AutoExecConfig_CreateConVar("sm_profilestatus_level_enable", "1", "Enable Steam Level Checking functions", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvLevelWhitelistEnable = AutoExecConfig_CreateConVar("sm_profilestatus_level_whitelist_enable", "1", "Enable Steam Level Check Whitelist?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvLevelWhitelistAuto   = AutoExecConfig_CreateConVar("sm_profilestatus_level_whitelist_auto", "1", "Whitelist members that have been checked automatically?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvMinLevel			 = AutoExecConfig_CreateConVar("sm_profilestatus_minlevel", "", "Minimum level required to enter the server.");
	g_cvMaxLevel			 = AutoExecConfig_CreateConVar("sm_profilestatus_maxlevel", "", "Maximum level tolerated to enter the server (can be left blank for no maximum).");
	
	/* Private Profile Check Module */
	g_cvEnablePrivateProfileCheck  = AutoExecConfig_CreateConVar("sm_profilestatus_privateprofile_enable", "1", "Block Fully Private Profiles?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	RegAdminCmd("sm_ps", Command_Generic, ADMFLAG_GENERIC, "Generic Plugin Command.");
	
	LoadTranslations("profilestatus.phrases");
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
}

/* Global CVAR Assigns and Checks */

public void OnConfigsExecuted() {
	
	g_cvApiKey.GetString(cAPIKey, sizeof(cAPIKey));
	g_cvDatabase.GetString(cvDatabase, sizeof(cvDatabase));
	
	minHours   = g_cvMinHours.IntValue;
	vacDays	= g_cvVACDays.IntValue;
	vacAmount  = g_cvVACAmount.IntValue;
	gameBans   = g_cvGameBans.IntValue;
	economyBan = g_cvEconomyBan.IntValue;
	
	if (!g_cvEnable.BoolValue)
		SetFailState("[PS] Plugin disabled!");
	
	if (!IsAPIKeyCorrect(cAPIKey))
		SetFailState("[PS] Please set your Steam API Key properly!");
	
	if (g_cvHoursWhitelistEnable.BoolValue || g_cvBansWhitelist.BoolValue || g_cvLevelWhitelistEnable.BoolValue)
		Database.Connect(SQL_ConnectDatabase, cvDatabase);
	else
		PrintToServer("[PS] No usage of database detected! Aborting database connection.");
}

/* Database connection, driver check and tables creation */

public void SQL_ConnectDatabase(Database db, const char[] error, any data) {
	
	if (db == null) {
		
		LogError("[PS] Could not connect to database %s! Error: %s", cvDatabase, error);
		PrintToServer("[PS] Could not connect to database %s! Error: %s", cvDatabase, error);
		return;
		
	}
	
	PrintToServer("[PS] Database connection to \"%s\" successful!", cvDatabase);
	g_Database = db;
	GetDriver();
	CreateTable();
	
}

public void GetDriver() {
	
	SQL_ReadDriver(g_Database, DBDRIVER, sizeof(DBDRIVER));
	g_bIsLite = strcmp(DBDRIVER, "sqlite") == 0 ? true : false;
	
}

public void CreateTable() {
	
	char sQuery1[256];
	char sQuery2[256];
	char sQuery3[256];
	
	if (g_bIsLite) {
		StrCat(sQuery1, sizeof(sQuery1), "CREATE TABLE IF NOT EXISTS ps_whitelist(");
		StrCat(sQuery1, sizeof(sQuery1), "entry INTEGER PRIMARY KEY, ");
		StrCat(sQuery1, sizeof(sQuery1), "steamid VARCHAR(17), ");
		StrCat(sQuery1, sizeof(sQuery1), "unique (steamid));");
		
		StrCat(sQuery2, sizeof(sQuery2), "CREATE TABLE IF NOT EXISTS ps_whitelist_bans(");
		StrCat(sQuery2, sizeof(sQuery2), "entry INTEGER PRIMARY KEY, ");
		StrCat(sQuery2, sizeof(sQuery2), "steamid VARCHAR(17), ");
		StrCat(sQuery2, sizeof(sQuery2), "unique (steamid));");
		
		StrCat(sQuery3, sizeof(sQuery3), "CREATE TABLE IF NOT EXISTS ps_whitelist_level(");
		StrCat(sQuery3, sizeof(sQuery3), "entry INTEGER PRIMARY KEY, ");
		StrCat(sQuery3, sizeof(sQuery3), "steamid VARCHAR(17), ");
		StrCat(sQuery3, sizeof(sQuery3), "unique (steamid));");
		
		g_Database.Query(SQL_CreateTable, sQuery1);
		g_Database.Query(SQL_CreateTable, sQuery2);
		g_Database.Query(SQL_CreateTable, sQuery3);
		return;
	}
	
	StrCat(sQuery1, sizeof(sQuery1), "CREATE TABLE IF NOT EXISTS ps_whitelist(");
	StrCat(sQuery1, sizeof(sQuery1), "entry INT NOT NULL AUTO_INCREMENT, ");
	StrCat(sQuery1, sizeof(sQuery1), "steamid VARCHAR(17) UNIQUE, ");
	StrCat(sQuery1, sizeof(sQuery1), "PRIMARY KEY (entry));");
	
	StrCat(sQuery2, sizeof(sQuery2), "CREATE TABLE IF NOT EXISTS ps_whitelist_bans(");
	StrCat(sQuery2, sizeof(sQuery2), "entry INT NOT NULL AUTO_INCREMENT, ");
	StrCat(sQuery2, sizeof(sQuery2), "steamid VARCHAR(17) UNIQUE, ");
	StrCat(sQuery2, sizeof(sQuery2), "PRIMARY KEY (entry));");
	
	StrCat(sQuery3, sizeof(sQuery3), "CREATE TABLE IF NOT EXISTS ps_whitelist_level(");
	StrCat(sQuery3, sizeof(sQuery3), "entry INT NOT NULL AUTO_INCREMENT, ");
	StrCat(sQuery3, sizeof(sQuery3), "steamid VARCHAR(17) UNIQUE, ");
	StrCat(sQuery3, sizeof(sQuery3), "PRIMARY KEY (entry));");
	
	g_Database.Query(SQL_CreateTable, sQuery1);
	g_Database.Query(SQL_CreateTable, sQuery2);
	g_Database.Query(SQL_CreateTable, sQuery3);	
	
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data) {
	
	if (db == null || results == null) {
		
		LogError("[PS] Create Table Query failure! %s", error);
		PrintToServer("[PS] Create Table Query failure! %s", error);
		return;
		
	}
	
	c--;
	if (!c) PrintToServer("[PS] Tables successfully created or were already created!");
	
}

/* Hour Check Module */

public void QueryHoursWhitelist(int client, char[] auth) {
	
	char WhitelistReadQuery[512];
	Format(WhitelistReadQuery, sizeof(WhitelistReadQuery), "SELECT * FROM ps_whitelist WHERE steamid='%s';", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(GetClientUserId(client));
	
	g_Database.Query(SQL_QueryHoursWhitelist, WhitelistReadQuery, pack);
	
}

public void SQL_QueryHoursWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	
	if (!client) 
		return;
	
	if (db == null || results == null) {
		
		LogError("[PS] Error while checking if user %s is hour whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is hour whitelisted! %s", auth, error);
		return;
		
	}
	
	if (!results.RowCount) {
		
		RequestHours(client, auth);
		return;
		
	}
}

public void RequestHours(int client, char[] auth) {
	
	char URL[512];
	Format(URL, sizeof(URL), "http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=%s&include_played_free_games=1&appids_filter[0]=%i&steamid=%s&format=json", cAPIKey, GetAppID(), auth);
	
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, URL);
	
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestHours_OnHTTPResponse);
	SteamWorks_SendHTTPRequest(request);
	
}

public void RequestHours_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		
		PrintToServer("[PS] HTTP Hours Request failure!");
		delete request;
		return;
		
	}
	
	int client = GetClientOfUserId(userid);
	
	if (!client) {
		
		delete request;
		return;
		
	}
	
	int bufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
	char[] responseBody = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBody, bufferSize);
	delete request;
	
	int playedTime = GetPlayerHours(responseBody);
	int totalPlayedTime = playedTime / 60;
	
	if (!totalPlayedTime) {
		
		KickClient(client, "%t", "Invisible Hours");
		return;
		
	}
	
	if (minHours != 0) {
		
		if (totalPlayedTime < minHours) {
			
			KickClient(client, "%t", "Not Enough Hours", totalPlayedTime, minHours);
			return;
		}
		
	}
	
	if (g_cvHoursWhitelistAuto.BoolValue) {
		
		char auth[40];
		GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
		AddPlayerToHoursWhitelist(auth);
		
	}
	
}

public void AddPlayerToHoursWhitelist(char[] auth) {
	
	char WhitelistWriteQuery[512];
	Format(WhitelistWriteQuery, sizeof(WhitelistWriteQuery), "INSERT INTO ps_whitelist (steamid) VALUES (%s);", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	
	g_Database.Query(SQL_AddPlayerToHoursWhitelist, WhitelistWriteQuery, pack);
	
}

public void SQL_AddPlayerToHoursWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	delete pack;
	
	if (db == null || results == null) {
		
		LogError("[PS] Error while trying to hour whitelist user %s! %s", auth, error);
		PrintToServer("[PS] Error while trying to hour whitelist user %s! %s", auth, error);
		return;
		
	}
	
	PrintToServer("[PS] Player %s successfully hour whitelisted!", auth);
	
}

/* Ban Check Module */

public void QueryBansWhitelist(int client, char[] auth) {
	
	char BansWhitelistQuery[256];
	Format(BansWhitelistQuery, sizeof(BansWhitelistQuery), "SELECT * FROM ps_whitelist_bans WHERE steamid='%s'", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(GetClientUserId(client));
	
	g_Database.Query(SQL_QueryBansWhitelist, BansWhitelistQuery, pack);
	
}

public void SQL_QueryBansWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	
	if (!client) 
		return;
	
	if (db == null || results == null) {
		
		LogError("[PS] Error while checking if user %s is ban whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is ban whitelisted! %s", auth, error);
		return;
		
	}
	
	if (!results.RowCount) {
		
		RequestBans(client, auth);
		return;
		
	}
	
	PrintToServer("[PS] User %s is ban whitelisted! Skipping ban check.", auth);
	
}

public void RequestBans(int client, char[] auth) {
	
	char URL[512];
	Format(URL, sizeof(URL), "http://api.steampowered.com/ISteamUser/GetPlayerBans/v1?key=%s&steamids=%s", cAPIKey, auth);

	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, URL);
	
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestBans_OnHTTPResponse);
	SteamWorks_SendHTTPRequest(request);
	
}

public void RequestBans_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		
		PrintToServer("[PS] HTTP Bans Request failure!");
		delete request;
		return;
		
	}
	
	int client = GetClientOfUserId(userid);
	
	if (!client) {
		
		delete request;
		return;
		
	}
	
	int bufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
	char[] responseBodyBans = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBodyBans, bufferSize);
	delete request;
	
	if (g_cvEnableBanDetection.BoolValue) {
		
		if (IsVACBanned(responseBodyBans)) {
			
			if (!GetDaysSinceLastVAC(responseBodyBans) || !GetVACAmount(responseBodyBans))
				KickClient(client, "%t", "VAC Kicked");
				
			else if (GetDaysSinceLastVAC(responseBodyBans) < vacDays)
				KickClient(client, "%t", "VAC Kicked Days", vacDays);
				
			else if (GetVACAmount(responseBodyBans) > vacAmount)
				KickClient(client, "%t", "VAC Kicked Amount", vacAmount);
				
		}
		
		if (IsCommunityBanned(responseBodyBans))
			if (g_cvCommunityBan.BoolValue)
				KickClient(client, "%t", "Community Ban Kicked");
		
		if (GetGameBans(responseBodyBans) > gameBans)
			KickClient(client, "%t", "Game Bans Exceeded", gameBans);
		
		GetEconomyBans(responseBodyBans, EcBan);
		
		if (economyBan == 1)
			if (StrContains(EcBan, "banned", false) != -1)
				KickClient(client, "%t", "Economy Ban Kicked");
				
		if (economyBan == 2)
			if (StrContains(EcBan, "banned", false) != -1 || StrContains(EcBan, "probation", false) != -1)
				KickClient(client, "%t", "Economy Ban/Prob Kicked");
		
	}
	
}

/* Steam Level Check Module */

public void QueryLevelWhitelist(int client, char[] auth) {
	
	char LevelWhitelistQuery[256];
	Format(LevelWhitelistQuery, sizeof(LevelWhitelistQuery), "SELECT * FROM ps_whitelist_level WHERE steamid='%s'", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(GetClientUserId(client));
	
	g_Database.Query(SQL_QueryLevelWhitelist, LevelWhitelistQuery, pack);
	
}

public void SQL_QueryLevelWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	
	if (!client) 
		return;
	
	if (db == null || results == null) {
		
		LogError("[PS] Error while checking if user %s is level whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is level whitelisted! %s", auth, error);
		return;
		
	}
	
	if (!results.RowCount) {
		
		RequestLevel(client, auth);
		return;
		
	}
	
	PrintToServer("[PS] User %s is level whitelisted! Skipping level check.", auth);
	
}

void RequestLevel(int client, char[] auth) {
	
	char URL[512];
	Format(URL, sizeof(URL), "http://api.steampowered.com/IPlayerService/GetSteamLevel/v1/?key=%s&steamid=%s", cAPIKey, auth);
	
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, URL);
	
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestLevel_OnHTTPResponse);
	SteamWorks_SendHTTPRequest(request);
	
}

public void RequestLevel_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		
		PrintToServer("[PS] HTTP Steam Level Request failure!");
		delete request;
		return;
		
	}
	
	int client = GetClientOfUserId(userid);

	if (!client) {
		
		delete request;
		return;
		
	}
	
	int bufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
	char[] responseBodyLevel = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBodyLevel, bufferSize);
	delete request;
	
	int minlevel = g_cvMinLevel.IntValue;
	int maxlevel = g_cvMaxLevel.IntValue;
	int level = GetSteamLevel(responseBodyLevel);
	
	if (level == -1) {
		
		KickClient(client, "%t", "Invisible Level");
		return;
		
	}
	
	else if (level < minlevel) {
		
		KickClient(client, "%t", "Low Level", level, minlevel);
		return;
		
	}
	
	if (maxlevel != 0) {
		
		if (level > maxlevel) {
			
			KickClient(client, "%t", "High Level", level, maxlevel);
			return;
			
		}
		
	}
	
	if (g_cvLevelWhitelistAuto.BoolValue) {
		
		char auth[40];
		GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
		AddPlayerToLevelWhitelist(auth);
		
	}
	
}

public void AddPlayerToLevelWhitelist(char[] auth) {
	
	char LevelWriteQuery[512];
	Format(LevelWriteQuery, sizeof(LevelWriteQuery), "INSERT INTO ps_whitelist_level (steamid) VALUES (%s);", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	
	g_Database.Query(SQL_AddPlayerToLevelWhitelist, LevelWriteQuery, pack);
	
}

public void SQL_AddPlayerToLevelWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	delete pack;
	
	if (db == null || results == null) {
		
		LogError("[PS] Error while trying to level whitelist user %s! %s", auth, error);
		PrintToServer("[PS] Error while trying to level whitelist user %s! %s", auth, error);
		return;
		
	}
	
	PrintToServer("[PS] Player %s successfully level whitelisted!", auth);
	
}

/* Private Profile Check Module */

public void CheckPrivateProfile(int client, char[] auth) {
	
	char URL[512];
	Format(URL, sizeof(URL), "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s", cAPIKey, auth);
	
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, URL);
	
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestPrivate_OnHTTPResponse);
	SteamWorks_SendHTTPRequest(request);
	
}

public void RequestPrivate_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		
		PrintToServer("[PS] HTTP Steam Private Profile Request failure!");
		delete request;
		return;
		
	}
	
	int client = GetClientOfUserId(userid);

	if (!client) {
		
		delete request;
		return;
		
	}
	
	int bufferSize;
	SteamWorks_GetHTTPResponseBodySize(request, bufferSize);
	char[] responseBodyPrivate = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBodyPrivate, bufferSize);
	delete request;

	if (GetCommVisibState(responseBodyPrivate) == 1)
		KickClient(client, "%t", "No Private Profile");
		
}

/* Whitelist Menu */

public void OpenWhitelistMenu(int client) {
	
	Menu menu = new Menu(mPickWhitelist, MENU_ACTIONS_ALL);
	menu.AddItem(CHOICE1, "Hours Whitelist");
	menu.AddItem(CHOICE2, "Bans Whitelist");
	menu.AddItem(CHOICE3, "Level Whitelist");
	menu.ExitButton = true;
	menu.Display(client, 20);
	
}

public int mPickWhitelist(Menu menu, MenuAction action, int param1, int param2) {
	
	switch (action) {
		
		case MenuAction_Display: {
			
			char buffer[255];
			Format(buffer, sizeof(buffer), "%t", "Select a Table");
			
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
			
		}
		
		case MenuAction_Select: {
			
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			MenuQuery(param1, info);
			
		}
		
		case MenuAction_End: {
			
			delete menu;
			
		}
		
	}
	
	return 0;
}

public void MenuQuery(int client, char[] info) {
	
	char table[32];
	
	if (StrEqual(info, "hoursTable", false))
		Format(table, sizeof(table), "ps_whitelist");
		
	if (StrEqual(info, "bansTable", false))
		Format(table, sizeof(table), "ps_whitelist_bans");
		
	if (StrEqual(info, "levelTable", false))
		Format(table, sizeof(table), "ps_whitelist_level");
	
	char query[256];
	g_Database.Format(query, sizeof(query), "SELECT * FROM %s", table);
	
	DataPack pack = new DataPack();
	pack.WriteString(table);
	pack.WriteCell(GetClientUserId(client));
	
	g_Database.Query(SQL_MenuQuery, query, pack);
	
}

public void SQL_MenuQuery(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char table[32];
	pack.ReadString(table, sizeof(table));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	
	if (!client) 
		return;
	
	if (db == null || results == null) {
		
		LogError("[PS] Error while querying %s for menu display! %s", table, error);
		PrintToServer("[PS] Error while querying %s for menu display! %s", table, error);
		CPrintToChat(client, "[PS] Error while querying %s for menu display! %s", table, error);
		return;
		
	}
		
	char type[16];
	
	if (StrEqual(table, "hoursTable", false))
		Format(type, sizeof(type), "Hours");
		
	if (StrEqual(table, "bansTable", false))
		Format(type, sizeof(type), "Bans");
		
	if (StrEqual(table, "levelTable", false))
		Format(type, sizeof(type), "Level");
			
	int entryCol, steamidCol;
	
	results.FieldNameToNum("entry", entryCol);
	results.FieldNameToNum("steamid", steamidCol);
	
	Menu menu = new Menu(TablesMenu, MENU_ACTIONS_ALL);
	menu.SetTitle("Showing %s Whitelist", type);
		
	char steamid[32], id[16];
	int count;
	
	if (!results.FetchRow()) {
		
		CPrintToChat(client, "%t", "No Results");
		OpenWhitelistMenu(client);
		return;
		
	} 
	
	else {
		
		do {
			
			count++;
			results.FetchString(steamidCol, steamid, sizeof(steamid));
			IntToString(count, id, sizeof(id));
			menu.AddItem(id, steamid, ITEMDRAW_RAWLINE);
			
		} while (results.FetchRow());
		
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
		
	}
	
}

public int TablesMenu(Menu menu, MenuAction action, int param1, int param2) {
	
	switch (action) {
		
		case MenuAction_Cancel: {
			
			if (param2 == MenuCancel_ExitBack) {
				
				OpenWhitelistMenu(param1);
				delete menu;
				
			}
			
		}
		
	}
	
	return 0;
	
}

/* Command */

public Action Command_Generic(int client, int args) {
	
	char arg1[30], arg2[30], arg3[30];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	
	if (StrEqual(arg1, "whitelist", false)) {
		
		if (!client) {
			
			ReplyToCommand(client, "You cannot open the menu whitelist from console!");
			return Plugin_Handled;
			
		} 
		
		else {
			
			OpenWhitelistMenu(client);
			return Plugin_Handled;
			
		}
		
	}
	
	if (!StrEqual(arg1, "hours", false) && !StrEqual(arg1, "bans", false) && !StrEqual(arg1, "level", false)) {
		
		CReplyToCommand(client, "%t", "Command Generic Usage");
		return Plugin_Handled;
		
	}
	
	if ((!StrEqual(arg2, "add", false) && !StrEqual(arg2, "remove", false) && !StrEqual(arg2, "check", false)) || StrEqual(arg3, "")) {
		
		CReplyToCommand(client, "%t", "Command Generic Usage");
		return Plugin_Handled;
		
	}
	
	if (!SimpleRegexMatch(arg3, "^7656119[0-9]{10}$")) {
		
		CReplyToCommand(client, "%t", "Invalid STEAMID");
		return Plugin_Handled;
		
	}
	
	Command(arg1, arg2, arg3, client);
	return Plugin_Handled;
	
}

public void Command(char[] arg1, char[] arg2, char[] arg3, int client) {
	
	char query[256], table[32];
	
	if (StrEqual(arg1, "hours", false))
		Format(table, sizeof(table), "ps_whitelist");
		
	if (StrEqual(arg1, "bans", false))
		Format(table, sizeof(table), "ps_whitelist_bans");
		
	if (StrEqual(arg1, "level", false))
		Format(table, sizeof(table), "ps_whitelist_level");
		
	
	if (StrEqual(arg2, "add"))
		Format(query, sizeof(query), "INSERT INTO %s (steamid) VALUES (%s);", table, arg3);
		
	if (StrEqual(arg2, "remove"))
		Format(query, sizeof(query), "DELETE FROM %s WHERE steamid='%s';", table, arg3);
		
	if (StrEqual(arg2, "check"))
		Format(query, sizeof(query), "SELECT * FROM %s WHERE steamid='%s';", table, arg3);
		
	
	DataPack pack = new DataPack();
	
	if (!client)
		pack.WriteCell(client);
		
	else
		pack.WriteCell(GetClientUserId(client));
		
	pack.WriteString(arg1);
	pack.WriteString(arg2);
	pack.WriteString(arg3);
	
	g_Database.Query(SQL_Command, query, pack);
	
}

public void SQL_Command(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	int client;
	int whateverarrived = pack.ReadCell();
	
	if(whateverarrived == 0)
		client = whateverarrived;
		
	else
		client = GetClientOfUserId(whateverarrived);
		
	char arg1[30], arg2[30], arg3[30];
	pack.ReadString(arg1, sizeof(arg1));
	pack.ReadString(arg2, sizeof(arg2));
	pack.ReadString(arg3, sizeof(arg3));
	delete pack;
	
	if (StrEqual(arg2, "add")) {
		
		if (db == null) {
			
			LogError("[PS] Error while adding %s to the %s whitelist! %s", arg3, arg1, error);
			PrintToServer("[PS] Error while adding %s to the %s whitelist! %s", arg3, arg1, error);
			CReplyToCommand(client, "[PS] Error while adding %s to the %s whitelist! %s", arg3, arg1, error);
			return;
			
		}
		
		if (results == null) {
			
			if (StrEqual(arg1, "hours", false)) {
				
				CReplyToCommand(client, "%t", "Nothing Hour Added", arg3);
				return;
				
			}
			
			if (StrEqual(arg1, "bans", false)) {
				
				CReplyToCommand(client, "%t", "Nothing Ban Added", arg3);
				return;
				
			}
			
			if (StrEqual(arg1, "level", false)) {
				
				CReplyToCommand(client, "%t", "Nothing Level Added", arg3);
				return;
			}
			
		}
		
		if (StrEqual(arg1, "hours", false)) {
			
			CReplyToCommand(client, "%t", "Successfully Hour Added", arg3);
			return;
			
		}
		
		if (StrEqual(arg1, "bans", false)) {
			
			CReplyToCommand(client, "%t", "Successfully Ban Added", arg3);
			return;
			
		}
		
		if (StrEqual(arg1, "level", false)) {
			
			CReplyToCommand(client, "%t", "Successfully Level Added", arg3);
			return;
			
		}
		
	}
	
	if (StrEqual(arg2, "remove")) {
		
		if (db == null || results == null) {
			
			LogError("[PS] Error while removing %s from the %s whitelist! %s", arg3, arg1, error);
			PrintToServer("[PS] Error while removing %s from the %s whitelist! %s", arg3, arg1, error);
			CReplyToCommand(client, "[PS] Error while removing %s from the %s whitelist! %s", arg3, arg1, error);
			return;
			
		}
		
		if (!results.AffectedRows) {
			
			if (StrEqual(arg1, "hours", false)) {
				
				CReplyToCommand(client, "%t", "Nothing Hour Removed", arg3);
				return;
				
			}
			
			if (StrEqual(arg1, "bans", false)) {
				
				CReplyToCommand(client, "%t", "Nothing Ban Removed", arg3);
				return;
				
			}
			
			if (StrEqual(arg1, "level", false)) {
				
				CReplyToCommand(client, "%t", "Nothing Level Removed", arg3);
				return;
				
			}
			
		}
		
		if (StrEqual(arg1, "hours", false)) {
			
			CReplyToCommand(client, "%t", "Successfully Hour Removed", arg3);
			return;
			
		}
		
		if (StrEqual(arg1, "bans", false)) {
			
			CReplyToCommand(client, "%t", "Successfully Ban Removed", arg3);
			return;
			
		}
		
		if (StrEqual(arg1, "level", false)) {
			
			CReplyToCommand(client, "%t", "Successfully Level Removed", arg3);
			return;
			
		}
		
	}
	
	if (StrEqual(arg2, "check")) {
		
		if (db == null || results == null) {
			
			LogError("[PS] Error while issuing check command on %s! %s", arg3, error);
			PrintToServer("[PS] Error while issuing check command on %s! %s", arg3, error);
			CReplyToCommand(client, "[PS] Error while issuing check command on %s! %s", arg3, error);
			return;
			
		}
		
		if (!results.RowCount) {
			
			if (StrEqual(arg1, "hours", false)) {
				
				CReplyToCommand(client, "%t", "Hour Check Not Whitelisted", arg3);
				return;
				
			}
			
			if (StrEqual(arg1, "bans", false)) {
				
				CReplyToCommand(client, "%t", "Ban Check Not Whitelisted", arg3);
				return;
				
			}
			
			if (StrEqual(arg1, "level", false)) {
				
				CReplyToCommand(client, "%t", "Level Check Not Whitelisted", arg3);
				return;
				
			}
			
		}
		
		if (StrEqual(arg1, "hours", false)) {
			
			CReplyToCommand(client, "%t", "Hour Check Whitelisted", arg3);
			return;
			
		}
		
		if (StrEqual(arg1, "bans", false)) {
			
			CReplyToCommand(client, "%t", "Ban Check Whitelisted", arg3);
			return;
			
		}
		
		if (StrEqual(arg1, "level", false)) {
			
			CReplyToCommand(client, "%t", "Level Check Whitelisted", arg3);
			return;
			
		}
		
	}
	
}

/* On Client Authorized */

public void OnClientAuthorized(int client) {
	
	if (IsFakeClient(client))
		return;
	
	char auth[40];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	if (g_cvEnableHourCheck.BoolValue) {
		
		if (g_cvHoursWhitelistEnable.BoolValue) {
			
			QueryHoursWhitelist(client, auth);
			
		}
		
		else {
			
			RequestHours(client, auth);
			
		}
		
	}
	
	if (g_cvEnableBanDetection.BoolValue) {
		
		if (g_cvBansWhitelist.BoolValue) {
			
			QueryBansWhitelist(client, auth);
			
		} 
		
		else {
			
			RequestBans(client, auth);
			
		}
	}
	
	if (g_cvEnableLevelCheck.BoolValue) {
		
		if (g_cvLevelWhitelistEnable.BoolValue) {
			
			QueryLevelWhitelist(client, auth);
			
		} 
		
		else {
			
			RequestLevel(client, auth);
			
		}
		
	}
	
	if (g_cvEnablePrivateProfileCheck.BoolValue) {
		
		CheckPrivateProfile(client, auth);
		
	}
	
}