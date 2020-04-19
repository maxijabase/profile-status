#include <sourcemod>
#include <steamworks>
#include <morecolors>
#include <stocksoup/version>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "[ANY] Profile Status", 
	author = "ratawar", 
	description = "Limits server entrance to players with certain amount of hours in that game.", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/member.php?u=282996"
};

/* Global Handles */

ConVar g_cvEnabled, g_cvApiKey, g_cvMinHours, g_cvWhitelist;
Regex r_Numbers, r_ApiKey, r_SteamID;
Database g_Database = null;

public void OnPluginStart()
{
	Database.Connect(SQL_ConnectDatabase, "storage-local");
	
	CreateConVar("sm_profilestatus_version", PLUGIN_VERSION, "Plugin version.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_cvEnabled = CreateConVar("sm_profilestatus_enabled", "1", "Enable the plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvApiKey = CreateConVar("sm_profilestatus_apikey", "", "Your Steam API key (https://steamcommunity.com/dev/apikey).", FCVAR_PROTECTED);
	g_cvMinHours = CreateConVar("sm_profilestatus_minhours", "", "Minimum of hours requiered to enter the server.");
	g_cvWhitelist = CreateConVar("sm_profilestatus_whitelist", "1", "Whitelist members that have been checked automatically?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	r_Numbers = CompileRegex("^[0-9]*$");
	r_ApiKey = CompileRegex("^[0-9A-Z]*$");
	r_SteamID = CompileRegex("^7656119[0-9]{10}$");
	
	RegAdminCmd("sm_ps_add", Command_AddWhitelist, ADMFLAG_GENERIC, "Add a STEAMID manually to the whitelist.");
	RegAdminCmd("sm_ps_remove", Command_RemoveWhitelist, ADMFLAG_GENERIC, "Remove a STEAMID from the whitelist.");
	RegAdminCmd("sm_ps_check", Command_CheckWhitelist, ADMFLAG_GENERIC, "Manually check if a STEAMID is whitelisted.");
	
	LoadTranslations("profilestatus.phrases");
	
	AutoExecConfig(true, "ProfileStatus");
}

public void OnMapStart() {
	
	if (!g_cvEnabled.BoolValue)
		SetFailState("[PS] Plugin disabled!");
		
	if (!IsAPIKeyCorrect())
		SetFailState("[PS] Please set your Steam API Key properly!");
		
	if (!AreCvarsNumeric())
		SetFailState("[PS] Please configure all cvars properly!");
	
}

public void SQL_ConnectDatabase(Database db, const char[] error, any data)
{
	
	if (db == null)
	{
		LogError("[PS] Database connection error! %s", error);
		PrintToServer("[PS] Database connection error! %s", error);
		return;
	}
	PrintToServer("[PS] Database connection successful!", error);
	g_Database = db;
	CreateTable();
}

public void CreateTable()
{
	char sQuery[1024] = "";
	StrCat(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS ps_whitelist(");
	StrCat(sQuery, sizeof(sQuery), "entry INTEGER PRIMARY KEY, ");
	StrCat(sQuery, sizeof(sQuery), "steamid VARCHAR(17), ");
	StrCat(sQuery, sizeof(sQuery), "unique (steamid));");
	g_Database.Query(SQL_CreateTable, sQuery);
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null || results == null)
	{
		LogError("[PS] Create Table Query failure! %s", error);
		PrintToServer("[PS] Create Table Query failure! %s", error);
		return;
	}
	PrintToServer("[PS] Tables successfully created or were already created!");
}

public void OnClientAuthorized(int client) {
	
	char auth[40];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	QueryDBForClient(client, auth);
}

public void QueryDBForClient(int client, char[] auth) {
	
	char WhitelistReadQuery[512];
	Format(WhitelistReadQuery, sizeof(WhitelistReadQuery), "SELECT * FROM ps_whitelist WHERE steamid='%s';", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(client);
	
	g_Database.Query(SQL_ReadWhitelistQuery, WhitelistReadQuery, pack);
}

public void SQL_ReadWhitelistQuery(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = pack.ReadCell();
	delete pack;
	
	if (db == null || results == null)
	{
		LogError("[PS] Error while checking if user %s is whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is whitelisted! %s", auth, error);
		return;
	}
	
	char logResponse[128];
	Format(logResponse, sizeof(logResponse), "[PS] User %s is not whitelisted!", auth);
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
	
	Handle request = CreateRequest_CheckHours(client, auth);
	SteamWorks_SendHTTPRequest(request);
	
}

Handle CreateRequest_CheckHours(int client, char[] auth)
{
	char apikey[40];
	GetConVarString(g_cvApiKey, apikey, sizeof(apikey));
	
	char request_url[512];
	
	Format(request_url, sizeof(request_url), "http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=%s&include_played_free_games=1&appids_filter[0]=%i&steamid=%s&format=json", apikey, GetAppID(), auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	SteamWorks_SetHTTPRequestContextValue(request, client);
	SteamWorks_SetHTTPCallbacks(request, CheckHours_OnHTTPResponse);
	return request;
}

public int CheckHours_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int client)
{
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		PrintToServer("[PS] HTTP Hours Request failure!");
		delete request;
		return;
	}
	
	int MinHours = g_cvMinHours.IntValue;
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
	
	if (totalPlayedTime < MinHours) {
		KickClient(client, "%t", "Not Enough Hours", totalPlayedTime, MinHours);
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
	
	g_Database.Query(SQL_WriteWhitelistQuery, WhitelistWriteQuery, pack);
	
}

public void SQL_WriteWhitelistQuery(Database db, DBResultSet results, const char[] error, DataPack pack)
{
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

public Action Command_CheckWhitelist(int client, int args) {
	
	char arg1[40];
	
	if (!GetCmdArg(1, arg1, sizeof(arg1))) {
		CReplyToCommand(client, "%t", "Command Check Usage");
		return Plugin_Handled;
	}
	
	if (!MatchRegex(r_SteamID, arg1)){
		CReplyToCommand(client, "%t", "Invalid STEAMID");
		return Plugin_Handled;
	}
		
	DataPack pack = new DataPack();
	
	pack.WriteCell(client);
	pack.WriteString(arg1);
	
	char CheckQuery[512];
	
	g_Database.Format(CheckQuery, sizeof(CheckQuery), "SELECT * FROM ps_whitelist WHERE steamid='%s';", arg1);
	g_Database.Query(SQL_CheckQuery, CheckQuery, pack);
	return Plugin_Handled;
}

public void SQL_CheckQuery(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	int client = pack.ReadCell();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	delete pack;
	
	if (db == null || results == null)
	{
		LogError("[PS] Error while issuing check command on %s! %s", auth, error);
		PrintToServer("[PS] Error while issuing check command on %s! %s", auth, error);
		CPrintToChat(client, "[PS] Error while issuing check command on %s! %s", auth, error);
		return;
	}
	
	if (!results.RowCount) {
		CPrintToChat(client, "%t", "Check Not Whitelisted", auth);
		return;
	}
	
	CPrintToChat(client, "%t", "Check Whitelisted", auth);
}

public Action Command_RemoveWhitelist(int client, int args) {
	
	char arg1[40];
	
	if (!GetCmdArg(1, arg1, sizeof(arg1))) {
		CReplyToCommand(client, "%t", "Command Remove Usage");
		return Plugin_Handled;
	}
	
	if (!MatchRegex(r_SteamID, arg1)){
		CReplyToCommand(client, "%t", "Invalid STEAMID");
		return Plugin_Handled;
	}
		
	DataPack pack = new DataPack();
	
	pack.WriteCell(client);
	pack.WriteString(arg1);
	
	char RemoveQuery[512];
	
	g_Database.Format(RemoveQuery, sizeof(RemoveQuery), "DELETE FROM ps_whitelist WHERE steamid='%s';", arg1);
	g_Database.Query(SQL_RemoveQuery, RemoveQuery, pack);
	return Plugin_Handled;
}

public void SQL_RemoveQuery(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	int client = pack.ReadCell();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	delete pack;
	
	if (db == null || results == null)
	{
		LogError("[PS] Error while issuing remove command on %s! %s", auth, error);
		PrintToServer("[PS] Error while issuing remove command on %s! %s", auth, error);
		CPrintToChat(client, "[PS] Error while issuing remove command on %s! %s", auth, error);
		return;
	}
	
	if (!results.AffectedRows){
		CPrintToChat(client, "%t", "Nothing Removed", auth);
		return;
	}
		
	CPrintToChat(client, "%t", "Successfully Removed", auth);
}

public Action Command_AddWhitelist(int client, int args) {
	
	char arg1[40];
	
	if (!GetCmdArg(1, arg1, sizeof(arg1))) {
		CReplyToCommand(client, "%t", "Command Add Usage");
		return Plugin_Handled;
	}
	
	if (!MatchRegex(r_SteamID, arg1)){
		CReplyToCommand(client, "%t", "Invalid STEAMID");
		return Plugin_Handled;
	}
		
	DataPack pack = new DataPack();
	
	pack.WriteCell(client);
	pack.WriteString(arg1);
	
	char AddQuery[512];
	
	g_Database.Format(AddQuery, sizeof(AddQuery), "INSERT INTO ps_whitelist (steamid) VALUES (%s);", arg1);
	g_Database.Query(SQL_Add_Query, AddQuery, pack);
	return Plugin_Handled;
}

public void SQL_Add_Query(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	int client = pack.ReadCell();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	delete pack;
	
	if (db == null)
	{
		LogError("[PS] Error while issuing add command on %s! %s", auth, error);
		PrintToServer("[PS] Error while issuing add command on %s! %s", auth, error);
		CPrintToChat(client, "[PS] Error while issuing add command on %s! %s", auth, error);
		return;
	}
	
	if (results == null) {
		CPrintToChat(client, "%t", "Nothing Added", auth);
		return;
	}
		
	CPrintToChat(client, "%t", "Successfully Added", auth);
}

/*  Credits to alphaearth for the following GetPlayerHours() snippet.
 *	https://forums.alliedmods.net/showthread.php?p=2680553 
 */

int GetPlayerHours(char[] responseBody) {
	char str2[2][64];
	ExplodeString(responseBody, "\"playtime_forever\":", str2, sizeof(str2), sizeof(str2[]));
	if (!StrEqual(str2[1], "")) {
		char lastString[2][64];
		ExplodeString(str2[1], "}", lastString, sizeof(lastString), sizeof(lastString[]));
		return StringToInt(lastString[0]);
	}
	return -1;
}

bool IsAPIKeyCorrect() {
	
	char apikey[40];
	GetConVarString(g_cvApiKey, apikey, sizeof(apikey));
	if (MatchRegex(r_ApiKey, apikey) == -1)
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