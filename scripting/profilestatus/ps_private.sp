/* Private Profile Check Module */

public void CheckPrivateProfile(int client, char[] auth) {
	
	Handle request = CreateRequest_RequestPrivate(client, auth);
	SteamWorks_SendHTTPRequest(request);
	
}

Handle CreateRequest_RequestPrivate(int client, char[] auth) {
	
	char apikey[40];
	GetConVarString(g_cvApiKey, apikey, sizeof(apikey));
	
	char request_url[512];
	
	Format(request_url, sizeof(request_url), "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s", apikey, auth);
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, request_url);
	
	SteamWorks_SetHTTPRequestContextValue(request, GetClientUserId(client));
	SteamWorks_SetHTTPCallbacks(request, RequestPrivate_OnHTTPResponse);
	return request;
}

public int RequestPrivate_OnHTTPResponse(Handle request, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int userid) {
	
	if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
		PrintToServer("[PS] HTTP Steam Private Profile Request failure!");
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
	char[] responseBodyPrivate = new char[bufferSize];
	SteamWorks_GetHTTPResponseBodyData(request, responseBodyPrivate, bufferSize);
	delete request;
	
	PrintToServer("%i", GetCommVisibState(responseBodyPrivate));

	if (GetCommVisibState(responseBodyPrivate) == 1)
		KickClient(client, "%t", "No Private Profile");
}