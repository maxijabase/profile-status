/* Hour Check Module */

public void QueryHoursWhitelist(int client, char[] auth) {
	
	char WhitelistReadQuery[512];
	Format(WhitelistReadQuery, sizeof(WhitelistReadQuery), "SELECT * FROM ps_whitelist WHERE steamid='%s';", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(GetClientUserId(client));
	
	g_Database.Query(SQL_QueryHoursWhitelist, WhitelistReadQuery, pack);
}

public void SQL_QueryHoursWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	
	if (!client) {
		return;
	}
	
	if (db == null || results == null) {
		LogError("[PS] Error while checking if user %s is hour whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is hour whitelisted! %s", auth, error);
		return;
	}
	
	if (!results.RowCount) {
		
		RequestHours(client, auth);
		return;
	}
}

void RequestHours(int client, char[] auth) {
	
	Handle request = CreateRequest_RequestHours(client, auth);
	SteamWorks_SendHTTPRequest(request);
	
}

Handle CreateRequest_RequestHours(int client, char[] auth) {
	
	char request_url[512];
	
	Format(request_url, sizeof(request_url), "http://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=%s&include_played_free_games=1&appids_filter[0]=%i&steamid=%s&format=json", cAPIKey, GetAppID(), auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestHours_OnHTTPResponse);
	return request;
}

public int RequestHours_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		PrintToServer("[PS] HTTP Hours Request failure!");
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
	
	char[] responseBody = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBody, bufferSize);
	delete request;
	
	int playedTime = GetPlayerHours(responseBody);
	int totalPlayedTime = playedTime / 60;
	
	if (!totalPlayedTime) {
		KickClient(client, "%t", "Invisible Hours");
		return;
	}
	
	if (minHours != 0) {
		if (totalPlayedTime < minHours) {
			KickClient(client, "%t", "Not Enough Hours", totalPlayedTime, minHours);
			return;
		}
	}
	
	if (g_cvHoursWhitelistAuto.BoolValue) {
		char auth[40];
		GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
		AddPlayerToHoursWhitelist(auth);
	}
}

public void AddPlayerToHoursWhitelist(char[] auth) {
	
	char WhitelistWriteQuery[512];
	Format(WhitelistWriteQuery, sizeof(WhitelistWriteQuery), "INSERT INTO ps_whitelist (steamid) VALUES (%s);", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	
	g_Database.Query(SQL_AddPlayerToHoursWhitelist, WhitelistWriteQuery, pack);
}

public void SQL_AddPlayerToHoursWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
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