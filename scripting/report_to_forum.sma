/*This is a port sourcemod's "Report to Forums" plugin to AMX Mod X
Original plugin: http://forums.alliedmods.net/showthread.php?t=211126
Lastest verion of this plugin://
Author: voed
Special thanks: me <3, AndrewZ, Bloo
*/

#include <amxmodx>
#include <amxmisc>
#include <sqlx>

//#define VOTEBAN_MODE
#define CONFIG_DIR "/report_to_forum/report_to_forum.cfg"

new const PLUGIN_NAME[] = "Report To Forum";
new const PLUGIN_AUTHOR[] = "voed";
new const PLUGIN_VERSION[] = "0.1b";

new g_Reasons[][]={	"Wallhack", 
			"AIMBot", 
			"Speedhack" }

enum SupportedForums
{
	FORUM_UNSUPPORTED,
	FORUM_VB4,
	FORUM_MYBB,
	FORUM_SMF,
	FORUM_PHPBB,
	FORUM_WBBLITE,
	FORUM_AEF,
	FORUM_USEBB,
	FORUM_XMB,
	FORUM_IPBOARDS,
	FORUM_XENFORO
}

/* Plugin ConVars */
new g_Cvar_TablePrefix
new g_Cvar_ForumSoftwareID
new g_Cvar_VPSTimeDiff
new g_MySQL_User, g_MySQL_Pass, g_MySQL_Host, g_MySQL_DB

new g_Cvar_ForumID;
new g_Cvar_SenderID;
new g_Cvar_UserName ;
new g_Cvar_Email;
//new g_Cvar_AdminNoPost;


/* Post Info */
new g_szPostTitle[512];
new g_szPostMessage[512];

/* Misc Variables */
new SupportedForums:g_iForumSoftwareID;
new g_iForumID;
new g_iThreadID;
new g_iPostID;
new g_iPostCount;
new g_iUserPostCount;
new g_iThreadCount;
new g_iSenderID;
new g_szTablePrefix[32];
new g_iTimeStamp;

new Handle:g_SqlTuple
new g_Error[512]
new Handle:SqlConnection

new g_pHostName
new g_iTarget[33]

new g_szUserName[MAX_NAME_LENGTH];
new g_szEmail[64];
new g_szHostName[64];
new g_szMapName[64];

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
	
	/* RTF Version */
	register_cvar("rtf_version", PLUGIN_VERSION);
	
	/* Plugin ConVars */
	g_Cvar_ForumSoftwareID 	= register_cvar("rtf_forum_softwareid", "");		// Forum Software ID.
	g_Cvar_VPSTimeDiff 	= register_cvar("rtf_vps_time_diff", "");		// Time difference used for VPS servers.
	
	g_Cvar_ForumID 		= register_cvar("rtf_ca_forum_id", "");		// Forum ID to post the report
	g_Cvar_SenderID 	= register_cvar("rtf_ca_sender_id", "2");		// Sender ID to post under.
	g_Cvar_UserName 	= register_cvar("rtf_ca_username", "rtfbot");		// Sender User Name to use.
	g_Cvar_Email 		= register_cvar("rtf_ca_email", "");	// Sender Email Address. (Optional)
	//g_Cvar_AdminNoPost 	= register_cvar("rtf_ca_admin_no_post", "");		// Only Post if no admin is available.
	
	g_MySQL_Host		= register_cvar("rtf_host", "")
	g_MySQL_User 		= register_cvar("rtf_user", "")
	g_MySQL_Pass		= register_cvar("rtf_pass", "")
	g_MySQL_DB		= register_cvar("rtf_database", "")
	g_Cvar_TablePrefix 	= register_cvar("rtf_table_prefix", "")		// Prefix to the tables in your forums database.
	
	#if defined VOTEBAN_MODE
	register_clcmd("say /voteban", "SayReport")
	#else
	register_clcmd("say !report", "SayReport")
	#endif
	
	g_pHostName      = get_cvar_pointer( "hostname" );
	
	register_dictionary("report_to_forum.txt");
	
	
	new cdir[64]
	get_configsdir(cdir, charsmax(cdir))
	format(cdir, charsmax(cdir), "%s%s", cdir, CONFIG_DIR)
	
	if(file_exists(cdir))
	{
		server_cmd("exec %s", cdir)
		server_exec()
	}
	else
		set_fail_state("[RTF] Config file does not exists")
		
		
	new conn[4][64]
	get_pcvar_string(g_MySQL_Host, conn[0], 32)
	get_pcvar_string(g_MySQL_User, conn[1], 32)
	get_pcvar_string(g_MySQL_Pass, conn[2], 32)
	get_pcvar_string(g_MySQL_DB, conn[3], 32)
	
	SQL_SetAffinity("mysql")	
	g_SqlTuple = SQL_MakeDbTuple(conn[0],conn[1],conn[2],conn[3])
	SQL_SetCharset(g_SqlTuple, "utf8");
   
	// ok, we're ready to connect
	new ErrorCode
	SqlConnection = SQL_Connect(g_SqlTuple,ErrorCode,g_Error,511)
	if(SqlConnection == Empty_Handle)
	{
		log_amx("Cant connect to database. Error: %s", g_Error)
		set_fail_state(g_Error)
	}
}

