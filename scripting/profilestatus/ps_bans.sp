/* Ban Check Module */

public void QueryBansWhitelist(int client, char[] auth) {
	
	char BansWhitelistQuery[256];
	Format(BansWhitelistQuery, sizeof(BansWhitelistQuery), "SELECT * FROM ps_whitelist_bans WHERE steamid='%s'", auth);
	
	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(GetClientUserId(client));
	
	g_Database.Query(SQL_QueryBansWhitelist, BansWhitelistQuery, pack);
	
}

public void SQL_QueryBansWhitelist(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char auth[40];
	pack.ReadString(auth, sizeof(auth));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	
	if (!client) {
		return;
	}
	
	if (db == null || results == null) {
		LogError("[PS] Error while checking if user %s is ban whitelisted! %s", auth, error);
		PrintToServer("[PS] Error while checking if user %s is ban whitelisted! %s", auth, error);
		return;
	}
	
	if (!results.RowCount) {
		
		RequestBans(client, auth);
		return;
	}
	
	PrintToServer("[PS] User %s is ban whitelisted! Skipping ban check.", auth);
}

void RequestBans(int client, char[] auth) {
	
	Handle request = CreateRequest_RequestBans(client, auth);
	SteamWorks_SendHTTPRequest(request);
	
}

Handle CreateRequest_RequestBans(int client, char[] auth) {
	
	char apikey[40];
	g_cvApiKey.GetString(apikey, sizeof(apikey));
	
	char request_url[512];
	
	Format(request_url, sizeof(request_url), "http://api.steampowered.com/ISteamUser/GetPlayerBans/v1?key=%s&steamids=%s", apikey, auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestBans_OnHTTPResponse);
	return request;
}

public int RequestBans_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		PrintToServer("[PS] HTTP Bans Request failure!");
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
	char[] responseBodyBans = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBodyBans, bufferSize);
	delete request;
	
	if (g_cvEnableBanDetection.BoolValue) {
		
		if (IsVACBanned(responseBodyBans)) {
			
			if (!GetDaysSinceLastVAC(responseBodyBans) || !GetVACAmount(responseBodyBans))
				KickClient(client, "%t", "VAC Kicked");
			else if (GetDaysSinceLastVAC(responseBodyBans) < vacDays)
				KickClient(client, "%t", "VAC Kicked Days", vacDays);
			else if (GetVACAmount(responseBodyBans) > vacAmount)
				KickClient(client, "%t", "VAC Kicked Amount", vacAmount);
		}
		
		if (IsCommunityBanned(responseBodyBans))
			if (g_cvCommunityBan.BoolValue)
			KickClient(client, "%t", "Community Ban Kicked");
		
		if (GetGameBans(responseBodyBans) > gameBans)
			KickClient(client, "%t", "Game Bans Exceeded", gameBans);
		
		GetEconomyBans(responseBodyBans, EcBan);
		
		if (economyBan == 1)
			if (StrContains(EcBan, "banned", false) != -1)
			KickClient(client, "%t", "Economy Ban Kicked");
		if (economyBan == 2)
			if (StrContains(EcBan, "banned", false) != -1 || StrContains(EcBan, "probation", false) != -1)
			KickClient(client, "%t", "Economy Ban/Prob Kicked");
		
	}
	
}