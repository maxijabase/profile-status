#include <sourcemod>
#include <steamworks>
#include <morecolors>
#include <stocksoup/version>
#include <profilestatus>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.2"
#define CHOICE1 "hoursTable"
#define CHOICE2 "bansTable"

public Plugin myinfo =  {
	
	name = "[ANY] Profile Status", 
	author = "ratawar", 
	description = "Limits server entrance to players based on game playtime or VAC/Steam Bans status.", 
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

static Regex
	r_ApiKey, 
	r_SteamID;

Database
	g_Database;

/* Variables */

static char
	cAPIKey[64], 
	cvDatabase[16], 
	EcBan[10];

int iMinHours, 
	iVACDays, 
	iVACAmount, 
	iGameBans, 
	iEconomyBan;
	
static int 
	c = 2;

//}

/* On Plugin Start */

public void OnPluginStart() {
	
	/* Plugin Version */
	CreateConVar("sm_profilestatus_version", PLUGIN_VERSION, "Plugin version.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	/* Basic Data */
	g_cvEnable 				 = CreateConVar("sm_profilestatus_enable", "1", "Enable the plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvApiKey  			 = CreateConVar("sm_profilestatus_apikey", "", "Your Steam API key (https://steamcommunity.com/dev/apikey).", FCVAR_PROTECTED);
	
	/* Database Name */
	g_cvDatabase 			 = CreateConVar("sm_profilestatus_database", "storage-local", 
											"Hour Check module's database name. Change this value only if you're using another database. (Only SQLite supported.)");
	
	/* Hour Check Module */
	g_cvEnableHourCheck 	 = CreateConVar("sm_profilestatus_hours_enable", "1", "Enable Hour Checking functions?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvMinHours 			 = CreateConVar("sm_profilestatus_hours_minhours", "", "Minimum of hours requiered to enter the server.");
	g_cvHoursWhitelistEnable = CreateConVar("sm_profilestatus_hours_whitelist_enable", "1", "Enable Hours Check Whitelist?");
	g_cvHoursWhitelistAuto   = CreateConVar("sm_profilestatus_hours_whitelist_auto", "1", "Whitelist members that have been checked automatically?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	/* Ban Check Module */
	g_cvEnableBanDetection   = CreateConVar("sm_profilestatus_bans_enable", "1", "Enable Ban Checking functions?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvBansWhitelist 		 = CreateConVar("sm_profilestatus_bans_whitelist", "1", "Enable Bans Whitelist?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvVACDays 			 = CreateConVar("sm_profilestatus_vac_days", "0", "Minimum days since the last VAC ban to be allowed into the server (0 for zero tolerance).");
	g_cvVACAmount 			 = CreateConVar("sm_profilestatus_vac_amount", "0", "Amount of VAC bans tolerated until prohibition (0 for zero tolerance).");
	g_cvCommunityBan 		 = CreateConVar("sm_profilestatus_community_ban", "0", "0- Don't kick if there's a community ban | 1- Kick if there's a community ban");
	g_cvGameBans 			 = CreateConVar("sm_profilestatus_game_bans", "5", "Amount of game bans tolerated until prohibition (0 for zero tolerance).");
	g_cvEconomyBan 			 = CreateConVar("sm_profilestatus_economy_bans", "0", 
											"0- Don't check for economy bans | 1- Kick if user is economy \"banned\" only. | 2- Kick if user is in either \"banned\" or \"probation\" state.", 
											_, true, 1.0, true, 2.0);
	
	/* RegEx */
	r_ApiKey = CompileRegex("^[0-9A-Z]*$");
	r_SteamID = CompileRegex("^7656119[0-9]{10}$");
	
	RegAdminCmd("sm_ps", Command_Generic, ADMFLAG_GENERIC, "Generic Hour Check command.");
	
	LoadTranslations("profilestatus.phrases");
	
	AutoExecConfig(true, "ProfileStatus");
	
}

/* Global CVAR Assigns and Checks */

public void OnConfigsExecuted() {
	
	g_cvApiKey.GetString(cAPIKey, sizeof(cAPIKey));
	g_cvDatabase.GetString(cvDatabase, sizeof(cvDatabase));
	
	iMinHours   = g_cvMinHours.IntValue;
	iVACDays    = g_cvVACDays.IntValue;
	iVACAmount  = g_cvVACAmount.IntValue;
	iGameBans   = g_cvGameBans.IntValue;
	iEconomyBan = g_cvEconomyBan.IntValue;
	
	if (!g_cvEnable.BoolValue)
		SetFailState("[PS] Plugin disabled!");
	
	if (!IsAPIKeyCorrect(cAPIKey, r_ApiKey))
		SetFailState("[PS] Please set your Steam API Key properly!");
	
	if (g_cvEnableHourCheck.BoolValue || g_cvBansWhitelist.BoolValue)
		Database.Connect(SQL_ConnectDatabase, cvDatabase);
	else
		PrintToServer("[PS] Hours Check module and Bans Whitelist disabled! Aborting database connection.");
	
	if (!g_cvEnableBanDetection.BoolValue)
		PrintToServer("[PS] Ban Detection module disabled!");
	
}

/* Database connection and tables creation */

public void SQL_ConnectDatabase(Database db, const char[] error, any data) {
	
	if (db == null)
	{
		LogError("[PS] Could not connect to database %s! Error: %s", cvDatabase, error);
		PrintToServer("[PS] Could not connect to database %s! Error: %s", cvDatabase, error);
		return;
	}
	
	PrintToServer("[PS] Database connection to \"%s\" successful!", cvDatabase);
	g_Database = db;
	CreateTable();
}

public void CreateTable() {
	
	char sQuery1[256];
	char sQuery2[256];
	StrCat(sQuery1, sizeof(sQuery1), "CREATE TABLE IF NOT EXISTS ps_whitelist(");
	StrCat(sQuery1, sizeof(sQuery1), "entry INTEGER PRIMARY KEY, ");
	StrCat(sQuery1, sizeof(sQuery1), "steamid VARCHAR(17), ");
	StrCat(sQuery1, sizeof(sQuery1), "unique (steamid));"); 
	StrCat(sQuery2, sizeof(sQuery2), "CREATE TABLE IF NOT EXISTS ps_whitelist_bans(");
	StrCat(sQuery2, sizeof(sQuery2), "entry INTEGER PRIMARY KEY, ");
	StrCat(sQuery2, sizeof(sQuery2), "steamid VARCHAR(17), ");
	StrCat(sQuery2, sizeof(sQuery2), "unique (steamid));");
	g_Database.Query(SQL_CreateTable, sQuery1);
	g_Database.Query(SQL_CreateTable, sQuery2);
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data) {
	
	if (db == null || results == null)
	{
		LogError("[PS] Create Table Query failure! %s", error);
		PrintToServer("[PS] Create Table Query failure! %s", error);
		return;
	}
	
	c -= 1;
	if (!c) PrintToServer("[PS] Tables successfully created or were already created!");
}

/* Hour Check Module */

public void QueryDBForClient(int client, char[] auth) {
	
	char WhitelistReadQuery[512];
	Format(WhitelistReadQuery, sizeof(WhitelistReadQuery), "SELECT * FROM ps_whitelist WHERE steamid='%s';", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(client);
	
	g_Database.Query(SQL_QueryDBForClient, WhitelistReadQuery, pack);
}

public void SQL_QueryDBForClient(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = pack.ReadCell();
	delete pack;
	
	if (db == null || results == null) {
		LogError("[PS] Error while checking if user %s is hour whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is hour whitelisted! %s", auth, error);
		return;
	}

	if (!results.RowCount) {
		
		PrintToServer("[PS] User %s is not hour whitelisted! Checking hours...", auth);
		RequestHours(client, auth);
		return;
	}
	
	PrintToServer("[PS] User %s is hour whitelisted! Skipping hour check.", auth);
}

void RequestHours(int client, char[] auth) {
	
	Handle request = CreateRequest_RequestHours(client, auth);
	SteamWorks_SendHTTPRequest(request);
	
}

Handle CreateRequest_RequestHours(int client, char[] auth) {
	
	char request_url[512];
	
	Format(request_url, sizeof(request_url), "http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=%s&include_played_free_games=1&appids_filter[0]=%i&steamid=%s&format=json", cAPIKey, GetAppID(), auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	SteamWorks_SetHTTPRequestContextValue(request, client);
	SteamWorks_SetHTTPCallbacks(request, RequestHours_OnHTTPResponse);
	return request;
}

public int RequestHours_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int client) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		PrintToServer("[PS] HTTP Hours Request failure!");
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
	
	if (totalPlayedTime < iMinHours) {
		KickClient(client, "%t", "Not Enough Hours", totalPlayedTime, iMinHours);
		return;
	}
	
	char auth[40];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	if (!g_cvHoursWhitelistAuto.BoolValue) {
		PrintToServer("[PS] Player passed hour check, but will not be whitelisted!");
		return;
	}
	
	AddPlayerToWhitelist(auth);
}

public void AddPlayerToWhitelist(char[] auth) {
	
	char WhitelistWriteQuery[512];
	Format(WhitelistWriteQuery, sizeof(WhitelistWriteQuery), "INSERT INTO ps_whitelist (steamid) VALUES (%s);", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	
	g_Database.Query(SQL_AddPlayerToWhitelist, WhitelistWriteQuery, pack);
}

public void SQL_AddPlayerToWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	delete pack;
	
	if (db == null || results == null)
	{
		LogError("[PS] Error while trying to hour whitelist user %s! %s", auth, error);
		PrintToServer("[PS] Error while trying to hour whitelist user %s! %s", auth, error);
		return;
	}
	
	PrintToServer("[PS] Player %s successfully hour whitelisted!", auth);
}

/* Ban Check Module */

void QueryBansWhitelist(int client, char[] auth) {
	
	char BansWhitelistQuery[256];
	Format(BansWhitelistQuery, sizeof(BansWhitelistQuery), "SELECT * FROM ps_whitelist_bans WHERE steamid='%s'", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(client);
	
	g_Database.Query(SQL_QueryBansWhitelist, BansWhitelistQuery, pack);
	
}

public void SQL_QueryBansWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = pack.ReadCell();
	delete pack;
	
	if (db == null || results == null) {
		LogError("[PS] Error while checking if user %s is ban whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is ban whitelisted! %s", auth, error);
		return;
	}
	
	if (!results.RowCount) {
		
		PrintToServer("[PS] User %s is not ban whitelisted! Checking ban status...", auth);
		RequestBans(client, auth);
		return;
	}
	
	PrintToServer("[PS] User %s is ban whitelisted! Skipping ban check.", auth);
}

void RequestBans(int client, char[] auth) {
	
	Handle request = CreateRequest_RequestBans(client, auth);
	SteamWorks_SendHTTPRequest(request);
	
}

Handle CreateRequest_RequestBans(int client, char[] auth) {
	
	char apikey[40];
	GetConVarString(g_cvApiKey, apikey, sizeof(apikey));
	
	char request_url[512];
	
	Format(request_url, sizeof(request_url), "http://api.steampowered.com/ISteamUser/GetPlayerBans/v1?key=%s&steamids=%s", apikey, auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	SteamWorks_SetHTTPRequestContextValue(request, client);
	SteamWorks_SetHTTPCallbacks(request, RequestBans_OnHTTPResponse);
	return request;
}

public int RequestBans_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int client) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		PrintToServer("[PS] HTTP Bans Request failure!");
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
			else if (GetDaysSinceLastVAC(responseBodyBans) < iVACDays)
				KickClient(client, "%t", "VAC Kicked Days", iVACDays);
			else if (GetVACAmount(responseBodyBans) > iVACAmount)
				KickClient(client, "%t", "VAC Kicked Amount", iVACAmount);
		}
		
		if (IsCommunityBanned(responseBodyBans))
			if (g_cvCommunityBan.BoolValue)
			KickClient(client, "%t", "Community Ban Kicked");
		
		if (GetGameBans(responseBodyBans) > iGameBans)
			KickClient(client, "%t", "Game Bans Exceeded", iGameBans);
		
		GetEconomyBans(responseBodyBans, EcBan);
		
		if (iEconomyBan == 1)
			if (StrContains(EcBan, "banned", false) != -1)
			KickClient(client, "%t", "Economy Ban Kicked");
		if (iEconomyBan == 2)
			if (StrContains(EcBan, "banned", false) != -1 || StrContains(EcBan, "probation", false) != -1)
			KickClient(client, "%t", "Economy Ban/Prob Kicked");
		
	}
	
}

/* Whitelist Menu */

public void OpenWhitelistMenu(int client) {
	
	Menu menu = new Menu(mPickWhitelist, MENU_ACTIONS_ALL);
	menu.AddItem(CHOICE1, "Hours Whitelist");
	menu.AddItem(CHOICE2, "Bans Whitelist");
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int mPickWhitelist(Menu menu, MenuAction action, int param1, int param2) {
	
	switch(action) {
		
		case MenuAction_Display: {
			
			char buffer[255];
			Format(buffer, sizeof(buffer), "Select a table");
			
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

public void MenuQuery(int param1, char[] info) {
	
	int client = param1;
	char table[32];
	StrEqual(info, "hoursTable", false) ? Format(table, sizeof(table), "ps_whitelist") : Format(table, sizeof(table), "ps_whitelist_bans");
	
	char query[256];
	g_Database.Format(query, sizeof(query), "SELECT * FROM %s", table);
	
	DataPack pack = new DataPack();
	pack.WriteString(table);
	pack.WriteCell(client);
	
	g_Database.Query(SQL_MenuQuery, query, pack);
}

public void SQL_MenuQuery(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char table[32];
	pack.ReadString(table, sizeof(table));
	int client = pack.ReadCell();
	delete pack;
	
	
	if (db == null || results == null) {
			
			LogError("[PS] Error while querying %s for menu display! %s", table, error);
			PrintToServer("[PS] Error while querying %s for menu display! %s", table, error);
			CPrintToChat(client, "[PS] Error while querying %s for menu display! %s", table, error);
			return;
		}
	
	char type[16];
	StrEqual(table, "ps_whitelist", false) ? Format(type, sizeof(type), "Hours") : Format(type, sizeof(type), "Bans");
	
	int entryCol, steamidCol;
	
	results.FieldNameToNum("entry", entryCol);
	results.FieldNameToNum("steamid", steamidCol);
	
	Menu menu = new Menu(TablesMenu, MENU_ACTIONS_ALL);
	menu.SetTitle("Showing %s Whitelist", type);
	
	char steamid[32], id[16]; 
	int count;
	
	while (results.FetchRow()) {
		
		count++;
		results.FetchString(steamidCol, steamid, sizeof(steamid));
		IntToString(count, id, sizeof(id));
		menu.AddItem(id, steamid, ITEMDRAW_DISABLED);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int TablesMenu(Menu menu, MenuAction action, int param1, int param2) {
	
	switch(action) {
		
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
	
	if (StrEqual(arg1, "whitelist", false))
		OpenWhitelistMenu(client);
	
	if (!StrEqual(arg1, "hours", false) && !StrEqual(arg1, "bans", false)) {
		CReplyToCommand(client, "%t", "Command Generic Usage");
		return Plugin_Handled;
	}
	
	if ((!StrEqual(arg2, "add", false) && !StrEqual(arg2, "remove", false) && !StrEqual(arg2, "check", false)) || StrEqual(arg3, "")) {
		CReplyToCommand(client, "%t", "Command Generic Usage");
		return Plugin_Handled;
	}
	
	if (MatchRegex(r_SteamID, arg3) == 0) {
		CReplyToCommand(client, "%t", "Invalid STEAMID");
		return Plugin_Handled;
	}
	
	Command(arg1, arg2, arg3, client);
	return Plugin_Handled;
}

public void Command(char[] arg1, char[] arg2, char[] arg3, int client) {
	
	char query[256], table[32];
	
	StrEqual(arg1, "hours", false) ? Format(table, sizeof(table), "ps_whitelist") : Format(table, sizeof(table), "ps_whitelist_bans");
	
	if (StrEqual(arg2, "add"))
		Format(query, sizeof(query), "INSERT INTO %s (steamid) VALUES (%s);", table, arg3);
	if (StrEqual(arg2, "remove"))
		Format(query, sizeof(query), "DELETE FROM %s WHERE steamid='%s';", table, arg3);
	if (StrEqual(arg2, "check"))
		Format(query, sizeof(query), "SELECT * FROM %s WHERE steamid='%s';", table, arg3);
	
	DataPack pack = new DataPack();
	
	pack.WriteCell(client);
	pack.WriteString(arg1);
	pack.WriteString(arg2);
	pack.WriteString(arg3);
	
	g_Database.Query(SQL_Command, query, pack);
	
}

public void SQL_Command(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	int client = pack.ReadCell();
	char arg1[30], arg2[30], arg3[30];
	pack.ReadString(arg1, sizeof(arg1));
	pack.ReadString(arg2, sizeof(arg2));
	pack.ReadString(arg3, sizeof(arg3));
	delete pack;
	
	char module[16];
	StrEqual(arg1, "hours", false) ? Format(module, sizeof(module), "Hours") : Format(module, sizeof(module), "Bans");
	
	if (StrEqual(arg2, "add")) {
		
		if (db == null) {
			
			LogError("[PS] Error while adding %s to the %s whitelist! %s", arg3, module, error);
			PrintToServer("[PS] Error while adding %s to the %s whitelist! %s", arg3, module, error);
			CPrintToChat(client, "[PS] Error while adding %s to the %s whitelist! %s", arg3, module, error);
			return;
		}
		
		if (results == null) {
			if (StrEqual(module, "Hours", false)) {
				CPrintToChat(client, "%t", "Nothing Hour Added", arg3);
				return;
			}
			CPrintToChat(client, "%t", "Nothing Ban Added", arg3);
			return;
		}
		if (StrEqual(module, "Hours", false)) {
			CPrintToChat(client, "%t", "Successfully Hour Added", arg3);
			return;
		}
		
		CPrintToChat(client, "%t", "Successfully Ban Added", arg3);
		
	}
	
	if (StrEqual(arg2, "remove")) {
		
		if (db == null || results == null)
		{
			LogError("[PS] Error while issuing remove command on %s! %s", arg3, error);
			PrintToServer("[PS] Error while issuing remove command on %s! %s", arg3, error);
			CPrintToChat(client, "[PS] Error while issuing remove command on %s! %s", arg3, error);
			return;
		}
		
		if (!results.AffectedRows) {
			if (StrEqual(module, "Hours", false)) {
				
				CPrintToChat(client, "%t", "Nothing Hour Removed", arg3);
				return;
			}
			CPrintToChat(client, "%t", "Nothing Ban Removed", arg3);
		}
		if (StrEqual(module, "Hours", false)) {
			CPrintToChat(client, "%t", "Successfully Hour Removed", arg3);
			return;
		}
		CPrintToChat(client, "%t", "Successfully Ban Removed", arg3);
		
	}
	
	if (StrEqual(arg2, "check")) {
		
		if (db == null || results == null)
		{
			LogError("[PS] Error while issuing check command on %s! %s", arg3, error);
			PrintToServer("[PS] Error while issuing check command on %s! %s", arg3, error);
			CPrintToChat(client, "[PS] Error while issuing check command on %s! %s", arg3, error);
			return;
		}
		
		if (!results.RowCount) {
			if (StrEqual(module, "Hours", false)) {
				
				CPrintToChat(client, "%t", "Hour Check Not Whitelisted", arg3);
				return;
			}
			CPrintToChat(client, "%t", "Ban Check Not Whitelisted", arg3);
			
		}
		if (StrEqual(module, "Hours", false)) {
			
			CPrintToChat(client, "%t", "Hour Check Whitelisted", arg3);
			return;
		}
		CPrintToChat(client, "%t", "Ban Check Whitelisted", arg3);
	}
} 

/* On Client Authorized */

public void OnClientAuthorized(int client) {
	
	char auth[40];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	if (g_cvEnableHourCheck.BoolValue)
		if (g_cvHoursWhitelistEnable) {
			PrintToServer("[PS] Checking hours database for %s existance.", auth);
			QueryDBForClient(client, auth);
			return;
		} else
			RequestHours(client, auth);
	
	if (g_cvEnableBanDetection.BoolValue)
		if (g_cvBansWhitelist.BoolValue) {
			PrintToServer("[PS] Checking bans database for %s existance.", auth);
			QueryBansWhitelist(client, auth);
			return;
		} else
			RequestBans(client, auth);
	
} 