public plugin_cfg()
{	
	
	get_pcvar_string(g_Cvar_UserName, g_szUserName, sizeof(g_szUserName));
	get_pcvar_string(g_Cvar_Email, g_szEmail, sizeof(g_szEmail));
	g_iForumID = get_pcvar_num(g_Cvar_ForumID);
	g_iSenderID = get_pcvar_num(g_Cvar_SenderID);
	
	/* Cache the Forum Softare ID */
	g_iForumSoftwareID = SupportedForums:get_pcvar_num(g_Cvar_ForumSoftwareID);
	
	/* Get the Table Prefix */
	get_pcvar_string(g_Cvar_TablePrefix, g_szTablePrefix, charsmax(g_szTablePrefix))
	get_mapname(g_szMapName, charsmax(g_szMapName))
	
}

public plugin_end()
{
	SQL_FreeHandle(g_SqlTuple) 
}

public SayReport(id)
{
	new title[128]
	formatex(title, charsmax(title), "%L", id, "RTF_MENU_CHOOSE_PLAYER")
	new i_Menu = menu_create(title, "SayReportHandler", 1)
	
	new s_Players[32], i_Num, i_Player
	new s_Name[32], s_Player[10]
	get_players(s_Players, i_Num, "ch")

	for (new i; i < i_Num; i++)
	{ 
		i_Player = s_Players[i]
		
		get_user_name(i_Player, s_Name, charsmax(s_Name))
		num_to_str(i_Player, s_Player, charsmax(s_Player))
		menu_additem(i_Menu, s_Name, s_Player, 0)
	}
	
	menu_display(id, i_Menu, 0)
	return PLUGIN_HANDLED
}

public SayReportHandler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
	new s_Data[6], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), _, _, i_Callback )
	
	g_iTarget[id] = str_to_num(s_Data)
	
	ReportReason(id)
	
	menu_destroy(menu)
	return PLUGIN_HANDLED
	
}

public ReportReason(id)
{
	new title[128]
	formatex(title, charsmax(title), "%L", id, "RTF_MENU_CHOOSE_REASON")
	new i_Menu = menu_create(title, "ReportReasonHandler", 1)
	
	for(new i=0; i<sizeof(g_Reasons); i++)
	{
		new key[4]
		num_to_str(i, key, charsmax(key))
		menu_additem(i_Menu, g_Reasons[i], key)
	}
	
	menu_display(id, i_Menu, 0)
	return PLUGIN_HANDLED
}

