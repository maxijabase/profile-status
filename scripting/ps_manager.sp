#include <sourcemod>
#include <sdktools>
#include <autoexecconfig>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

#define MOD_ACCOUNTAGE "profilestatus_accountage"
#define MOD_BANS "profilestatus_bans"
#define MOD_STEAMLEVEL "profilestatus_steamlevel"
#define MOD_PROFILEPRIVACY "profilestatus_profileprivacy"

ArrayList modules;
StringMap databases;

public Plugin myinfo = 
{
  name = "Profile Status - Manager", 
  author = "ampere", 
  description = "Manages the Profile Status modules installed", 
  version = PLUGIN_VERSION, 
  url = "github.com/maxijabase"
};

public void OnPluginStart()
{
  AutoExecConfig_CreateConVar("sm_ps_manager_version", PLUGIN_VERSION, "Standard plugin version ConVar.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  
  RegAdminCmd("sm_ps", CMD_Manager, ADMFLAG_GENERIC);
  RegAdminCmd("sm_profilestatus", CMD_Manager, ADMFLAG_GENERIC);
  
  LoadTranslations("profilestatus.manager.phrases");
  
  modules = new ArrayList(ByteCountToCells(32));
  databases = new StringMap();
  BuildModulesList();
}

void BuildModulesList()
{
  if (LibraryExists(MOD_ACCOUNTAGE))
  {
    modules.PushString(MOD_ACCOUNTAGE);
    char db[32];
    FindConVar("sm_ps_ag_database_name").GetString(db, sizeof(db));
    databases.SetString(MOD_ACCOUNTAGE, db);
  }
  if (LibraryExists(MOD_BANS))
  {
    modules.PushString(MOD_BANS);
    char db[32];
    FindConVar("sm_ps_bans_database_name").GetString(db, sizeof(db));
    databases.SetString(MOD_BANS, db);
  }
  if (LibraryExists(MOD_STEAMLEVEL))
  {
    modules.PushString(MOD_STEAMLEVEL);
    char db[32];
    FindConVar("sm_ps_level_database_name").GetString(db, sizeof(db));
    databases.SetString(MOD_STEAMLEVEL, db);
  }
  if (LibraryExists(MOD_PROFILEPRIVACY))
  {
    modules.PushString(MOD_PROFILEPRIVACY);
    char db[32];
    FindConVar("sm_ps_profileprivacy_database_name").GetString(db, sizeof(db));
    databases.SetString(MOD_PROFILEPRIVACY, db);
  }
}

public Action CMD_Manager(int client, int args)
{
  if (!client)
  {
    ReplyToCommand(client, "Can't perform this action from console!");
    return Plugin_Handled;
  }
  
  Menu menu = BuildMenu();
  menu.Display(client, 30);
  return Plugin_Handled;
}

Menu BuildMenu()
{
  Menu menu = new Menu(Handler_Main);
  menu.SetTitle("Profile Status");
  for (int i = 0; i < modules.Length; i++)
  {
    char name[32];
    modules.GetString(i, name, sizeof(name));
    Format(name, sizeof(name), "%t", name);
    menu.AddItem(name, name);
  }
  return menu;
}

public int Handler_Main(Menu menu, MenuAction action, int param1, int param2)
{
  switch (action)
  {
    case MenuAction_Select:
    {
      switch (param2)
      {
        
      }
    }
    case MenuAction_End:
    {
      delete menu;
    }
  }
  return 0;
}
