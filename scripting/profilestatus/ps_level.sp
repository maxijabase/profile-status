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
	
	if (!client) {
		return;
	}
	
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
	
	Handle request = CreateRequest_RequestLevel(client, auth);
	SteamWorks_SendHTTPRequest(request);
	
}

Handle CreateRequest_RequestLevel(int client, char[] auth) {
	
	char apikey[40];
	GetConVarString(g_cvApiKey, apikey, sizeof(apikey));
	
	char request_url[512];
	
	Format(request_url, sizeof(request_url), "http://api.steampowered.com/IPlayerService/GetSteamLevel/v1/?key=%s&steamid=%s", apikey, auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestLevel_OnHTTPResponse);
	return request;
}

public int RequestLevel_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) {
	
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
	
	if (db == null || results == null)
	{
		LogError("[PS] Error while trying to level whitelist user %s! %s", auth, error);
		PrintToServer("[PS] Error while trying to level whitelist user %s! %s", auth, error);
		return;
	}
	
	PrintToServer("[PS] Player %s successfully level whitelisted!", auth);
}