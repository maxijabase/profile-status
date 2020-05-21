/*
**
*/
#if defined _INCLUDE_included
 #endinput
#endif
#define _INCLUDE_included

/**
 * Gets player's hours from the API response body.
 *
 * @param responseBody           API response body.
 */

stock int GetPlayerHours(const char[] responseBody) {
	
	char str[8][64];
	
	ExplodeString(responseBody, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 8; i++) {
		
		if (StrContains(str[i], "playtime_forever") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/**
 * Gets players' days since their last VAC Ban from the API response body.
 *
 * @param responseBody          API response body.
 */

stock int GetDaysSinceLastVAC(const char[] responseBodyBans) {
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "DaysSinceLastBan") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/**
 * Gets players' VAC Ban amount from the API response body.
 *
 * @param responseBody          API response body.
 */

stock int GetVACAmount(const char[] responseBodyBans) {
	
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "NumberOfVACBans") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/**
 * Gets players' amount of Game Bans from the API response body.
 *
 * @param responseBody          API response body.
 */

stock int GetGameBans(char[] responseBodyBans) {
	
	char str[7][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "NumberOfGameBans") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return StringToInt((str2[1]));
			
		}
	}
	return -1;
}

/**
 * Returns true if player is VAC Banned, false otherwise.
 *
 * @param responseBody          API response body.
 */

stock bool IsVACBanned(const char[] responseBodyBans) {
	
	char str[10][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "VACBanned") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return (StrEqual(str2[1], "false")) ? false : true;
			
		}
	}
	return false;
}

/**
 * Returns true if player is Community Banned, false otherwise.
 *
 * @param responseBody          API response body.
 */

stock bool IsCommunityBanned(const char[] responseBodyBans) {
	
	char str[10][64];
	
	ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
	
	for (int i = 0; i < 7; i++) {
		
		if (StrContains(str[i], "CommunityBanned") != -1) {
			
			char str2[2][32];
			ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
			
			return (StrEqual(str2[1], "false")) ? false : true;
			
		}
	}
	return false;
}

/**
 * Returns players' Economy Ban status.
 *
 * @param responseBody          API response body.
 * @param EcBan          Variable to store the type of Economy Ban.
 */

stock void GetEconomyBans(const char[] responseBodyBans, char[] EcBan) { 
    char str[7][64];
    
    ExplodeString(responseBodyBans, ",", str, sizeof(str), sizeof(str[]));
    
    for (int i = 0; i < 7; i++) {
        
        if (StrContains(str[i], "EconomyBan") != -1) {
            
            char str2[2][32];
            ExplodeString(str[i], ":", str2, sizeof(str2), sizeof(str2[]));
            strcopy(EcBan, 15, str2[1]);
            
        }
    }
    
}

/**
 * Returns true if API Key matches regex, false otherwise.
 *
 * @param responseBody          API response body.
 */

stock bool IsAPIKeyCorrect(char[] cAPIKey, Regex r_ApiKey) {
	
	if (cAPIKey[0] == '\0')
		return false;
	else if (MatchRegex(r_ApiKey, cAPIKey) == 0)
		return false;
		
	return true;
}