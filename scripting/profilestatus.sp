#include <sourcemod>
#include <regex>
#include "include/steamworks"
#include "multicolors"
#include "include/stocksoup/version"
#include "include/profilestatus"
#include "include/autoexecconfig"

#include "profilestatus/ps_global.sp"
#include "profilestatus/ps_hours.sp"
#include "profilestatus/ps_bans.sp"
#include "profilestatus/ps_level.sp"
#include "profilestatus/ps_private.sp"
#include "profilestatus/ps_database.sp"
#include "profilestatus/ps_menu.sp"
#include "profilestatus/ps_command.sp"

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.3.5"

public Plugin myinfo = {
	
	name = "[ANY] Profile Status", 
	author = "ratawar", 
	description = "Limits server entrance to players.", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?p=2697650"
};

/* Plugin Start */

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

/* On Client Authorized */

public void OnClientAuthorized(int client) {
	
	if (IsFakeClient(client))
		return;
	
	char auth[40];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	if (g_cvEnableHourCheck.BoolValue) {
		if (g_cvHoursWhitelistEnable.BoolValue) {
			QueryHoursWhitelist(client, auth);
		} else
			RequestHours(client, auth);
	}
	
	if (g_cvEnableBanDetection.BoolValue) {
		if (g_cvBansWhitelist.BoolValue) {
			QueryBansWhitelist(client, auth);
		} else
			RequestBans(client, auth);
	}
	
	if (g_cvEnableLevelCheck.BoolValue) {
		if (g_cvLevelWhitelistEnable.BoolValue) {
			QueryLevelWhitelist(client, auth);
		} else
			RequestLevel(client, auth);
	}
	
	if (g_cvEnablePrivateProfileCheck.BoolValue) {
		CheckPrivateProfile(client, auth);
	}
} 
