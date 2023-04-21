#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>
#include <timeparser>
#include <playerinfo>

#undef REQUIRE_PLUGIN
#include <updater>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define UPDATE_URL "https://raw.githubusercontent.com/maxijabase/profile-status/master/updatefile.txt"

public Plugin myinfo = 
{
  name = "Profile Status - Account Age", 
  author = "ampere", 
  description = "Blocks accounts based on their age.", 
  version = PLUGIN_VERSION, 
  url = "Your website URL/AlliedModders profile URL"
};

ConVar cvMinimumAge;
ConVar cvAllowFetchFailure;
ConVar cvEnableDatabase;
ConVar cvDatabaseName;

char minimumAge[16];
char databaseName[32];
bool allowFetchFailure;
bool enableDatabase;
bool isSQLite;

Database DB;

ArrayList tempBlacklist;

public void OnPluginStart()
{
  AutoExecConfig_SetCreateFile(true);
  AutoExecConfig_SetFile("ps_accountage");
  
  AutoExecConfig_CreateConVar("sm_ps_ag_version", PLUGIN_VERSION, "Standard plugin version ConVar.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  
  cvMinimumAge = AutoExecConfig_CreateConVar("sm_ps_ag_minimum_age", "7d", 
    "Minimum account age relative to the time the check is performed. Format is [n][unit] (e.g. 3d, 1y, 10m, 48h, 10d20h, etc)");
  
  cvAllowFetchFailure = AutoExecConfig_CreateConVar("sm_ps_ag_allow_invisible_date", "1", 
    "Let the player in if their account creation date is hidden due to private profile. This will not kick players if the API returned an error.");
  
  cvEnableDatabase = AutoExecConfig_CreateConVar("sm_ps_ag_enable_database", "1", 
    "Enable database usage to prevent players from being checked every time.");
  
  cvDatabaseName = AutoExecConfig_CreateConVar("sm_ps_ag_database_name", "storage-local", 
    "Database connection name. Change this only if you're going to use a different database connection to store whitelisted players, otherwise it'll stay locally.");
  
  AutoExecConfig_ExecuteFile();
  AutoExecConfig_CleanFile();
  
  if (LibraryExists("updater"))
  {
    Updater_AddPlugin(UPDATE_URL);
  }
}

public void OnLibraryAdded(const char[] name)
{
  if (StrEqual(name, "updater"))
  {
    Updater_AddPlugin(UPDATE_URL);
  }
}

public void OnConfigsExecuted()
{
  cvMinimumAge.GetString(minimumAge, sizeof(minimumAge));
  cvDatabaseName.GetString(databaseName, sizeof(databaseName));
  allowFetchFailure = cvAllowFetchFailure.BoolValue;
  enableDatabase = cvEnableDatabase.BoolValue;
  
  if (ParseTime(minimumAge) == -1)
  {
    SetFailState("Minimum age cvar has been set incorrectly! Please check the format.");
  }
  
  if (enableDatabase)
  {
    Database.Connect(OnDatabaseConnected, databaseName);
  }
}

public void OnDatabaseConnected(Database db, const char[] error, any data)
{
  if (db == null)
  {
    SetFailState("Database connection failed! %s", error);
  }
  DB = db;
  CreateTables();
  
  char driver[2];
  DB.Driver.GetIdentifier(driver, sizeof(driver));
  isSQLite = driver[0] == 's';
}

public void OnMapStart()
{
  tempBlacklist = new ArrayList(ByteCountToCells(32));
}

public void OnClientPostAdminCheck(int client)
{
  char steamid[18];
  GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));
  
  if (tempBlacklist.FindString(steamid) != -1)
  {
    KickClient(client, "Your account's creation date does not meet this server's requirements");
    return;
  }
  
  if (enableDatabase && DB != null)
  {
    GetPlayerFromWhitelist(client);
  }
  else
  {
    PI_GetAccountCreationDate(client, OnCreationDateReceived, GetClientUserId(client));
  }
}

void GetPlayerFromWhitelist(int client)
{
  char steamid[18];
  GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));
  
  char query[256];
  DB.Format(query, sizeof(query), "SELECT steamid FROM ps_accountage_whitelist WHERE steamid = '%s'", steamid);
  DB.Query(OnPlayerReceived, query, GetClientUserId(client));
}

public void OnPlayerReceived(Database db, DBResultSet results, const char[] error, int userid)
{
  if (db == null || results == null)
  {
    LogError("Get player from whitelist failure! %s", error);
    return;
  }
  
  if (!results.FetchRow())
  {
    PI_GetAccountCreationDate(GetClientOfUserId(userid), OnCreationDateReceived, userid);
  }
}

public void OnCreationDateReceived(AccountCreationDateResponse response, const char[] error, int timestamp, int userid)
{
  int client = GetClientOfUserId(userid);
  char steamid[18];
  GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));
  
  switch (response)
  {
    case AccountCreationDate_UnknownError:
    {
      LogError("Error while fetching account creation date for %N", client);
      return;
    }
    case AccountCreationDate_InvisibleDate:
    {
      if (!allowFetchFailure)
      {
        KickClient(client, "Your account's creation date could not be verified by the server");
        LogMessage("Client %N's account creation date could not be seen, rejecting...");
      }
      else
      {
        LogMessage("Client %N's account's creation date could not be seen, allowing...");
      }
      return;
    }
    case AccountCreationDate_Success:
    {
      int current = GetTime();
      int cutoff = current - (ParseTime(minimumAge) - current);
      if (timestamp >= cutoff)
      {
        KickClient(client, "Your account's creation date does not meet this server's requirements");
        LogMessage("Client %N's account's creation date requirements were not met, rejecting...", client);
        tempBlacklist.PushString(steamid);
      }
      else
      {
        if (enableDatabase && DB != null)
        {
          SaveToWhitelist(steamid);
        }
        
        LogMessage("Client %N's account's creation date meets the requirements, allowing...", client);
      }
    }
  }
}

void SaveToWhitelist(const char[] steamid)
{
  char query[512];
  DB.Format(query, sizeof(query), "INSERT INTO ps_accountage_whitelist VALUES ('%s')", steamid);
  DB.Query(OnPlayerSaved, query);
}

public void OnPlayerSaved(Database db, DBResultSet results, const char[] error, any data) {
  
  if (db == null || results == null)
  {
    LogError("Save player to whitelist failure! %s", error);
    return;
  }
}

void CreateTables()
{
  char query[1024];
  
  if (isSQLite)
  {
    DB.Format(query, sizeof(query), 
      "CREATE TABLE IF NOT EXISTS ps_accountage_whitelist(steamid VARCHAR(17), unique (steamid));");
  }
  else
  {
    DB.Format(query, sizeof(query), 
      "CREATE TABLE IF NOT EXISTS ps_accountage_whitelist(steamid VARCHAR(17) PRIMARY KEY);");
  }
  
  DB.Query(OnTablesCreated, query);
}

public void OnTablesCreated(Database db, DBResultSet results, const char[] error, any data)
{
  if (db == null || results == null)
  {
    LogError("Create Table Query failure! %s", error);
    return;
  }
} 