public ReportReasonHandler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
	new s_Data[6], s_Name[32], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback )
	
	SendReport(id, g_iTarget[id], s_Name)
	
	menu_destroy(menu)
	return PLUGIN_HANDLED
}
public SendReport(sender_id, target_id, reason[])
{
	new szReason[64]
	if((!sender_id) || (!target_id) || (!reason[0]))
		return PLUGIN_HANDLED
		
	formatex(szReason, charsmax(szReason), reason)
	new sender_name[32], name[32], steamid[32], ip[16]
	get_user_name(target_id, name, charsmax(name))
	get_user_name(sender_id, sender_name, charsmax(sender_name))
	get_user_authid(target_id, steamid, charsmax(steamid))
	get_user_ip(target_id, ip, charsmax(ip), 1)
	get_pcvar_string( g_pHostName, g_szHostName, 63 );
	new br[10]
	if(g_iForumSoftwareID == FORUM_IPBOARDS)
	{
		formatex(br, charsmax(br), "<br />")
	}
	else
	{
		formatex(br, charsmax(br), "^n")
	}
	
	formatex(g_szPostTitle, charsmax(g_szPostTitle), "%s %L %s", name, LANG_SERVER, "RTF_REPORTED_FOR", szReason)
	formatex(g_szPostMessage, charsmax(g_szPostMessage), "%L %s%s", LANG_SERVER, "RTF_HOST_NAME", g_szHostName, br)
	format(g_szPostMessage, charsmax(g_szPostMessage), "%s%L %s%s", g_szPostMessage, LANG_SERVER, "RTF_SENDER_NAME", sender_name, br)
	format(g_szPostMessage, charsmax(g_szPostMessage), "%s%L %s%s", g_szPostMessage, LANG_SERVER, "RTF_NAME", name, br)
	format(g_szPostMessage, charsmax(g_szPostMessage), "%s%L %s%s", g_szPostMessage, LANG_SERVER, "RTF_STEAMID", steamid, br)
	format(g_szPostMessage, charsmax(g_szPostMessage), "%s%L %s%s", g_szPostMessage, LANG_SERVER, "RTF_IP", ip, br)
	format(g_szPostMessage, charsmax(g_szPostMessage), "%s%L %s", g_szPostMessage, LANG_SERVER, "RTF_REASON", szReason)
	
	GetWebSafeString(g_szPostTitle, charsmax(g_szPostTitle));
	GetWebSafeString(g_szUserName, charsmax(g_szUserName));
	mysql_escape_string(g_szPostTitle, charsmax(g_szPostTitle));
	mysql_escape_string(g_szUserName, charsmax(g_szUserName));
	mysql_escape_string(g_szPostMessage, charsmax(g_szPostMessage));
	//log_amx("Server: %s^nSender name: %s^nUser name: %s^nUser SteamID: %s^nReason:%s", g_szHostName, sender_name, name, steamid, reason)
	g_iTimeStamp = (get_systime() - get_pcvar_num(g_Cvar_VPSTimeDiff));
	
	if(!g_szTablePrefix[0])
	{
		switch(g_iForumSoftwareID)
		{
			//case FORUM_VB4:
			//case FORUM_MYBB:			
			case FORUM_SMF:g_szTablePrefix 		= "smf_"
			case FORUM_PHPBB:g_szTablePrefix 	= "phpbb_"
			//case FORUM_WBBLITE:
			//case FORUM_AEF:
			//case FORUM_USEBB:
			//case FORUM_XMB:
			//case FORUM_IPBOARDS:
			case FORUM_XENFORO:g_szTablePrefix 	= "xf_"
		}
	}
	
	SendForumPost()
	FindRecentThread()
	CreateThreadPost()
	if(g_iForumSoftwareID != FORUM_MYBB)
	{
		GetPostId()
		SetPostId()
	}
	
	GetCurrentForumPostData()
	UpdateForumPostCount(g_iThreadCount, g_iPostCount)
	
	GetUserPostInfo();
	UpdateUserPostCount(g_iUserPostCount);
	
	client_print(sender_id, print_chat, "%L", sender_id, "RTF_REPORT_SENDED")
	return PLUGIN_HANDLED
}

