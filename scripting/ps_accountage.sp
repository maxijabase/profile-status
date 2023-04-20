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

char minimumAge[16];
bool allowFetchFailure;
bool enableDatabase;

public void OnPluginStart()
{
  AutoExecConfig_SetCreateFile(true);
  AutoExecConfig_SetFile("ps_accountage");
  
  AutoExecConfig_CreateConVar("sm_ps_ag_version", PLUGIN_VERSION, "Standard plugin version ConVar.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  
  cvMinimumAge = AutoExecConfig_CreateConVar("sm_ps_ag_minimum_age", "7d", 
    "Minimum account age relative to the time the check is performed. Format is [n][unit] (e.g. 3d, 1y, 10m, 48h, 10d20h, etc)");
  
  cvAllowFetchFailure = AutoExecConfig_CreateConVar("sm_ps_ag_allow_invisible_date", "1", 
    "Let the player in if their account creation date is hidden due to private profile. This will not kick players if the API returned an error.");
  
  cvEnableDatabase = AutoExecConfig_CreateConVar("sm_ps_ag_enable_database", "0", 
    "Enable database usage to prevent players from being checked every time.");
  
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

public void OnConfigsExecuted() {
  cvMinimumAge.GetString(minimumAge, sizeof(minimumAge));
  allowFetchFailure = cvAllowFetchFailure.BoolValue;
  enableDatabase = cvEnableDatabase.BoolValue;
  
  if (ParseTime(minimumAge) == -1) {
    SetFailState("Minimum age cvar has been set incorrectly! Please check the format.");
  }
  
  if (enableDatabase) {
    Database.Connect(OnDatabaseConnected, "accountagecontrol");
  }
}

public void OnDatabaseConnected(Database db, const char[] error, any data) {
  
}

public void OnMapStart()
{
  
}

public void OnClientPostAdminCheck(int client) {
  PI_GetAccountCreationDate(client, OnCreationDateReceived, GetClientUserId(client));
}

public void OnCreationDateReceived(AccountCreationDateResponse response, const char[] error, int timestamp, int userid) {
  int client = GetClientOfUserId(userid);
  
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
      if (timestamp >= cutoff) {
        KickClient(client, "Your account's creation date does not meet this server's requirements");
        LogMessage("Client %N's account's creation date requirements were not met, rejecting...", client);
      }
    }
  }
}