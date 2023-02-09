#include <sourcemod>
#include <sdktools>
#include <sdktools_gamerules>
#include <cstrike>

char adminstr[1024];
char error[255];
Handle taserhelg = null;

ConVar adminPointsEnabled;

public Plugin myinfo = {
	name = "OSTaserHelg",
	author = "Pintuz",
	description = "OldSwedes Taser en admin helg plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSTaserHelg"
}

public void OnPluginStart ( ) {
    HookEvent ( "player_death", Event_PlayerDeath );
    adminPointsEnabled = CreateConVar ( "ostaserhelg_admin_points_enabled", "1", "Enable admin points" );
    RegConsoleCmd ( "sm_ttop", Command_KnifeTop, "Shows the top 10 taser kills" );
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
    bool teamKill;
    int points = 5;

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
    
 
    //if ( ! isValidSteamID ( victim_authid ) || ! isValidSteamID ( attacker_authid ) ) {
    //    return;
    //}

    teamKill = isTeamKill ( attacker, victim );

    if ( adminPointsEnabled.BoolValue && isPlayerAdmin ( victim_authid ) ) {
        points = 10;
    }

    isAttackerAdmin = isPlayerAdmin ( attacker_authid );
    isVictimAdmin = isPlayerAdmin ( victim_authid );


    
    if ( teamKill ) {
        addKnifeEvent ( attacker_name, attacker_authid, victim_name, victim_authid, -points );
        fixPoints ( victim_name, victim_authid, true, points );
        fixPoints ( attacker_name, attacker_authid, false, points );
        if ( isAttackerAdmin && isVictimAdmin ) {
            PrintToChatAll ( " \x04[OSTaserHelg]\x01: \x06%s \x08(admin) \x01tasered teammate \x07%s \x08(admin) \x01and got \x07-%d \x01points!", attacker_name, victim_name, points );
        } else if ( isVictimAdmin ) {
            PrintToChatAll ( " \x04[OSTaserHelg]\x01: \x06%s tasered \x01teammate \x07%s \x08(admin) \x01and got \x07-%d \x01points!", attacker_name, victim_name, points );
        } else if ( isAttackerAdmin ) {
            PrintToChatAll ( " \x04[OSTaserHelg]\x01: \x06%s \x08(admin) \x01tasered teammate \x07%s \x01and got \x07-%d \x01points!", attacker_name, victim_name, points );
        } else {
            PrintToChatAll ( " \x04[OSTaserHelg]\x01: \x06%s \x01tasered teammate \x07%s \x01and got \x07-%d \x01points!", attacker_name, victim_name, points );
        }
    } else {
        addKnifeEvent ( attacker_name, attacker_authid, victim_name, victim_authid, points );
        fixPoints ( attacker_name, attacker_authid, true, points );
        fixPoints ( victim_name, victim_authid, false, points );
        if ( isAttackerAdmin && isVictimAdmin ) {
            PrintToChatAll ( " \x04[OSTaserHelg]\x01: \x06%s \x08(admin) \x01tasered \x07%s \x08(admin) \x01and got \x04%d \x01points!", attacker_name, victim_name, points );
        } else if ( isVictimAdmin ) {
            PrintToChatAll ( " \x04[OSTaserHelg]\x01: \x06%s \x01tasered \x07%s \x08(admin) \x01and got \x04%d \x01points!", attacker_name, victim_name, points );
        } else if ( isAttackerAdmin ) {
            PrintToChatAll ( " \x04[OSTaserHelg]\x01: \x06%s \x08(admin) \x01tasered \x07%s \x01and got \x04%d \x01points!", attacker_name, victim_name, points );
        } else {
            PrintToChatAll ( " \x04[OSTaserHelg]\x01: \x06%s \x01tasered \x07%s \x01and got \x04%d \x01points!", attacker_name, victim_name, points );
        }
    }
}


/* END of EVENTS */

/* COMMANDS*/
public Action Command_KnifeTop ( int client, int args ) {
    checkConnection ( );
    DBStatement stmt;
    char name[64];
    char steamid[32];
    char sid[32];
    int points;
    int i;
    if ( ( stmt = SQL_PrepareQuery ( taserhelg, "select name,steamid,points from userstats order by points desc limit 10;", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( taserhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x07] (error: %s)", error);
        return Plugin_Handled;
    }

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( taserhelg, error, sizeof(error));
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
            PrintToChat ( client, " \x04[OSTaserHelg]: %d. %s: %dp", i, name, points );
        } else {
            PrintToChat ( client, " \x04[OSTaserHelg]: \x09%d. %s: %dp", i, name, points );
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
    if ( ( stmt = SQL_PrepareQuery ( taserhelg, "select steamid from admin;", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( taserhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x09] (error: %s)", error);
        return;
    }

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( taserhelg, error, sizeof(error));
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

public void fixPoints ( char name[64], char authid[32], bool increase, int points ) {
    checkConnection ();
    char query[255];
    DBStatement stmt;
    if ( increase ) {
        Format ( query, sizeof(query), "insert into userstats (name,steamid,points) values (?,?,?) on duplicate key update points = points + ?;" );
    } else {
        Format ( query, sizeof(query), "insert into userstats (name,steamid,points) values (?,?,?) on duplicate key update points = points - ?;" );
    }
    if ( ( stmt = SQL_PrepareQuery ( taserhelg, query, error, sizeof(error) ) ) == null ) {
        SQL_GetError ( taserhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x02] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, name, false );
    SQL_BindParamString ( stmt, 1, authid, false );
    if ( increase ) {
        SQL_BindParamInt ( stmt, 2, points );
    } else {
        SQL_BindParamInt ( stmt, 2, -points );
    }
    SQL_BindParamInt ( stmt, 3, points );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( taserhelg, error, sizeof(error));
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

public void addKnifeEvent ( char attacker_name[64], char attacker_authid[32], char victim_name[64], char victim_authid[32], int points ) {
    checkConnection ( )
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( taserhelg, "insert into event (stamp,attacker,attackerid,victim,victimid,points) values (now(),?,?,?,?,?)", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( taserhelg, error, sizeof(error) );
        PrintToServer("[OSTaserHelg]: Failed to prepare query[0x01] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, attacker_name, false );
    SQL_BindParamString ( stmt, 1, attacker_authid, false );
    SQL_BindParamString ( stmt, 2, victim_name, false );
    SQL_BindParamString ( stmt, 3, victim_authid, false );
    SQL_BindParamInt ( stmt, 4, points );
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( taserhelg, error, sizeof(error));
        PrintToServer("[OSTaserHelg]: Failed to query[0x02] (error: %s)", error);
    }
    if ( stmt != null ) {
        delete stmt;
    }
}
 
public void databaseConnect ( ) {
    if ( ( taserhelg = SQL_Connect ( "taserhelg", true, error, sizeof(error) ) ) != null ) {
        PrintToServer ( "[OSTaserHelg]: Connected to taserhelg database!" );
    } else {
        PrintToServer ( "[OSTaserHelg]: Failed to connect to taserhelg database! (error: %s)", error );
    }
}

public void checkConnection ( ) {
    if ( taserhelg == null || taserhelg == INVALID_HANDLE ) {
        databaseConnect ( );
    }
}
 
/* IS TEAMKILL */
public bool isTeamKill ( int attacker, int victim ) {
    if ( GetClientTeam ( attacker ) == GetClientTeam ( victim ) ) {
        return true;
    }
    return false;
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
 