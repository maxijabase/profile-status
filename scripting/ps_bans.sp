#include <sourcemod>
#include <sdktools>
#include <playerinfo>
#include <autoexecconfig>

#undef REQUIRE_PLUGIN
#include <updater>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define UPDATE_URL "https://raw.githubusercontent.com/maxijabase/profile-status/master/updatefile.txt"

public Plugin myinfo = 
{
  name = "Profile Status - Bans", 
  author = "ampere", 
  description = "Restricts players based on their bans status", 
  version = PLUGIN_VERSION, 
  url = "github.com/maxijabase"
};

ConVar cvEnableWhitelist;
ConVar cvDatabaseName;
ConVar cvVacMinDays;
ConVar cvVacMaxAmount;
ConVar cvCommunityBanAllowed;
ConVar cvGameBanMaxAmount;
ConVar cvEconomyBanState;

bool enableWhitelist;
char databaseName[32];
bool isSQLite;

int vacMinDays;
int vacMaxAmount;
bool communityBanAllowed;
int gameBanMaxAmount;
int economyBanState;

Database DB;

ArrayList tempBlacklist;

enum
{
  EconomyBan_Allow, 
  EconomyBan_AllowProbation, 
  EconomyBan_DisallowAll
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  RegPluginLibrary("profilestatus_bans");
  return APLRes_Success;
}

public void OnPluginStart()
{
  AutoExecConfig_SetCreateFile(true);
  AutoExecConfig_SetFile("ps_bans");
  
  AutoExecConfig_CreateConVar("sm_ps_bans_version", PLUGIN_VERSION, "Standard plugin version ConVar.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  
  cvEnableWhitelist = AutoExecConfig_CreateConVar("sm_ps_bans_whitelist", "1", 
    "Enable whitelist to make the plugin bypass checks on selected players.", _, true, 0.0, true, 1.0);
  
  cvDatabaseName = AutoExecConfig_CreateConVar("sm_ps_bans_database_name", "storage-local", 
    "Database connection name. Change this only if you're going to use a different database connection to store whitelisted players, otherwise it'll stay locally.");
  
  cvVacMinDays = AutoExecConfig_CreateConVar("sm_ps_bans_vac_min_days", "0", 
    "Minimum days since the last VAC ban to be allowed into the server (0 for zero tolerance).");
  
  cvVacMaxAmount = AutoExecConfig_CreateConVar("sm_ps_bans_vac_max_amount", "0", 
    "Amount of VAC bans tolerated until prohibition (0 for zero tolerance).");
  
  cvCommunityBanAllowed = AutoExecConfig_CreateConVar("sm_ps_bans_communityban_allow", "0", 
    "Allow players with a community ban.", _, true, 0.0, true, 1.0);
  
  cvGameBanMaxAmount = AutoExecConfig_CreateConVar("sm_ps_bans_gamebans_max", "5", 
    "Amount of game bans tolerated until prohibition (0 for zero tolerance).");
  
  cvEconomyBanState = AutoExecConfig_CreateConVar("sm_ps_bans_economy", "0", 
    "0: Allow all economy ban states | 1- Kick if user is economy \"banned\" only. | 2- Kick if user is in either \"banned\" or \"probation\" state.", _, true, 0.0, true, 2.0);
  
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
  enableWhitelist = cvEnableWhitelist.BoolValue;
  cvDatabaseName.GetString(databaseName, sizeof(databaseName));
  vacMinDays = cvVacMinDays.IntValue;
  vacMaxAmount = cvVacMaxAmount.IntValue;
  communityBanAllowed = cvCommunityBanAllowed.BoolValue;
  gameBanMaxAmount = cvGameBanMaxAmount.IntValue;
  economyBanState = cvEconomyBanState.IntValue;
  
  if (enableWhitelist)
  {
    Database.Connect(OnDatabaseConnected, databaseName);
  }
}

public void OnMapStart()
{
  tempBlacklist = new ArrayList(ByteCountToCells(32));
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

void CreateTables()
{
  char query[1024];
  
  if (isSQLite)
  {
    DB.Format(query, sizeof(query), 
      "CREATE TABLE IF NOT EXISTS ps_bans_whitelist(steamid VARCHAR(17), alias VARCHAR(32), unique (steamid));");
  }
  else
  {
    DB.Format(query, sizeof(query), 
      "CREATE TABLE IF NOT EXISTS ps_bans_whitelist(steamid VARCHAR(17) PRIMARY KEY, alias VARCHAR(32));");
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

public void OnClientPostAdminCheck(int client)
{
  char steamid[18];
  GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));
  
  if (tempBlacklist.FindString(steamid) != -1)
  {
    KickClient(client, "Your account's ban state does not meet this server's requirements");
    return;
  }
  
  if (enableWhitelist)
  {
    GetPlayerFromWhitelist(client);
  }
  else
  {
    PI_GetPlayerBans(client, OnBansReceived, GetClientUserId(client));
  }
}

public void OnBansReceived(PlayerBansResponse response, const char[] error, PlayerBans bans, int userid) {
  int client = GetClientOfUserId(userid);
  char steamid[18];
  GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));
  
  bool block;
  
  switch (response)
  {
    case PlayerBans_UnknownError:
    {
      LogError("Error while fetching ban information for %N", client);
      return;
    }
    case PlayerBans_Success:
    {
      if (vacMinDays > bans.DaysSinceLastBan)
      {
        block = true;
        KickClient(client, "Your account does not meet this server's minimum days since last VAC ban criteria");
      }
      
      if (vacMaxAmount < bans.NumberOfVACBans)
      {
        block = true;
        KickClient(client, "Your account does not meet this server's VAC Ban amount criteria");
      }
      
      if (!communityBanAllowed && bans.CommunityBanned)
      {
        block = true;
        KickClient(client, "Your account does not meet this server's Community Ban criteria");
      }
      
      if (gameBanMaxAmount < bans.NumberOfGameBans)
      {
        block = true;
        KickClient(client, "Your account does not meet this server's Game Ban amount criteria");
      }
      
      bool shouldKickForEconomyBan;
      
      switch (economyBanState)
      {
        case EconomyBan_AllowProbation:
        {
          if (bans.EconomyBan == EconomyBan_Banned)
          {
            shouldKickForEconomyBan = true;
          }
        }
        case EconomyBan_DisallowAll:
        {
          if (bans.EconomyBan != EconomyBan_None)
          {
            shouldKickForEconomyBan = true;
          }
        }
      }
      
      if (shouldKickForEconomyBan)
      {
        KickClient(client, "Your account does not meet this server's Economy Ban criteria");
      }
      
      if (block || shouldKickForEconomyBan)
      {
        tempBlacklist.PushString(steamid);
      }
    }
  }
}

void GetPlayerFromWhitelist(int client)
{
  char steamid[18];
  GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid));
  
  char query[256];
  DB.Format(query, sizeof(query), "SELECT steamid FROM ps_bans_whitelist WHERE steamid = '%s'", steamid);
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
    PI_GetPlayerBans(GetClientOfUserId(userid), OnBansReceived, userid);
  }
}
