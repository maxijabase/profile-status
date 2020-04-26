#include <sourcemod>
#include <steamworks>
#include <morecolors>
#include <stocksoup/version>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.0"

public Plugin myinfo =  {
	
	name = "[ANY] Profile Status", 
	author = "ratawar", 
	description = "Limits server entrance to players based on game playtime or VAC/Steam Bans status.", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/member.php?u=282996"
};

/* Global Handles */

ConVar
	g_cvEnabled, 
	g_cvApiKey;
ConVar
	g_cvDatabase;
ConVar
	g_cvEnableHourCheck, 
	g_cvMinHours, 
	g_cvWhitelist;
ConVar
	g_cvEnableBanDetection, 
	g_cvVACDays, 
	g_cvVACAmount,
	g_cvCommunityBan, 
	g_cvGameBans, 
	g_cvEconomyBan;

Regex
	r_Numbers, 
	r_ApiKey, 
	r_SteamID;

Database
g_Database;

/* Global Variables */

char 
	cAPIKey[64], 
	cvDatabase[16],
	EcBan[10];
	
int iMinHours, 
	iVACDays,
	iVACAmount,
	iGameBans,
	iEconomyBan;

/* On Plugin Start */

public void OnPluginStart() {
	
	/* Plugin Version */
	CreateConVar("sm_profilestatus_version", PLUGIN_VERSION, "Plugin version.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	/* Basic Data */
	g_cvEnabled 			= CreateConVar("sm_profilestatus_enable", "1", "Enable the plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvApiKey 				= CreateConVar("sm_profilestatus_apikey", "", "Your Steam API key (https://steamcommunity.com/dev/apikey).", FCVAR_PROTECTED);
	
	/* Database Name */
	g_cvDatabase 			= CreateConVar("sm_profilestatus_database", "storage-local", "Hour Check module's database name. Change this value only if you're using another database. (Only SQLite supported.)");
	
	/* Hour Check Module */
	g_cvEnableHourCheck		= CreateConVar("sm_profilestatus_hourcheck_enable", "1", "Enable Hour Checking functions?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvMinHours 			= CreateConVar("sm_profilestatus_minhours", "", "Minimum of hours requiered to enter the server.");
	g_cvWhitelist 			= CreateConVar("sm_profilestatus_whitelist", "1", "Whitelist members that have been checked automatically?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	/* Ban Check Module */
	g_cvEnableBanDetection 	= CreateConVar("sm_profilestatus_bans_enable", "1", "Enable Ban Checking functions?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvVACDays 			= CreateConVar("sm_profilestatus_vac_days", "0", "Minimum days since the last VAC ban to be allowed into the server (0 for zero tolerance).");
	g_cvVACAmount 			= CreateConVar("sm_profilestatus_vac_amount", "0", "Amount of VAC bans tolerated until prohibition (0 for zero tolerance).");
	g_cvCommunityBan 		= CreateConVar("sm_profilestatus_community_ban", "0", "0- Don't kick if there's a community ban | 1- Kick if there's a community ban");
	g_cvGameBans 			= CreateConVar("sm_profilestatus_game_bans", "5", "Amount of game bans tolerated until prohibition (0 for zero tolerance).");
	g_cvEconomyBan 			= CreateConVar("sm_profilestatus_economy_bans", "0", 
							"0- Don't check for economy bans | 1- Kick if user is economy \"banned\" only. | 2- Kick if user is in either \"banned\" or \"probation\" state.", 
							_, true, 1.0, true, 2.0);
	
	/* RegEx */
	r_Numbers 				= CompileRegex("^[0-9]*$");
	r_ApiKey 				= CompileRegex("^[0-9A-Z]*$");
	r_SteamID 				= CompileRegex("^7656119[0-9]{10}$");
	
	/* Global CVAR Assigns */

	g_cvApiKey.GetString(cAPIKey, sizeof(cAPIKey));

	g_cvDatabase.GetString(cvDatabase, sizeof(cvDatabase));

	iMinHours   = g_cvMinHours.IntValue;
	iVACDays    = g_cvVACDays.IntValue;
	iVACAmount  = g_cvVACAmount.IntValue;
	iGameBans   = g_cvGameBans.IntValue;
	iEconomyBan = g_cvEconomyBan.IntValue;
	
	RegAdminCmd("sm_ps", Command_Generic, ADMFLAG_GENERIC, "Generic Hour Check command.");
	
	LoadTranslations("profilestatus.phrases");
	
	AutoExecConfig(true, "ProfileStatus");

}

/* On Map Start */

public void OnMapStart() {
	
	if (!AreCvarsNumeric())
		SetFailState("[PS] Please configure all cvars properly!");
	
	if (!g_cvEnabled.BoolValue)
		SetFailState("[PS] Plugin disabled!");
	
	if (!IsAPIKeyCorrect())
		SetFailState("[PS] Please set your Steam API Key properly!");
	
	if (g_cvEnableHourCheck.BoolValue)
		Database.Connect(SQL_ConnectDatabase, "storage-local");
	else
		PrintToServer("[PS] Hours Check module disabled! Aborting database connection.");
	
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
	
	char sQuery[1024] = "";
	StrCat(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS ps_whitelist(");
	StrCat(sQuery, sizeof(sQuery), "entry INTEGER PRIMARY KEY, ");
	StrCat(sQuery, sizeof(sQuery), "steamid VARCHAR(17), ");
	StrCat(sQuery, sizeof(sQuery), "unique (steamid));");
	g_Database.Query(SQL_CreateTable, sQuery);
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data) {
	
	if (db == null || results == null)
	{
		LogError("[PS] Create Table Query failure! %s", error);
		PrintToServer("[PS] Create Table Query failure! %s", error);
		return;
	}
	
	PrintToServer("[PS] Tables successfully created or were already created!");
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
		LogError("[PS] Error while checking if user %s is whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is whitelisted! %s", auth, error);
		return;
	}
	
	char logResponse[128];
	Format(logResponse, sizeof(logResponse), "[PS] User %s is not whitelisted! Checking hours...", auth);
	
	if (!g_cvWhitelist.BoolValue)
		Format(logResponse, sizeof(logResponse), "[PS] Whitelist disabled!");
	
	if (!results.RowCount) {
		PrintToServer("%s", logResponse);
		RequestHours(client, auth);
		return;
	}
	
	PrintToServer("[PS] User %s is whitelisted!", auth);
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
	
	PrintToServer("hours %i", GetPlayerHours(responseBody) / 60);
	
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
	
	if (g_cvWhitelist.BoolValue)
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
		LogError("[PS] Error while trying to whitelist user %s! %s", auth, error);
		PrintToServer("[PS] Error while trying to whitelist user %s! %s", auth, error);
		return;
	}
	
	PrintToServer("[PS] Player %s successfully whitelisted!", auth);
}

public Action Command_Generic(int client, int args) {
	
	char arg1[30], arg2[30];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	if (!StrEqual(arg1, "add", false) && !StrEqual(arg1, "remove", false) && !StrEqual(arg1, "check", false) || StrEqual(arg2, "")) {
		CReplyToCommand(client, "%t", "Command Generic Usage");
		return Plugin_Handled;
	}
	
	if (!MatchRegex(r_SteamID, arg2)) {
		CReplyToCommand(client, "%t", "Invalid STEAMID");
		return Plugin_Handled;
	}
	
	Command(arg1, arg2, client);
	return Plugin_Handled;
}

public void Command(char[] arg1, char[] arg2, int client) {
	
	char query[256];
	
	if (StrEqual(arg1, "add"))
		Format(query, sizeof(query), "INSERT INTO ps_whitelist (steamid) VALUES (%s);", arg2);
	if (StrEqual(arg1, "remove"))
		Format(query, sizeof(query), "DELETE FROM ps_whitelist WHERE steamid='%s';", arg2);
	if (StrEqual(arg1, "check"))
		Format(query, sizeof(query), "SELECT * FROM ps_whitelist WHERE steamid='%s';", arg2);
	
	DataPack pack = new DataPack();
	
	pack.WriteCell(client);
	pack.WriteString(arg1);
	pack.WriteString(arg2);
	
	g_Database.Query(SQL_Command, query, pack);
	
}

public void SQL_Command(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	int client = pack.ReadCell();
	char arg1[30], arg2[30];
	pack.ReadString(arg1, sizeof(arg1));
	pack.ReadString(arg2, sizeof(arg2));
	delete pack;
	
	if (StrEqual(arg1, "add")) {
		
		if (db == null) {
			
			LogError("[PS] Error while issuing add command on %s! %s", arg2, error);
			PrintToServer("[PS] Error while issuing add command on %s! %s", arg2, error);
			CPrintToChat(client, "[PS] Error while issuing add command on %s! %s", arg2, error);
			return;
		}
		
		if (results == null) {
			CPrintToChat(client, "%t", "Nothing Added", arg2);
			return;
		}
		
		CPrintToChat(client, "%t", "Successfully Added", arg2);
		return;
	}
	
	if (StrEqual(arg1, "remove")) {
		
		if (db == null || results == null)
		{
			LogError("[PS] Error while issuing remove command on %s! %s", arg2, error);
			PrintToServer("[PS] Error while issuing remove command on %s! %s", arg2, error);
			CPrintToChat(client, "[PS] Error while issuing remove command on %s! %s", arg2, error);
			return;
		}
		
		if (!results.AffectedRows) {
			CPrintToChat(client, "%t", "Nothing Removed", arg2);
			return;
		}
		
		CPrintToChat(client, "%t", "Successfully Removed", arg2);
		return;
	}
	
	if (StrEqual(arg1, "check")) {
		
		if (db == null || results == null)
		{
			LogError("[PS] Error while issuing check command on %s! %s", arg2, error);
			PrintToServer("[PS] Error while issuing check command on %s! %s", arg2, error);
			CPrintToChat(client, "[PS] Error while issuing check command on %s! %s", arg2, error);
			return;
		}
		
		if (!results.RowCount) {
			CPrintToChat(client, "%t", "Check Not Whitelisted", arg2);
			return;
		}
		
		CPrintToChat(client, "%t", "Check Whitelisted", arg2);
		return;
	}
	
}

int GetPlayerHours(char[] responseBody) {
	
	char str[8][64];
	
	ExplodeString(responseBody, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 8; i++) {
		
		if (StrContains(str[i], "playtime_forever") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/* Ban Check Module */

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
				
		GetEconomyBans(responseBodyBans);
		
		if (iEconomyBan == 1)
			if (StrContains(EcBan, "banned", false) != -1)
				KickClient(client, "%t", "Economy Ban Kicked");
		if (iEconomyBan == 2)
			if (StrContains(EcBan, "banned", false) != -1 || StrContains(EcBan, "probation", false) != -1)
				KickClient(client, "%t", "Economy Ban/Prob Kicked");
				
			}

}

int GetDaysSinceLastVAC(char[] responseBodyBans) {
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "DaysSinceLastBan") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

int GetVACAmount(char[] responseBodyBans) {
	
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "NumberOfVACBans") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

int GetGameBans(char[] responseBodyBans) {
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "NumberOfGameBans") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

bool IsVACBanned(char[] responseBodyBans) {
	
	char str[10][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "VACBanned") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return (StrEqual(str2[1], "false")) ? false : true;
			
		}
	}
	return false;
} 

bool IsCommunityBanned(char[] responseBodyBans) {
	
	char str[10][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "CommunityBanned") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return (StrEqual(str2[1], "false")) ? false : true;
			
		}
	}
	return false;
}

void GetEconomyBans(char[] responseBodyBans) { 
    char str[7][64];
    
    ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
    
    for (int i = 0; i < 7; i++) {
        
        if (StrContains(str[i], "EconomyBan") != -1) {
            
            char str2[2][32];
            ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
            strcopy(EcBan, 15, str2[1]);
            
        }
    }
    
}

/* On Client Authorized */

public void OnClientAuthorized(int client) {
	
	char auth[40];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	if (g_cvEnableHourCheck.BoolValue)
		QueryDBForClient(client, auth);
	
	if (g_cvEnableBanDetection.BoolValue)
		RequestBans(client, auth);
	
}

/* Extra Checks */

bool IsAPIKeyCorrect() {
	
	if (StrEqual(cAPIKey, "", false && MatchRegex(r_ApiKey, cAPIKey) == -1 ))
		return false;
		
	return true;
}

bool AreCvarsNumeric() {
	char minhours[10], enable[2], whitelist[2];
	IntToString(g_cvMinHours.IntValue, minhours, sizeof(minhours));
	IntToString(g_cvEnabled.IntValue, enable, sizeof(enable));
	IntToString(g_cvWhitelist.IntValue, whitelist, sizeof(whitelist));
	if (!MatchRegex(r_Numbers, minhours) || !MatchRegex(r_Numbers, enable) || !MatchRegex(r_Numbers, whitelist)) {
		return false;
	}
	return true;
}