public SendForumPost()
{
	new szSeoTitle[256], szSeoName[64]
	formatex(szSeoTitle, charsmax(szSeoTitle), "%s", g_szPostTitle, charsmax(g_szPostTitle))
	SeoTitle(szSeoTitle, charsmax(szSeoTitle))
	
	formatex(szSeoName, charsmax(szSeoName), "%s", g_szUserName, charsmax(g_szUserName))
	SeoTitle(szSeoName, charsmax(szSeoName))
	
	new szSQLQuery[1024]
	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sthread (title, lastpost, forumid, open, postusername, postuserid, lastposter, lastposterid, dateline, visible) VALUES ('%s', '%d', '%d', '1', '%s', '%d', '%s', '%d', '%d', '1');", g_szTablePrefix, g_szPostTitle, g_iTimeStamp, g_iForumID, g_szUserName, g_iSenderID, g_szUserName, g_iSenderID, g_iTimeStamp);
		case FORUM_MYBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sthreads (fid, subject, uid, username, dateline, firstpost, lastpost, visible) VALUES ('%d', '%s', '%d', '%s', '%d', '1', '%d', '1');", g_szTablePrefix, g_iForumID, g_szPostTitle, g_iSenderID, g_szUserName, g_iTimeStamp, g_iTimeStamp);			
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %stopics (id_board, approved) VALUES ('%d', '1');", g_szTablePrefix, g_iForumID);
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %stopics (forum_id, topic_title, topic_poster, topic_time, topic_views, topic_first_poster_name, topic_first_poster_colour, topic_last_poster_id, topic_last_poster_name, topic_last_post_subject, topic_last_post_time, topic_last_view_time, topic_posts_approved) VALUES ('%d', '%s', '%d', '%d', '1', '%s', 'AA0000', '%d', '%s', '%s', '%d', '%d', '1');", g_szTablePrefix, g_iForumID, g_szPostTitle, g_iSenderID, g_iTimeStamp, g_szUserName, g_iSenderID, g_szUserName, g_szPostTitle, g_iTimeStamp, g_iTimeStamp);
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sthread (boardID, topic, time, userID, username, lastPostTime, lastPosterID, lastPoster) VALUES ('%d', '%s', '%d', '%d', '%s', '%d', '%d', '%s');", g_szTablePrefix, g_iForumID, g_szPostTitle, g_iTimeStamp, g_iSenderID, g_szUserName, g_iTimeStamp, g_iSenderID, g_szUserName);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %stopics (topic, t_bid, t_status, t_mem_id, t_approved) VALUES ('%s', '%d', '1', '%d', '1');", g_szTablePrefix, g_szPostTitle, g_iForumID, g_iSenderID);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %stopics (forum_id, topic_title) VALUES ('%d', '%s');", g_szTablePrefix, g_iForumID, g_szPostTitle);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sthreads (fid, subject, author) VALUES ('%d', '%s', '%s');", g_szTablePrefix, g_iForumID, g_szPostTitle, g_szUserName);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %stopics (title, state, posts, starter_id, start_date, last_poster_id, last_post, starter_name, last_poster_name, poll_state, last_vote, views, forum_id, approved, author_mode, pinned, title_seo, seo_first_name, seo_last_name, last_real_post) VALUES ('%s', 'open', '1', '%d', '%d', '%d', '%d', '%s', '%s', '0', '0', '1','%d', '1', '1', '0', '%s', '%s', '%s', '%d');", g_szTablePrefix, g_szPostTitle, g_iSenderID, g_iTimeStamp, g_iSenderID, g_iTimeStamp, g_szUserName, g_szUserName, g_iForumID, szSeoTitle, szSeoName, szSeoName, g_iTimeStamp);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sthread (node_id, title, reply_count, view_count, user_id, username, post_date, last_post_date, discussion_state, last_post_id, last_post_user_id, last_post_username) VALUES ('%d', '%s', '0', '0', '%d', '%s', '%d', '%d', 'visible', '%d', '%d', '%s');", g_szTablePrefix, g_iForumID, g_szPostTitle, g_iSenderID, g_szUserName, g_iTimeStamp, g_iTimeStamp, g_iForumID, g_iSenderID, g_szUserName);
	}
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant create thread. Error: %s", g_Error)
        }
        // close the handle
        SQL_FreeHandle(Query)
}


