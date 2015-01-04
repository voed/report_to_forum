
#if defined _rtf_included
	#endinput
#endif
#define _rtf_included

stock rtf_get_steamurl( const SteamID[], url[], len )
{
	new szLeft[9], iSteamid, iLeft
	new szTemp[35]
	copy(szTemp, charsmax(szTemp), SteamID)
	strtok( szTemp, szLeft, charsmax(szLeft), szTemp, charsmax(szTemp), ':' ) //remove STEAM_0:
	strtok( szTemp, szLeft, charsmax(szLeft), szTemp, charsmax(szTemp), ':' ) //take left and right part
	iLeft = str_to_num( szLeft[ 0 ] )
	iSteamid = str_to_num( szTemp )
	iSteamid = iSteamid * 2 + iLeft
	formatex(url, len, "http://steamcommunity.com/profiles/[U:1:%i]", iSteamid)
}

stock bool:is_user_steam( index )
{
// Author Sh0oter
        static dp_pointer
	
        if( dp_pointer || ( dp_pointer = get_cvar_pointer( "dp_r_id_provider" ) ) )
        {
            server_cmd( "dp_clientinfo %d", index )
            server_exec()
            return ( get_pcvar_num( dp_pointer ) == 2 ) ? true : false
        }
	
        return false
}


stock SeoTitle(szString[], len)
{
	replace_all(szString, len, " ", "-");
	strtolower(szString)
}

stock mysql_escape_string(dest[], len)
{
	replace_all(dest, len, "\\", "\\\\")
	replace_all(dest, len, "\0", "\\0")
	replace_all(dest, len, "\n", "\\n")
	replace_all(dest, len, "\r", "\\r")
	replace_all(dest, len, "\x1a", "\Z")
	replace_all(dest, len, "'", "\'")
	replace_all(dest, len, "^"", "\^"")
}

stock GetWebSafeString(szString[], len)
{	
	replace_all(szString, len, "/", "");
	replace_all(szString, len, "\\", "");
	replace_all(szString, len, "[", "");
	replace_all(szString, len, "]", "");
	replace_all(szString, len, "}", "");
	replace_all(szString, len, "{", "");
	replace_all(szString, len, "|", "");
	replace_all(szString, len, "?", "");
	replace_all(szString, len, "=", "");
	replace_all(szString, len, "+", "");
	replace_all(szString, len, ">", "");
	replace_all(szString, len, "<", "");
	replace_all(szString, len, "*", "");
	replace_all(szString, len, "\", "");
	replace_all(szString, len, "'", "");
	replace_all(szString, len, "`", "");
	replace_all(szString, len, "!", "");
	replace_all(szString, len, "@", "");
	replace_all(szString, len, "#", "");
	replace_all(szString, len, "$", "");
	replace_all(szString, len, "%", "");
	replace_all(szString, len, "^^", "");
	replace_all(szString, len, "&", "");
}

