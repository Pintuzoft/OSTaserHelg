#include <sourcemod>
#include <sdktools>
#include <sdktools_gamerules>
#include <cstrike>

char adminstr[1024];
char error[255];
Handle knivhelg = null;

public Plugin myinfo = {
	name = "OSTaserHelg",
	author = "Pintuz",
	description = "OldSwedes Taser helg plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSTaserHelg"
}

public void OnPluginStart ( ) {
    HookEvent ( "player_death", Event_PlayerDeath );
    RegConsoleCmd ( "sm_ttop", Command_TaserTop, "Shows the top 10 taser kills" );
    AutoExecConfig ( true, "ostaserhelg" );
}

public void OnMapStart ( ) {
    checkConnection ( );
    fetchAdminStr ( );
}

/* EVENTS */
 
public void Event_PlayerDeath ( Event event, const char[] name, bool dontBroadcast ) {
    int victim_id = GetEventInt(event, "userid");
    int attacker_id = GetEventInt(event, "attacker");
    int victim = GetClientOfUserId(victim_id);
    int attacker = GetClientOfUserId(attacker_id);
    char victim_name[64];
    char attacker_name[64];
    char victim_authid[32];
    char attacker_authid[32];
    char weapon[32];
    bool isAttackerAdmin;
    bool isVictimAdmin;

    if ( ! playerIsReal ( victim ) || 
         ! playerIsReal ( attacker ) ||
         victim == attacker ) {
        return;
    }
    
    GetEventString ( event, "weapon", weapon, sizeof(weapon) );

    if ( ! stringContains ( weapon, "TASER" ) ){
        return;
    }

    if ( isWarmup ( ) ) {
        PrintToChatAll ( "[OSTaserHelg]: Its warmup so taser doesnt count!" );
        return;
    }
    
    GetClientName ( victim, victim_name, sizeof ( victim_name ) );
    GetClientName ( attacker, attacker_name, sizeof ( attacker_name ) );
    GetClientAuthId ( victim, AuthId_Steam2, victim_authid, sizeof ( victim_authid ) );
    GetClientAuthId ( attacker, AuthId_Steam2, attacker_authid, sizeof ( attacker_authid ) );
    
    if ( ! isValidSteamID ( victim_authid ) || ! isValidSteamID ( attacker_authid ) ) {
        return;
    }

    isAttackerAdmin = isPlayerAdmin ( attacker_authid );
    isVictimAdmin = isPlayerAdmin ( victim_authid );

    addKnifeEvent ( attacker_name, attacker_authid, victim_name, victim_authid, isVictimAdmin );
    incPoints ( attacker_name, attacker_authid, isVictimAdmin );
    decPoints ( victim_name, victim_authid, isVictimAdmin );
    
    if ( isAttackerAdmin && isVictimAdmin ) {
        PrintToChatAll ( " \x02[OSKnivHelg]: %s (admin) tasered %s (admin) and got %d points!", attacker_name, victim_name, 10 );
    } else if ( isVictimAdmin ) {
        PrintToChatAll ( " \x02[OSKnivHelg]: %s tasered %s (admin) and got %d points!", attacker_name, victim_name, 10 );
    } else if ( isAttackerAdmin ) {
        PrintToChatAll ( " \x02[OSKnivHelg]: %s (admin) tasered %s and got %d points!", attacker_name, victim_name, 5 );
    } else {
        PrintToChatAll ( " \x02[OSKnivHelg]: %s tasered %s and got %d points!", attacker_name, victim_name, 5 );
    }
}


/* END of EVENTS */

/* COMMANDS*/
public Action Command_TaserTop ( int client, int args ) {
    checkConnection ( );
    DBStatement stmt;
    char name[64];
    char steamid[32];
    char sid[32];
    int points;
    int i;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "select name,steamid,points from userstats order by points desc limit 10;", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x07] (error: %s)", error);
        return Plugin_Handled;
    }

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to query[0x08] (error: %s)", error);
        return Plugin_Handled;
    }

    GetClientAuthId ( client, AuthId_Steam2, steamid, sizeof ( steamid ) );
    if ( ! isValidSteamID ( steamid ) ) {
        steamid = "STEAM_9:9:9";
    }
    PrintToChat ( client, " \x04[OSTaserHelg]: Leaderboard:" );
    i = 1;
    while ( SQL_FetchRow ( stmt ) ) {
        SQL_FetchString ( stmt, 0, name, sizeof(name) );
        SQL_FetchString ( stmt, 1, sid, sizeof(sid) );
        points = SQL_FetchInt ( stmt, 2 );
        if ( StrContains ( steamid, sid, false ) ) {
            PrintToChat ( client, " \x04- %d. %s: %dp", i, name, points );
        } else {
            PrintToChat ( client, " \x04- \x09%d. %s: %dp", i, name, points );
        }
        i++;
    }
    PrintToChat ( client, " \x04[OSTaserHelg]: Full stats: https://oldswedes.se/taserhelg" );
    return Plugin_Handled;
}