/* Finds the Thread ID for the thread we just created */
public FindRecentThread()
{
	new szSQLQuery[512];
	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT threadid FROM %sthread WHERE dateline='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_MYBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT tid FROM %sthreads WHERE dateline='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT MAX(id_topic) FROM %stopics;", g_szTablePrefix);
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT topic_id FROM %stopics WHERE topic_time='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT threadID FROM %sthread WHERE time='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT MAX(tid) FROM %stopics;", g_szTablePrefix);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT MAX(id) FROM %stopics;", g_szTablePrefix);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT tid FROM %stopics WHERE lastpost='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT tid FROM %stopics WHERE last_post='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT thread_id FROM %sthread WHERE post_date='%d';", g_szTablePrefix, g_iTimeStamp);
	}
	
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant find thread. Error: %s", g_Error)
        }
	
	if(SQL_NumResults(Query))
	{
		g_iThreadID = SQL_ReadResult(Query, 0)
	}
	else 	
		g_iThreadID = 1
        SQL_FreeHandle(Query)
}

/* Creates the Post (message) for the thread we created */
public CreateThreadPost()
{	
	new szSQLQuery[1024];
	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %spost (threadid, username, userid, title, dateline, pagetext, allowsmilie, visible, htmlstate) VALUES ('%d', '%s', '%d', '%s', '%d', '%s', '1', '1', 'on_nl2br');", g_szTablePrefix, g_iThreadID, g_szUserName, g_iSenderID, g_szPostTitle, g_iTimeStamp, g_szPostMessage);			
		case FORUM_MYBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sposts (tid, fid, subject, uid, username, dateline, message, visible) VALUES ('%d', '%d', '%s', '%d', '%s', '%d', '%s', '1');", g_szTablePrefix, g_iThreadID, g_iForumID, g_szPostTitle, g_iSenderID, g_szUserName, g_iTimeStamp, g_szPostMessage);			
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %smessages (id_topic, id_board, poster_time, id_member, subject, poster_name, poster_email, body, approved) VALUES ('%d', '%d', '%d', '%d', '%s', '%s', '%s', '%s', '1');", g_szTablePrefix, g_iThreadID, g_iForumID, g_iTimeStamp, g_iSenderID, g_szPostTitle, g_szUserName, g_szEmail, g_szPostMessage);			
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sposts (topic_id, forum_id, poster_id, post_username, post_time, enable_bbcode, post_subject, post_text, post_postcount, post_visibility) VALUES ('%d', '%d', '%d', '%s', '%d', '1', '%s', '%s', '1', '1');", g_szTablePrefix, g_iThreadID, g_iForumID, g_iSenderID, g_szUserName, g_iTimeStamp, g_szPostTitle, g_szPostMessage);
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %spost (threadID, userID, username, message, time, enableSmilies, enableBBCodes) VALUES ('%d', '%d', '%s', '%s', '%d', '0', '1');", g_szTablePrefix, g_iThreadID, g_iSenderID, g_szUserName, g_szPostMessage, g_iTimeStamp);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sposts (post_tid, post_fid, ptime, poster_id, post, use_smileys, p_approved) VALUES ('%d', '%d', '%d', '%d', '%s', '0', '1');", g_szTablePrefix, g_iThreadID, g_iForumID, g_iTimeStamp, g_iSenderID, g_szPostMessage);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sposts (topic_id, poster_id, content, post_time, enable_smilies) VALUES ('%d', '%d', '%s', '%d', '0');", g_szTablePrefix, g_iThreadID, g_iSenderID, g_szPostMessage, g_iTimeStamp);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sposts (fid, tid, author, message, subject, dateline, useip, bbcodeoff, smileyoff) VALUES ('%d', '%d', '%s', '%s', '%s', '%d', '%s', 'no', 'yes');", g_szTablePrefix, g_iForumID, g_iThreadID, g_szUserName, g_szPostMessage, g_szPostTitle, g_iTimeStamp);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %sposts (author_id, author_name, post_date, post, topic_id, new_topic) VALUES ('%d', '%s', '%d', '%s', '%d', '1');", g_szTablePrefix, g_iSenderID, g_szUserName, g_iTimeStamp, g_szPostMessage, g_iThreadID);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "INSERT INTO %spost (thread_id, user_id, username, post_date, message, message_state) VALUES ('%d', '%d', '%s', '%d', '%s', 'visible');", g_szTablePrefix, g_iThreadID, g_iSenderID, g_szUserName, g_iTimeStamp, g_szPostMessage);
	}
	
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant create post. Error: %s", g_Error)
        }

        // close the handle
        SQL_FreeHandle(Query)
}

