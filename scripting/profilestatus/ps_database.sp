/* Database connection, driver check and tables creation */

public void SQL_ConnectDatabase(Database db, const char[] error, any data) {
	
	if (db == null) {
		LogError("[PS] Could not connect to database %s! Error: %s", cvDatabase, error);
		PrintToServer("[PS] Could not connect to database %s! Error: %s", cvDatabase, error);
		return;
	}
	
	PrintToServer("[PS] Database connection to \"%s\" successful!", cvDatabase);
	g_Database = db;
	GetDriver();
	CreateTable();
}

public void GetDriver() {
	
	SQL_ReadDriver(g_Database, DBDRIVER, sizeof(DBDRIVER));
	g_bIsLite = strcmp(DBDRIVER, "sqlite") == 0 ? true : false;
	
}

public void CreateTable() {
	
	char sQuery1[256];
	char sQuery2[256];
	char sQuery3[256];
	
	if (g_bIsLite) {
		StrCat(sQuery1, sizeof(sQuery1), "CREATE TABLE IF NOT EXISTS ps_whitelist(");
		StrCat(sQuery1, sizeof(sQuery1), "entry INTEGER PRIMARY KEY, ");
		StrCat(sQuery1, sizeof(sQuery1), "steamid VARCHAR(17), ");
		StrCat(sQuery1, sizeof(sQuery1), "unique (steamid));");
		
		StrCat(sQuery2, sizeof(sQuery2), "CREATE TABLE IF NOT EXISTS ps_whitelist_bans(");
		StrCat(sQuery2, sizeof(sQuery2), "entry INTEGER PRIMARY KEY, ");
		StrCat(sQuery2, sizeof(sQuery2), "steamid VARCHAR(17), ");
		StrCat(sQuery2, sizeof(sQuery2), "unique (steamid));");
		
		StrCat(sQuery3, sizeof(sQuery3), "CREATE TABLE IF NOT EXISTS ps_whitelist_level(");
		StrCat(sQuery3, sizeof(sQuery3), "entry INTEGER PRIMARY KEY, ");
		StrCat(sQuery3, sizeof(sQuery3), "steamid VARCHAR(17), ");
		StrCat(sQuery3, sizeof(sQuery3), "unique (steamid));");
		
		g_Database.Query(SQL_CreateTable, sQuery1);
		g_Database.Query(SQL_CreateTable, sQuery2);
		g_Database.Query(SQL_CreateTable, sQuery3);
		return;
	}
	StrCat(sQuery1, sizeof(sQuery1), "CREATE TABLE IF NOT EXISTS ps_whitelist(");
	StrCat(sQuery1, sizeof(sQuery1), "entry INT NOT NULL AUTO_INCREMENT, ");
	StrCat(sQuery1, sizeof(sQuery1), "steamid VARCHAR(17) UNIQUE, ");
	StrCat(sQuery1, sizeof(sQuery1), "PRIMARY KEY (entry));");
	
	StrCat(sQuery2, sizeof(sQuery2), "CREATE TABLE IF NOT EXISTS ps_whitelist_bans(");
	StrCat(sQuery2, sizeof(sQuery2), "entry INT NOT NULL AUTO_INCREMENT, ");
	StrCat(sQuery2, sizeof(sQuery2), "steamid VARCHAR(17) UNIQUE, ");
	StrCat(sQuery2, sizeof(sQuery2), "PRIMARY KEY (entry));");
	
	StrCat(sQuery3, sizeof(sQuery3), "CREATE TABLE IF NOT EXISTS ps_whitelist_level(");
	StrCat(sQuery3, sizeof(sQuery3), "entry INT NOT NULL AUTO_INCREMENT, ");
	StrCat(sQuery3, sizeof(sQuery3), "steamid VARCHAR(17) UNIQUE, ");
	StrCat(sQuery3, sizeof(sQuery3), "PRIMARY KEY (entry));");
	
	g_Database.Query(SQL_CreateTable, sQuery1);
	g_Database.Query(SQL_CreateTable, sQuery2);
	g_Database.Query(SQL_CreateTable, sQuery3);	
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data) {
	
	if (db == null || results == null)
	{
		LogError("[PS] Create Table Query failure! %s", error);
		PrintToServer("[PS] Create Table Query failure! %s", error);
		return;
	}
	
	cc--;
	if (!cc) PrintToServer("[PS] Tables successfully created or were already created!");
}