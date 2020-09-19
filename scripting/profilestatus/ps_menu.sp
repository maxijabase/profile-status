/* Whitelist Menu */

#define CHOICE1 "hoursTable"
#define CHOICE2 "bansTable"
#define CHOICE3 "levelTable"

public void OpenWhitelistMenu(int client) {
	
	Menu menu = new Menu(mPickWhitelist, MENU_ACTIONS_ALL);
	menu.AddItem(CHOICE1, "Hours Whitelist");
	menu.AddItem(CHOICE2, "Bans Whitelist");
	menu.AddItem(CHOICE3, "Level Whitelist");
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int mPickWhitelist(Menu menu, MenuAction action, int param1, int param2) {
	
	switch (action) {
		
		case MenuAction_Display: {
			
			char buffer[255];
			Format(buffer, sizeof(buffer), "%t", "Select a Table");
			
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
			
		}
		
		case MenuAction_Select: {
			
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			MenuQuery(param1, info);
			
		}
		
		case MenuAction_End: {
			
			delete menu;
			
		}
	}
	return 0;
}

public void MenuQuery(int param1, char[] info) {
	
	int client = param1;
	char table[32];
	
	if (StrEqual(info, "hoursTable", false))
		Format(table, sizeof(table), "ps_whitelist");
	if (StrEqual(info, "bansTable", false))
		Format(table, sizeof(table), "ps_whitelist_bans");
	if (StrEqual(info, "levelTable", false))
		Format(table, sizeof(table), "ps_whitelist_level");
	
	char query[256];
	g_Database.Format(query, sizeof(query), "SELECT * FROM %s", table);
	
	DataPack pack = new DataPack();
	pack.WriteString(table);
	pack.WriteCell(GetClientUserId(client));
	
	g_Database.Query(SQL_MenuQuery, query, pack);
}

public void SQL_MenuQuery(Database db, DBResultSet results, const char[] error, DataPack pack) {
	
	pack.Reset();
	char table[32];
	pack.ReadString(table, sizeof(table));
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	
	if (!client) {
		return;
	}
	
	if (db == null || results == null) {
		
		LogError("[PS] Error while querying %s for menu display! %s", table, error);
		PrintToServer("[PS] Error while querying %s for menu display! %s", table, error);
		CPrintToChat(client, "[PS] Error while querying %s for menu display! %s", table, error);
		return;
	}
		
	char type[16];
	
	if (StrEqual(table, "hoursTable", false))
		Format(type, sizeof(type), "Hours");
	if (StrEqual(table, "bansTable", false))
		Format(type, sizeof(type), "Bans");
	if (StrEqual(table, "levelTable", false))
		Format(type, sizeof(type), "Level");
			
	int entryCol, steamidCol;
	
	results.FieldNameToNum("entry", entryCol);
	results.FieldNameToNum("steamid", steamidCol);
	
	Menu menu = new Menu(TablesMenu, MENU_ACTIONS_ALL);
	menu.SetTitle("Showing %s Whitelist", type);
		
	char steamid[32], id[16];
	int count;
	
	if (!results.FetchRow()) {
		CPrintToChat(client, "%t", "No Results");
		OpenWhitelistMenu(client);
		return;
	} else {
		do {
			count++;
			results.FetchString(steamidCol, steamid, sizeof(steamid));
			IntToString(count, id, sizeof(id));
			menu.AddItem(id, steamid, ITEMDRAW_RAWLINE);
			
		} while (results.FetchRow());
		menu.ExitBackButton = true;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
}

public int TablesMenu(Menu menu, MenuAction action, int param1, int param2) {
	
	switch (action) {
		
		case MenuAction_Cancel: {
			
			if (param2 == MenuCancel_ExitBack) {
				OpenWhitelistMenu(param1);
				delete menu;
			}
		}
		
	}
	return 0;
}