/* Finds the Post ID for the thread we just created */
public GetPostId()
{
	new szSQLQuery[256];
	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT postid FROM %spost WHERE dateline='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT id_msg FROM %smessages WHERE poster_time='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT post_id FROM %sposts WHERE post_time='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT postID FROM %spost WHERE time='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT pid FROM %sposts WHERE ptime='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT id FROM %sposts WHERE post_time='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SLECT pid FROM %sposts WHERE dateline='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT pid FROM %sposts WHERE post_date='%d';", g_szTablePrefix, g_iTimeStamp);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT post_id FROM %spost WHERE post_date='%d';", g_szTablePrefix, g_iTimeStamp);
	}
	
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant get post ID. Error: %s", g_Error)
        }
	if(SQL_NumResults(Query))
	{
		g_iPostID =  SQL_ReadResult(Query, 0)
	}
	else g_iPostID = 1
	
        // close the handle
        SQL_FreeHandle(Query)
}

/* Sets the Post ID for the thread we just created */
public SetPostId()
{
	new szSQLQuery[256];
	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sthread SET firstpostid=%d, lastpostid=%d WHERE threadid=%d;", g_szTablePrefix, g_iPostID, g_iPostID, g_iThreadID);
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %stopics SET id_first_msg=%d, id_last_msg=%d WHERE id_topic=%d;", g_szTablePrefix, g_iPostID, g_iPostID, g_iThreadID);
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %stopics SET topic_first_post_id=%d, topic_last_post_id=%d WHERE topic_id=%d;", g_szTablePrefix, g_iPostID, g_iPostID, g_iThreadID);
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sthread SET firstPostID=%d WHERE threadID=%d;", g_szTablePrefix, g_iPostID, g_iThreadID);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %stopics SET first_post_id=%d, last_post_id=%d, mem_id_last_post=%d WHERE tid=%d;", g_szTablePrefix, g_iPostID, g_iPostID, g_iSenderID, g_iThreadID);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %stopics SET first_post_id=%d, last_post_id=%d WHERE id=%d;", g_szTablePrefix, g_iPostID, g_iPostID, g_iThreadID);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sthreads SET lastpost='%d|%s|%d' WHERE tid=%d;", g_szTablePrefix, g_iTimeStamp, g_szUserName, g_iPostID, g_iThreadID);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %stopics SET topic_firstpost='%d' WHERE last_post='%d';", g_szTablePrefix, g_iPostID, g_iTimeStamp);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sthread SET first_post_id='%d', last_post_date='%d', last_post_id='%s', last_post_user_id='%d', last_post_username='%s' WHERE thread_id='%d';", g_szTablePrefix, g_iPostID, g_iTimeStamp, g_iPostID, g_iSenderID, g_szUserName, g_iPostID);
	}
	
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant set Post ID. Error: %s", g_Error)
        }
        // close the handle
        SQL_FreeHandle(Query)
}