/* METHODS */
 
public void fetchAdminStr ( ) {
    char buf[32];
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "select steamid from admin;", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x09] (error: %s)", error);
        return;
    }

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to query[0x10] (error: %s)", error);
        return;
    }
    adminstr = "";
    while ( SQL_FetchRow ( stmt ) ) {
        SQL_FetchString ( stmt, 0, buf, sizeof(buf) );
        Format ( adminstr, sizeof(adminstr), "%s;%s", adminstr, buf );
    } 
    PrintToServer ( "[OSTaserHelg]: adminstr: %s", adminstr );

    if ( stmt != null ) {
        delete stmt;
    }
}

public void incPoints ( char name[64], char authid[32], bool isVictimAdmin ) {
    checkConnection ();
    char query[255];
    DBStatement stmt;
    int points = (isVictimAdmin?10:5);
        
    Format ( query, sizeof(query), "insert into userstats (name,steamid,points) values (?,?,?) on duplicate key update points = points + ?;" );
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, query, error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x02] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, name, false );
    SQL_BindParamString ( stmt, 1, authid, false );
    SQL_BindParamInt ( stmt, 2, points );
    SQL_BindParamInt ( stmt, 3, points );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to query[0x03] (error: %s)", error);
        return;
    }

    if ( stmt != null ) {
        delete stmt;
    }
}
public void decPoints ( char name[64], char authid[32], bool isVictimAdmin ) {
    checkConnection ();
    char query[255];
    DBStatement stmt;
    int points = (isVictimAdmin?10:5);
         
    Format ( query, sizeof(query), "insert into userstats (name,steamid,points) values (?,?,?) on duplicate key update points = points - ?;" );
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, query, error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x02] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, name, false );
    SQL_BindParamString ( stmt, 1, authid, false );
    SQL_BindParamInt ( stmt, 2, -points );
    SQL_BindParamInt ( stmt, 3, points );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to query[0x03] (error: %s)", error);
        return;
    }

    if ( stmt != null ) {
        delete stmt;
    }
}

public bool isPlayerAdmin ( char authid[32] ) {
    ReplaceString ( authid, sizeof(authid), "STEAM_0", "STEAM_1" );
    return ( StrContains ( adminstr, authid, false ) != -1 );
}
 
public bool stringContains ( char string[32], char match[32] ) {
    return ( StrContains ( string, match, false ) != -1 );
}

public bool isValidSteamID ( char authid[32] ) {
    if ( stringContains ( authid, "STEAM_0" ) ) {
        return true;
    } else if ( stringContains ( authid, "STEAM_1" ) ) {
        return true;
    }
    return false;
}

public void addKnifeEvent ( char attacker_name[64], char attacker_authid[32], char victim_name[64], char victim_authid[32], int isAdmin ) {
    checkConnection ( )
    DBStatement stmt;
    int points = (isAdmin?10:5);
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "insert into event (stamp,attacker,attackerid,victim,victimid,points) values (now(),?,?,?,?,?)", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error) );
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x01] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, attacker_name, false );
    SQL_BindParamString ( stmt, 1, attacker_authid, false );
    SQL_BindParamString ( stmt, 2, victim_name, false );
    SQL_BindParamString ( stmt, 3, victim_authid, false );
    SQL_BindParamInt ( stmt, 4, points );
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to query[0x02] (error: %s)", error);
    }
    if ( stmt != null ) {
        delete stmt;
    }
}
 
public void databaseConnect ( ) {
    if ( ( knivhelg = SQL_Connect ( "knivhelg", true, error, sizeof(error) ) ) != null ) {
        PrintToServer ( "[OSTaserHelg]: Connected to knivhelg database!" );
    } else {
        PrintToServer ( "[OSTaserHelg]: Failed to connect to knivhelg database! (error: %s)", error );
    }
}

public void checkConnection ( ) {
    if ( knivhelg == null || knivhelg == INVALID_HANDLE ) {
        databaseConnect ( );
    }
}
 
/* return true if player is real */
public bool playerIsReal ( int player ) {
    return ( player > 0 &&
             IsClientInGame ( player ) &&
             ! IsClientSourceTV ( player ) );
}

/* isWarmup */
public bool isWarmup ( ) {
    if ( GameRules_GetProp ( "m_bWarmupPeriod" ) == 1 ) {
        return true;
    } 
    return false;
}