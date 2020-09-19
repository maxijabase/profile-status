/* Command */

public Action Command_Generic(int client, int args) {
	
	char arg1[30], arg2[30], arg3[30];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	
	if (StrEqual(arg1, "whitelist", false))
		OpenWhitelistMenu(client);
	
	if (!StrEqual(arg1, "hours", false) && !StrEqual(arg1, "bans", false) && !StrEqual(arg1, "level", false)) {
		CReplyToCommand(client, "%t", "Command Generic Usage");
		return Plugin_Handled;
	}
	
	if ((!StrEqual(arg2, "add", false) && !StrEqual(arg2, "remove", false) && !StrEqual(arg2, "check", false)) || StrEqual(arg3, "")) {
		CReplyToCommand(client, "%t", "Command Generic Usage");
		return Plugin_Handled;
	}
	
	if (!SimpleRegexMatch(arg3, "^7656119[0-9]{10}$")) {
		CReplyToCommand(client, "%t", "Invalid STEAMID");
		return Plugin_Handled;
	}
	
	Command(arg1, arg2, arg3, client);
	return Plugin_Handled;
}

public void Command(char[] arg1, char[] arg2, char[] arg3, int client) {
	
	char query[256], table[32];
	
	if (StrEqual(arg1, "hours", false))
		Format(table, sizeof(table), "ps_whitelist");
	if (StrEqual(arg1, "bans", false))
		Format(table, sizeof(table), "ps_whitelist_bans");
	if (StrEqual(arg1, "level", false))
		Format(table, sizeof(table), "ps_whitelist_level");
	
	if (StrEqual(arg2, "add"))
		Format(query, sizeof(query), "INSERT INTO %s (steamid) VALUES (%s);", table, arg3);
	if (StrEqual(arg2, "remove"))
		Format(query, sizeof(query), "DELETE FROM %s WHERE steamid='%s';", table, arg3);
	if (StrEqual(arg2, "check"))
		Format(query, sizeof(query), "SELECT * FROM %s WHERE steamid='%s';", table, arg3);
	
	DataPack pack = new DataPack();
	
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(arg1);
	pack.WriteString(arg2);
	pack.WriteString(arg3);
	
	g_Database.Query(SQL_Command, query, pack);
	
}

public void SQL_Command(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	char arg1[30], arg2[30], arg3[30];
	pack.ReadString(arg1, sizeof(arg1));
	pack.ReadString(arg2, sizeof(arg2));
	pack.ReadString(arg3, sizeof(arg3));
	delete pack;
	
	if (!client) {
		return;
	}
	
	if (StrEqual(arg2, "add")) {
		
		if (db == null) {
			
			LogError("[PS] Error while adding %s to the %s whitelist! %s", arg3, arg1, error);
			PrintToServer("[PS] Error while adding %s to the %s whitelist! %s", arg3, arg1, error);
			CPrintToChat(client, "[PS] Error while adding %s to the %s whitelist! %s", arg3, arg1, error);
			return;
		}
		
		if (results == null) {
			if (StrEqual(arg1, "hours", false)) {
				CPrintToChat(client, "%t", "Nothing Hour Added", arg3);
				return;
			}
			if (StrEqual(arg1, "bans", false)) {
				CPrintToChat(client, "%t", "Nothing Ban Added", arg3);
				return;
			}
			if (StrEqual(arg1, "level", false)) {
				CPrintToChat(client, "%t", "Nothing Level Added", arg3);
				
			}
		}
		if (StrEqual(arg1, "hours", false)) {
			CPrintToChat(client, "%t", "Successfully Hour Added", arg3);
			return;
		}
		if (StrEqual(arg1, "bans", false)) {
			CPrintToChat(client, "%t", "Successfully Ban Added", arg3);
			return;
		}
		if (StrEqual(arg1, "level", false)) {
			CPrintToChat(client, "%t", "Successfully Level Added", arg3);
			return;
		}
	}
	
	if (StrEqual(arg2, "remove")) {
		
		if (db == null || results == null)
		{
			LogError("[PS] Error while removing %s from the %s whitelist! %s", arg3, arg1, error);
			PrintToServer("[PS] Error while removing %s from the %s whitelist! %s", arg3, arg1, error);
			CPrintToChat(client, "[PS] Error while removing %s from the %s whitelist! %s", arg3, arg1, error);
			return;
		}
		
		if (!results.AffectedRows) {
			if (StrEqual(arg1, "hours", false)) {
				CPrintToChat(client, "%t", "Nothing Hour Removed", arg3);
				return;
			}
			if (StrEqual(arg1, "bans", false)) {
				CPrintToChat(client, "%t", "Nothing Ban Removed", arg3);
				return;
			}
			if (StrEqual(arg1, "level", false)) {
				CPrintToChat(client, "%t", "Nothing Level Removed", arg3);
				return;
			}
		}
		
		if (StrEqual(arg1, "hours", false)) {
			CPrintToChat(client, "%t", "Successfully Hour Removed", arg3);
			return;
		}
		if (StrEqual(arg1, "bans", false)) {
			CPrintToChat(client, "%t", "Successfully Ban Removed", arg3);
			return;
		}
		if (StrEqual(arg1, "level", false)) {
			CPrintToChat(client, "%t", "Successfully Level Removed", arg3);
			
		}
	}
	
	if (StrEqual(arg2, "check")) {
		
		if (db == null || results == null)
		{
			LogError("[PS] Error while issuing check command on %s! %s", arg3, error);
			PrintToServer("[PS] Error while issuing check command on %s! %s", arg3, error);
			CPrintToChat(client, "[PS] Error while issuing check command on %s! %s", arg3, error);
			return;
		}
		
		if (!results.RowCount) {
			if (StrEqual(arg1, "hours", false)) {
				CPrintToChat(client, "%t", "Hour Check Not Whitelisted", arg3);
				return;
			}
			if (StrEqual(arg1, "bans", false)) {
				CPrintToChat(client, "%t", "Ban Check Not Whitelisted", arg3);
				return;
			}
			if (StrEqual(arg1, "level", false)) {
				CPrintToChat(client, "%t", "Level Check Not Whitelisted", arg3);
				return;
			}
		}
		if (StrEqual(arg1, "hours", false)) {
			CPrintToChat(client, "%t", "Hour Check Whitelisted", arg3);
			return;
		}
		if (StrEqual(arg1, "bans", false)) {
			CPrintToChat(client, "%t", "Ban Check Whitelisted", arg3);
			return;
		}
		if (StrEqual(arg1, "level", false)) {
			CPrintToChat(client, "%t", "Level Check Whitelisted", arg3);
			return;
		}
	}
}