/* Gets the Current Post and Thread count for the specified thread */
public GetCurrentForumPostData()
{
	new szSQLQuery[256];
	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT replycount, threadcount FROM %sforum WHERE forumid='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_MYBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts, threads FROM %sforums WHERE fid='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT num_posts, num_topics FROM %sboards WHERE id_board='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT forum_posts_approved, forum_topics_approved FROM %sforums WHERE forum_id='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts, threads FROM %sboard WHERE boardID='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT nposts, ntopic FROM %sforums WHERE fid='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts, topics FROM %sforums WHERE id='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts, threads FROM %sforums WHERE fid='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts, topics FROM %sforums WHERE id='%d';", g_szTablePrefix, g_iForumID);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT message_count, discussion_count FROM %sforum WHERE node_id='%i';", g_szTablePrefix, g_iForumID);
	}
	
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant get post count. Error: %s", g_Error)
        }
	if(SQL_NumResults(Query))
	{
		g_iPostCount = SQL_ReadResult(Query, 0) + 1
		g_iThreadCount = SQL_ReadResult(Query, 1) + 1
	}
	else
	{
		g_iPostCount = 1
		g_iThreadCount = 1
	}
        // close the handle
        SQL_FreeHandle(Query)
}

/* Increase the Thread and Post count accordingly */
public UpdateForumPostCount(iPostCount, iThreadCount)
{
	new szSQLQuery[512];
	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sforum SET threadcount='%d', replycount='%d', lastpost='%d', lastposter='%s', lastposterid='%d', lastpostid='%d', lastthread='%s', lastthreadid='%d' WHERE forumid='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iTimeStamp, g_szUserName, g_iSenderID, g_iPostID, g_szPostTitle, g_iThreadID, g_iForumID);			
		case FORUM_MYBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sforums SET threads='%d', posts='%d', lastpost='%d', lastposter='%s', lastposteruid='%d', lastposttid='%d', lastpostsubject='%s' WHERE fid='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iTimeStamp, g_szUserName, g_iSenderID, g_iThreadID, g_szPostTitle, g_iForumID);			
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sboards SET num_topics='%d', num_posts='%d', id_last_msg='%d', id_msg_updated='%d' WHERE id_board='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iPostID, g_iPostID, g_iForumID);			
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sforums SET forum_topics_approved='%d', forum_posts_approved='%d', forum_last_post_id='%d', forum_last_post_subject='%s', forum_last_post_time='%d', forum_last_poster_id='%d', forum_last_poster_name='%s' WHERE forum_id='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iPostID, g_szPostTitle, g_iTimeStamp, g_iSenderID, g_szUserName, g_iForumID);			
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sboard SET threads='%d', posts='%d' WHERE boardID='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iForumID);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sforums SET ntopic='%d', nposts='%d', f_last_pid='%d' WHERE fid ='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iPostID, g_iForumID);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sforums SET topics='%d', posts='%d', last_topic_id='%d' WHERE id='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iThreadID, g_iForumID);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sforums SET lastpost='%d', posts='%d', threads='%d' WHERE fid='%d';", g_szTablePrefix, g_iTimeStamp, iPostCount, iThreadCount, g_iForumID);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sforums SET topics='%d', last_post='%d', last_poster_id='%d', last_poster_name='%s', last_title='%s', last_id='%d', newest_title='%s', newest_id='%d' WHERE id='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iTimeStamp, g_iSenderID, g_szUserName, g_szPostTitle, g_iPostID, g_szPostTitle, g_iPostID, g_iForumID);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %sforum SET discussion_count='%d', message_count='%d', last_post_id='%d', last_post_date='%d', last_post_user_id='%d', last_post_username='%s', last_thread_title='%s' WHERE node_id='%d';", g_szTablePrefix, iThreadCount, iPostCount, g_iPostID, g_iTimeStamp, g_iSenderID, g_szUserName, g_szPostTitle, g_iForumID);
	}
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant set post count. Error: %s", g_Error)
        }
        // close the handle
        SQL_FreeHandle(Query)
}

