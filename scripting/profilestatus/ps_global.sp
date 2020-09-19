/* Handles */

ConVar
	g_cvEnable, 
	g_cvApiKey;
	
ConVar 
	g_cvDatabase, 
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

char
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
	
int cc = 3;