/* Get the Users post count */
public GetUserPostInfo()
{
	new szSQLQuery[256];
	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts FROM %suser WHERE userid='%d';", g_szTablePrefix, g_iSenderID)
		case FORUM_MYBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT postnum FROM %susers WHERE uid='%d';", g_szTablePrefix, g_iSenderID);
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts FROM %smembers WHERE id_member='%d';", g_szTablePrefix, g_iSenderID);
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT user_posts FROM %susers WHERE user_id='%d';", g_szTablePrefix, g_iSenderID);
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts FROM %suser WHERE userID='%d';", g_szTablePrefix, g_iSenderID);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts FROM %susers WHERE id='%d';", g_szTablePrefix, g_iSenderID);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts FROM %smembers WHERE id='%d';", g_szTablePrefix, g_iSenderID);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT postnum FROM %smembers WHERE uid='%d';", g_szTablePrefix, g_iSenderID);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT posts FROM %smembers WHERE member_id='%d';", g_szTablePrefix, g_iSenderID);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "SELECT message_count FROM %suser WHERE user_id='%d';", g_szTablePrefix, g_iSenderID);
	}
	
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant get user message count. Error: %s", g_Error)
        }
	
	if(SQL_NumResults(Query))
	{
		g_iUserPostCount = SQL_ReadResult(Query, 0) + 1
	}
	else g_iUserPostCount = 1
	
        // close the handle
        SQL_FreeHandle(Query)
}

/* Increase the users post count accordingly */
public UpdateUserPostCount(iPostCount)
{
	new szSQLQuery[512];

	switch(g_iForumSoftwareID)
	{
		case FORUM_VB4:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %suser SET posts='%d', lastvisit='%d', lastactivity='%d', lastpost='%d', lastpostid='%d' WHERE userid=%d;", g_szTablePrefix, iPostCount, g_iTimeStamp, g_iTimeStamp, g_iTimeStamp, g_iPostID, g_iSenderID);
		case FORUM_MYBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %susers SET postnum='%d' WHERE uid='%d';", g_szTablePrefix, iPostCount, g_iSenderID);
		case FORUM_SMF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %smembers SET posts='%d', last_login='%d' WHERE id_member=%d;", g_szTablePrefix, iPostCount, g_iTimeStamp, g_iSenderID);
		case FORUM_PHPBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %susers SET user_posts='%d', user_lastpost_time='%d' WHERE user_id=%d;", g_szTablePrefix, iPostCount, g_iTimeStamp, g_iSenderID);			
		case FORUM_WBBLITE:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %suser SET posts='%d', boardLastVisitTime='%d', boardLastActivityTime='%d' WHERE userID=%d;", g_szTablePrefix, iPostCount, g_iTimeStamp, g_iTimeStamp, g_iSenderID);
		case FORUM_AEF:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %susers SET lastlogin='%d', lastlogin_1='%d', posts='%d' WHERE id=%d;", g_szTablePrefix, g_iTimeStamp, g_iTimeStamp, iPostCount, g_iSenderID);
		case FORUM_USEBB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %smembers SET last_login='%d', last_pageview='%d', posts='%d' WHERE id=%d;", g_szTablePrefix, g_iTimeStamp, g_iTimeStamp, iPostCount, g_iSenderID);
		case FORUM_XMB:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %smembers SET postnum='%d', lastvisit='%d';", g_szTablePrefix, iPostCount, g_iTimeStamp);
		case FORUM_IPBOARDS:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %smembers SET posts='%d', last_post='%d', last_visit='%d', last_activity='%d' WHERE member_id=%d;", g_szTablePrefix, iPostCount, g_iTimeStamp, g_iTimeStamp, g_iTimeStamp, g_iSenderID);
		case FORUM_XENFORO:
			formatex(szSQLQuery, charsmax(szSQLQuery), "UPDATE %suser SET message_count='%d', last_activity='%d' WHERE user_id = '%d';", g_szTablePrefix, iPostCount, g_iTimeStamp, g_iSenderID);
	}
		
	new Handle:Query = SQL_PrepareQuery(SqlConnection, szSQLQuery);
	if(!SQL_Execute(Query))
        {
            // if there were any problems
            SQL_QueryError(Query,g_Error,511)
            log_amx("[RTF] Cant set user message count. Error: %s", g_Error)
        }
	
        // close the handle
        SQL_FreeHandle(Query)
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
	
	return 1
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
