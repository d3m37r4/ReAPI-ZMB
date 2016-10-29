#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

#pragma semicolon				1

#define PLUGIN_NAME				"[ZMB] Core"
#define PLUGIN_VERS				"0.0.3a"
#define PLUGIN_AUTH				"81x08"

#define SetBit(%0,%1)			((%0) |= (1 << (%1 - 1)))
#define ClearBit(%0,%1)			((%0) &= ~(1 << (%1 - 1)))
#define IsSetBit(%0,%1)			((%0) & (1 << (%1 - 1)))
#define InvertBit(%0,%1)		((%0) ^= (1 << (%1 - 1)))
#define IsNotSetBit(%0,%1)		(~(%0) & (1 << (%1 - 1)))

#define IsPlayer(%0)			(%0 && %0 <= g_iMaxPlayers)

#define MAX_PLAYERS				32
#define MAX_CLASSES				10

#define FOG_COLOR				"128 128 128"
#define FOG_DENSITY				"0.0012"

#define CLASS_NONE				0

const MsgId_TextMsg				= 77;
const MsgId_SendAudio			= 100;
const MsgId_ScreenFade			= 98;

enum (+= 35)	{
	TASK_ID_INFECT,
	TASK_ID_LIGTH_STYLE,
	
	TASK_ID_PLAYER_HUD
};

enum Color	{
	COLOR_RED,
	COLOR_GREEN,
	COLOR_BLUE
};

enum Positon	{
	Float: POS_X,
	Float: POS_Y
};

enum infoClass	{
	CLASS_NAME[64],
	CLASS_KNIFE_MODEL[64],
	CLASS_PLAYER_MODEL[64],
	
	Float: CLASS_SPEED,
	Float: CLASS_HEALTH,
	Float: CLASS_GRAVITY,
	Float: CLASS_FACTOR_DMG
};

enum playerEquipment	{
	PLAYER_EQUIPMENT_PRIMARY,
	PLAYER_EQUIPMENT_SECONDARY
};

enum listWeaponInfo	{
	WEAPON_NAME[12],
	WEAPON_CLASSNAME[16],
	WeaponIdType: WEAPON_ID,
	WEAPON_BPAMMO
};

enum _: bitsPlayer	{
	BIT_NONE,
	
	BIT_INFECT,
	BIT_CONNECTED,
	BIT_MENU_EQUIPMENT,
	
	BIT_MAX
};

new const g_listPrimaryWeaponszMenu[][listWeaponInfo] =	{
	{},
	
	{"M4A1", "weapon_m4a1", WEAPON_M4A1, 90},
	{"AK47", "weapon_ak47", WEAPON_AK47, 90},
	{"AWP", "weapon_awp", WEAPON_AWP, 30}
};

new const g_listSecondaryWeaponszMenu[][listWeaponInfo] =	{
	{},
	
	{"USP", "weapon_usp", WEAPON_USP, 120},
	{"Deagle", "weapon_deagle", WEAPON_DEAGLE, 30},
	{"Glock 18", "weapon_glock18", WEAPON_GLOCK18, 120}
};

new const g_listGrenades[] =	{
	"weapon_hegrenade",
	"weapon_flashbang",
	"weapon_flashbang",
	"weapon_smokegrenade"
};

new g_iFakeMetaFwd_Spawn;

new Ham: g_iHamFwd_Player_Speed = Ham_Item_PreFrame;

new HamHook: g_iHamFwd_Entity_Block[13];

new g_iCvar_HudType,
	g_iCvar_HudColor[Color],
	Float: g_fCvar_HudPosition[Positon];
	
new g_iCvar_ZombieRatio,
	g_iCvar_SaveEquipment,
	g_iCvar_TimeInfections;

new g_szCvar_MapLightStyle[2],
	g_szCvar_GameDescription[64];
	
new g_iMaxPlayers,
	g_iZombieClasses;
	
new g_iSyncPlayerHud;

new g_iSizeSoundsSurvirvorWin;

new g_iSizeSoundsZombieDie,
	g_iSizeSoundsZombieWin,
	g_iSizeSoundsZombieScream,
	g_iSizeSoundsZombieKnifeMiss,
	g_iSizeSoundsZombieKnifeHits;

new g_iPrimaryWeapons,
	g_iSecondaryWeapons;

new g_infoZombieClass[MAX_CLASSES][infoClass];

new bool: g_bRoundEnd,
	bool: g_bInfectionBegan;

new gp_iBit[bitsPlayer],
	gp_iClass[MAX_PLAYERS + 1],
	gp_iSelectedClass[MAX_PLAYERS + 1],
	gp_iEquipment[MAX_PLAYERS + 1][playerEquipment];
	
new gp_iMenuPosition[MAX_PLAYERS + 1];

new gp_szSteamId[MAX_PLAYERS + 1][35];

new	Trie: g_tEquipment,
	Trie: g_tRemoveEntities;

new Array: g_aSoundsSurvirvorWin;

new Array: g_aSoundsZombieDie,
	Array: g_aSoundsZombieWin,
	Array: g_aSoundsZombieScream,
	Array: g_aSoundsZombieKnifeMiss,
	Array: g_aSoundsZombieKnifeHits;

/*================================================================================
 [PLUGIN]
=================================================================================*/
public plugin_precache()	{
	LoadSounds();
	LoadClasses();

	FakeMeta_EnvFog();
	FakeMeta_RemoveEntities();
}

public plugin_init()	{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	Event_Init();
	Message_Init();
	
	ReAPI_Init();
	FakeMeta_Init();
	Hamsandwich_Init();

	ClCmd_Init();
	MenuCmd_Init();

	g_iMaxPlayers = get_maxplayers();
	
	g_iSyncPlayerHud = CreateHudSyncObj();
	
	g_iPrimaryWeapons = sizeof(g_listPrimaryWeaponszMenu);
	g_iSecondaryWeapons = sizeof(g_listSecondaryWeaponszMenu);
}

public plugin_cfg()	{
 	set_cvar_string("mp_refill_bpammo_weapons",	"2");
	set_cvar_string("humans_join_team",	"any");
	set_cvar_string("mp_auto_join_team","1");
	set_cvar_string("sv_skyname", "drkg");
	
	Cvars_Cfg();
}

/*================================================================================
 [PRECACHE]
=================================================================================*/
LoadSounds()	{
	new szFileDir[128];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	
	formatex(szFileDir, charsmax(szFileDir), "%s/zmb/zmb_sounds.ini", szFileDir);

	switch(file_exists(szFileDir))
	{
		case 0:
		{
			UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szFileDir);
		}
		case 1:
		{
			ReadFile_Sounds(szFileDir);
		}
	}
}

ReadFile_Sounds(const szFileDir[])	{
	new iFile = fopen(szFileDir, "rt");
	
	if(iFile)
	{
		new iStrLen;
		new szBuffer[128], szBlock[32];

		while(!(feof(iFile)))
		{
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
				continue;
			
			iStrLen = strlen(szBuffer);
			
			if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']')
			{
				copyc(szBlock, charsmax(szBlock), szBuffer[1], szBuffer[iStrLen - 1]);

				continue;
			}
			
			if(szBlock[0])
			{
				remove_quotes(szBuffer);

				new szPrecache[64];
				formatex(szPrecache, charsmax(szPrecache), "sound/%s", szBuffer);
				
				switch(file_exists(szPrecache))
				{
					case 0:
					{
						UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szPrecache);
					}
					case 1:
					{
						switch(szBlock[0])
						{
							case 's':	/* [Survirvor win] */
							{
								if(equali(szBlock, "survirvor_win", 13))
								{
									if(g_aSoundsSurvirvorWin || (g_aSoundsSurvirvorWin = ArrayCreate(64)))
									{
										precache_sound(szBuffer);
										
										ArrayPushString(g_aSoundsSurvirvorWin, szBuffer);
									}
								}
							}
							case 'z':
							{
								/* [Zombie win] */
								if(equali(szBlock, "zombie_win", 10))
								{
									if(g_aSoundsZombieWin || (g_aSoundsZombieWin = ArrayCreate(64)))
									{
										precache_sound(szBuffer);
										
										ArrayPushString(g_aSoundsZombieWin, szBuffer);
									}
									
									continue;
								}
								
								/* [Zombie death] */
								if(equali(szBlock, "zombie_death", 12))
								{
									if(g_aSoundsZombieDie || (g_aSoundsZombieDie = ArrayCreate(64)))
									{
										precache_sound(szBuffer);

										ArrayPushString(g_aSoundsZombieDie, szBuffer);
									}
									
									continue;
								}
								
								/* [Zombie scream] */
								if(equali(szBlock, "zombie_scream", 13))
								{
									if(g_aSoundsZombieScream || (g_aSoundsZombieScream = ArrayCreate(64)))
									{
										precache_sound(szBuffer);

										ArrayPushString(g_aSoundsZombieScream, szBuffer);
									}
								}
								
								/* [Zombie knife miss] */
								if(equali(szBlock, "zombie_knife_miss", 17))
								{
									if(g_aSoundsZombieKnifeMiss || (g_aSoundsZombieKnifeMiss = ArrayCreate(64)))
									{
										precache_sound(szBuffer);

										ArrayPushString(g_aSoundsZombieKnifeMiss, szBuffer);
									}
								}
								
								/* [Zombie knife hits] */
								if(equali(szBlock, "zombie_knife_hits", 17))
								{
									if(g_aSoundsZombieKnifeHits || (g_aSoundsZombieKnifeHits = ArrayCreate(64)))
									{
										precache_sound(szBuffer);

										ArrayPushString(g_aSoundsZombieKnifeHits, szBuffer);
									}
								}
							}
						}
					}
				}
			}
		}
		
		fclose(iFile);
		
		if(g_aSoundsSurvirvorWin)
		{
			g_iSizeSoundsSurvirvorWin = ArraySize(g_aSoundsSurvirvorWin);
		}
		
		if(g_aSoundsZombieWin)
		{
			g_iSizeSoundsZombieWin = ArraySize(g_aSoundsZombieWin);
		}

		if(g_aSoundsZombieDie)
		{
			g_iSizeSoundsZombieDie = ArraySize(g_aSoundsZombieDie);
		}
		
		if(g_aSoundsZombieScream)
		{
			g_iSizeSoundsZombieScream = ArraySize(g_aSoundsZombieScream);
		}
		
		if(g_aSoundsZombieKnifeMiss)
		{
			g_iSizeSoundsZombieKnifeMiss = ArraySize(g_aSoundsZombieKnifeMiss);
		}
		
		if(g_aSoundsZombieKnifeHits)
		{
			g_iSizeSoundsZombieKnifeHits = ArraySize(g_aSoundsZombieKnifeHits);
		}
	}
}

LoadClasses()	{
	new szFileDir[128];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	
	formatex(szFileDir, charsmax(szFileDir), "%s/zmb/zmb_classes.ini", szFileDir);

	switch(file_exists(szFileDir))
	{
		case 0:
		{
			UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szFileDir);
		}
		case 1:
		{
			ReadFile_Classes(szFileDir);
		}
	}
}

ReadFile_Classes(const szFileDir[])	{
	new iFile = fopen(szFileDir, "rt");
	
	if(iFile)
	{
		new iStrLen;
		new szBuffer[128], szKey[32], szValue[64];
		
		new infoZombieClass[infoClass];
		
		while(!(feof(iFile)))
		{
			fgets(iFile, szBuffer, charsmax(szBuffer));
			trim(szBuffer);

			if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
				continue;
			
			iStrLen = strlen(szBuffer);
			
			if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']')
			{
				new szName[64];
				copyc(szName, charsmax(szName), szBuffer[1], szBuffer[iStrLen - 1]);

				if(equali(szName, "end", 3) || equali(szName, "конец", 5))
				{
					addZombieClass(
						infoZombieClass[CLASS_NAME],
						infoZombieClass[CLASS_KNIFE_MODEL],
						infoZombieClass[CLASS_PLAYER_MODEL],
						infoZombieClass[CLASS_SPEED],
						infoZombieClass[CLASS_HEALTH],
						infoZombieClass[CLASS_GRAVITY],
						infoZombieClass[CLASS_FACTOR_DMG]
					);
					
					arrayset(infoZombieClass, 0, sizeof(infoZombieClass));
				}
				else
				{
					infoZombieClass[CLASS_NAME] = szName;
				}
				
				continue;
			}

			if(infoZombieClass[CLASS_NAME])
			{
				strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
				
				trim(szKey);
				trim(szValue);
				
				remove_quotes(szKey);
				remove_quotes(szValue);
				
				switch(szKey[0])
				{
					case 'k':	/* [Knife model] */
					{
						if(equali(szKey, "knife_model", 11))
						{
							switch(file_exists(szValue))
							{
								case 0:
								{
									UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szValue);
								}
								case 1:
								{
									precache_model(szValue);
									
									infoZombieClass[CLASS_KNIFE_MODEL] = szValue;
								}
							}
						}
					}
					case 'p':	/* [Player model] */
					{
						if(equali(szKey, "player_model", 12))
						{
							new szPrecache[64];
							formatex(szPrecache, charsmax(szPrecache), "models/player/%s/%s.mdl", szValue, szValue);
							
							switch(file_exists(szPrecache))
							{
								case 0:
								{
									UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szPrecache);
								}
								case 1:
								{
									precache_model(szPrecache);
									
									infoZombieClass[CLASS_PLAYER_MODEL] = szValue;
								}
							}
						}
					}
					case 's':	/* [Speed] */
					{
						if(equali(szKey, "speed", 5))
						{
							infoZombieClass[CLASS_SPEED] = _: str_to_float(szValue);
						}
					}
					case 'h':	/* [Health] */
					{
						if(equali(szKey, "health", 6))
						{
							infoZombieClass[CLASS_HEALTH] = _: str_to_float(szValue);
						}
					}
					case 'g':	/* [Gravity] */
					{
						if(equali(szKey, "gravity", 7))
						{
							infoZombieClass[CLASS_GRAVITY] = _: str_to_float(szValue);
						}
					}
					case 'f':	/* [Factro damage] */
					{
						if(equali(szKey, "factor_damage", 13))
						{
							infoZombieClass[CLASS_FACTOR_DMG] = _: str_to_float(szValue);
						}
					}
				}
			}
		}

		fclose(iFile);
	}
}

/*================================================================================
 [CVARS]
=================================================================================*/
Cvars_Cfg()	{
	new iCvarId_HudType,
		iCvarId_HudColor,
		iCvarId_HudPosition,
		iCvarId_ZombieRatio,
		iCvarId_MapLightStyle,
		iCvarId_SaveEquipment,
		iCvarId_TimeInfections,
		iCvarId_GameDescription;

	iCvarId_HudType			= register_cvar("zmb_hud_type", "0");
	iCvarId_HudColor		= register_cvar("zmb_hud_color", "#008000");
	iCvarId_HudPosition		= register_cvar("zmb_hud_position", "-1.0 0.85");
	iCvarId_ZombieRatio		= register_cvar("zmb_zombie_ratio", "2");
	iCvarId_MapLightStyle	= register_cvar("zmb_map_lightstyle", "d");
	iCvarId_SaveEquipment	= register_cvar("zmb_save_equipment", "0");
	iCvarId_TimeInfections	= register_cvar("zmb_time_infections", "15");
	iCvarId_GameDescription	= register_cvar("zmb_game_description", "[ZMB] by 81x08");

 	new szFileDir[128];
	get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
	
	formatex(szFileDir, charsmax(szFileDir), "%s/zmb/zmb_core.cfg", szFileDir);
	
	switch(file_exists(szFileDir))
	{
		case 0:
		{
			UTIL_SetFileState("Core", "~ [WARNING] Файл ^"%s^" не найден.", szFileDir);
		}
		case 1:
		{
			server_cmd("exec %s", szFileDir);
		}
	}

	g_iCvar_HudType					= get_pcvar_num(iCvarId_HudType);
	
	new szColor[8];
	get_pcvar_string(iCvarId_HudColor, szColor, charsmax(szColor));

	g_iCvar_HudColor = UTIL_ParseHEXColor(szColor);

	new szPosition[Positon][8], szCvarPosition[16];
	get_pcvar_string(iCvarId_HudPosition, szCvarPosition, charsmax(szCvarPosition));
	parse(szCvarPosition, szPosition[POS_X], charsmax(szPosition[]), szPosition[POS_Y], charsmax(szPosition[]));
	
	g_fCvar_HudPosition[POS_X] 		= str_to_float(szPosition[POS_X]);
	g_fCvar_HudPosition[POS_Y] 		= str_to_float(szPosition[POS_Y]);
	
	g_iCvar_ZombieRatio				= get_pcvar_num(iCvarId_ZombieRatio);
	g_iCvar_SaveEquipment			= get_pcvar_num(iCvarId_SaveEquipment);
	g_iCvar_TimeInfections			= get_pcvar_num(iCvarId_TimeInfections);
	
	get_pcvar_string(iCvarId_MapLightStyle, g_szCvar_MapLightStyle, charsmax(g_szCvar_MapLightStyle));
	get_pcvar_string(iCvarId_GameDescription, g_szCvar_GameDescription, charsmax(g_szCvar_GameDescription));

	if(g_iCvar_SaveEquipment)
	{
		g_tEquipment = TrieCreate();
	}
	
	if(g_szCvar_GameDescription[0])
	{
		set_member_game(m_GameDesc, g_szCvar_GameDescription);
	}
}

/*================================================================================
 [CLIENT]
=================================================================================*/
public client_putinserver(iIndex)	{
	if(is_user_bot(iIndex) || is_user_hltv(iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	SetBit(gp_iBit[BIT_CONNECTED], iIndex);
	SetBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex);
	
	gp_iClass[iIndex] = random_num(1, g_iZombieClasses);
	gp_iSelectedClass[iIndex] = CLASS_NONE;
	
	if(g_iCvar_SaveEquipment)
	{
		get_user_authid(iIndex, gp_szSteamId[iIndex], charsmax(gp_szSteamId[]));
		
		if(TrieKeyExists(g_tEquipment, gp_szSteamId[iIndex]))
		{
			TrieGetArray(g_tEquipment, gp_szSteamId[iIndex], gp_iEquipment[iIndex], sizeof(gp_iEquipment[][]));

			TrieDeleteKey(g_tEquipment, gp_szSteamId[iIndex]);
		}
	}
	
	return PLUGIN_CONTINUE;
}

public client_disconnect(iIndex)	{
	if(IsNotSetBit(gp_iBit[BIT_CONNECTED], iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		remove_task(TASK_ID_PLAYER_HUD + iIndex);
	}
	
	for(new iCount = BIT_NONE; iCount < BIT_MAX; iCount++)
	{
		ClearBit(gp_iBit[iCount], iIndex);
	}

	switch(g_iCvar_SaveEquipment)
	{
		case 0:
		{
			gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY] = 0;
			gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY] = 0;
		}
		case 1:
		{
			TrieSetArray(g_tEquipment, gp_szSteamId[iIndex], gp_iEquipment[iIndex], sizeof(gp_iEquipment[][]));
		}
	}
	
	return PLUGIN_CONTINUE;
}

/*================================================================================
 [EVENT]
=================================================================================*/
Event_Init()	{
	register_event("InitHUD", "EventHook_InitHUD", "b");
	register_event("HLTV", "EventHook_HLTV", "a", "1=0", "2=0");
	
	register_logevent("LogEventHook_RoundEnd",		2,	"1=Round_End");
	register_logevent("LogEventHook_RoundStart",	2,	"1=Round_Start");
	register_logevent("LogEventHook_RestartGame",	2,	"1=Game_Commencing", "1&Restart_Round_");
}

public EventHook_InitHUD(const iIndex)	{
	message_begin(MSG_ONE, SVC_LIGHTSTYLE, {0, 0, 0}, iIndex);
	{
		write_byte(0);
		write_string(g_szCvar_MapLightStyle);
	}
	message_end();
}

public EventHook_HLTV()	{
	g_bRoundEnd = false;
	
	rg_balance_teams();
	
	for(new iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)
	{
		if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			ClearBit(gp_iBit[BIT_INFECT], iIndex);
			
			remove_task(TASK_ID_PLAYER_HUD + iIndex);
			
			rg_reset_user_model(iIndex);
		}
	}

	set_task(float(g_iCvar_TimeInfections), "taskInfect", TASK_ID_INFECT);
}

public LogEventHook_RoundStart()	{
}

public LogEventHook_RoundEnd()	{
	g_bRoundEnd = true;
	g_bInfectionBegan = false;
	
	remove_task(TASK_ID_INFECT);
}

public LogEventHook_RestartGame()	{
	LogEventHook_RoundEnd();
}

/*================================================================================
 [MESSAGE]
=================================================================================*/
Message_Init()	{
	/* register_message(MsgId_TextMsg, "MessageHook_TextMsg"); */
	register_message(MsgId_SendAudio, "MessageHook_SendAudio");
}

public MessageHook_TextMsg()	{
	new szArg[32];
	get_msg_arg_string(2, szArg, charsmax(szArg));

	return PLUGIN_CONTINUE;
}

public MessageHook_SendAudio()	{
	new szArg[14], szSoundWin[64];
	get_msg_arg_string(2, szArg, charsmax(szArg));

	switch(szArg[7])
	{
		case 't':
		{
			if(equal(szArg[7], "terwin", 6))
			{
				ArrayGetString(g_aSoundsZombieWin, random(g_iSizeSoundsZombieWin), szSoundWin, charsmax(szSoundWin));
				
				set_msg_arg_string(2, szSoundWin);
			}
		}
		case 'c':
		{
			if(equal(szArg[7], "ctwin", 5))
			{
				ArrayGetString(g_aSoundsSurvirvorWin, random(g_iSizeSoundsSurvirvorWin), szSoundWin, charsmax(szSoundWin));
				
				set_msg_arg_string(2, szSoundWin);
			}
		}
	}

	return PLUGIN_CONTINUE;
}

/*================================================================================
 [ReAPI]
=================================================================================*/
ReAPI_Init()	{
	RegisterHookChain(RG_ShowVGUIMenu, "HC_ShowVGUIMenu_Pre", false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "HC_CBasePlayer_Spawn_Post", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "HC_CBasePlayer_Killed_Post", true);
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "HC_CBasePlayer_TraceAttack_Pre", false);
}

public HC_ShowVGUIMenu_Pre(const iIndex, const VGUIMenu: iMenuType)	{
	if(iMenuType == VGUI_Menu_Team)
	{
		ShowMenu_Main(iIndex);
	}
	
	SetHookChainReturn(ATYPE_INTEGER, 0);

	return HC_SUPERCEDE;
}

public HC_CBasePlayer_Spawn_Post(const iIndex)	{
	if(is_user_alive(iIndex))
	{
		if(IsSetBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex))
		{
			ShowMenu_Equipment(iIndex);
		}
		else
		{
			new iPrimaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY];
			new iSecondaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY];
			
			givePlayerPrimaryWeapon(iIndex, iPrimaryWeaponId);
			givePlayerSecondaryWeapon(iIndex, iSecondaryWeaponId);
			givePlayerGrenades(iIndex);
		}
		
		if(gp_iSelectedClass[iIndex] != CLASS_NONE)
		{
			gp_iClass[iIndex] = gp_iSelectedClass[iIndex];
			
			gp_iSelectedClass[iIndex] = 0;
		}
	}
}

public HC_CBasePlayer_Killed_Post(const iVictim, const iAttacker)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iVictim))
	{
		remove_task(TASK_ID_PLAYER_HUD + iVictim);
	}
}

public HC_CBasePlayer_TraceAttack_Pre(const iVictim, const iAttacker, Float: fDamage)	{
	if(!(g_bInfectionBegan))
	{
		return HC_CONTINUE;
	}
	
	if(IsSetBit(gp_iBit[BIT_INFECT], iAttacker))
	{
		if(g_bRoundEnd)
		{
			SetHookChainReturn(ATYPE_INTEGER, 0);
			
			return HC_SUPERCEDE;
		}
		
		fDamage *= g_infoZombieClass[gp_iClass[iAttacker]][CLASS_FACTOR_DMG];

		SetHookChainArg(3, ATYPE_FLOAT, fDamage);
	}
	
	return HC_CONTINUE;
}

/*================================================================================
 [FakeMeta]
=================================================================================*/
FakeMeta_Init()	{
	unregister_forward(FM_Spawn, g_iFakeMetaFwd_Spawn, true);
	
	register_forward(FM_EmitSound, "FMHook_EmitSound_Pre", false);
}

FakeMeta_EnvFog()	{
	new iEnt = rg_create_entity("env_fog");
	
	if(iEnt)
	{
		UTIL_SetKvd(iEnt, "env_fog", "density", FOG_DENSITY);
		UTIL_SetKvd(iEnt, "env_fog", "rendercolor", FOG_COLOR);
	}
}

FakeMeta_RemoveEntities()	{
	new const szRemoveEntities[][] =
	{
		"func_hostage_rescue",
		"info_hostage_rescue",
		"func_bomb_target",
		"info_bomb_target",
		"func_vip_safetyzone",
		"info_vip_start",
		"func_escapezone",
		"hostage_entity",
		"monster_scientist",
		"func_buyzone"
	};

	g_tRemoveEntities = TrieCreate();

	for(new iCount = 0; iCount < sizeof(szRemoveEntities); iCount++)
	{
		TrieSetCell(g_tRemoveEntities, szRemoveEntities[iCount], iCount);
	}
	
	rg_create_entity("func_buyzone");

	g_iFakeMetaFwd_Spawn = register_forward(FM_Spawn, "FakeMetaHook_Spawn_Post", true);
}

public FakeMetaHook_Spawn_Post(const iEnt)	{
	if(!(is_entity(iEnt)))
	{
		return FMRES_IGNORED;
	}
	
	static szClassName[20];
	get_entvar(iEnt, var_classname, szClassName, charsmax(szClassName));
	
	if(TrieKeyExists(g_tRemoveEntities, szClassName))
	{
		set_entvar(iEnt, var_flags, get_entvar(iEnt, var_flags) | FL_KILLME);
		
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public FMHook_EmitSound_Pre(const iIndex, const iChannel, const szSample[], const Float: fVolume, const Float: fAttn, const iFlag, const iPitch)	{
	if(IsPlayer(iIndex))
	{
		if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			new szSound[64];

			if(szSample[8] == 'k' && szSample[9] == 'n' && szSample[10] == 'i')
			{
				/* [Knife slash] */
				if(szSample[14] == 's' && szSample[15] == 'l' && szSample[16] == 'a')
				{
					ArrayGetString(g_aSoundsZombieKnifeMiss, random(g_iSizeSoundsZombieKnifeMiss), szSound, charsmax(szSound));
			
					emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
					
					return FMRES_SUPERCEDE;
				}
				
				/* [Knife [hit|stab] */
				if((szSample[14] == 'h' && szSample[15] == 'i' && szSample[16] == 't') || (szSample[14] == 's' && szSample[15] == 't' && szSample[16] == 'a'))
				{
					/* [Wall] */
					if(szSample[17] == 'w' && szSample[18] == 'a' && szSample[19] == 'l')
					{
						ArrayGetString(g_aSoundsZombieKnifeMiss, random(g_iSizeSoundsZombieKnifeMiss), szSound, charsmax(szSound));
			
						emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
					}
					else
					{
						ArrayGetString(g_aSoundsZombieKnifeHits, random(g_iSizeSoundsZombieKnifeHits), szSound, charsmax(szSound));
			
						emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
					}

					return FMRES_SUPERCEDE;
				}
			}
			
			if(szSample[7] == 'd' && szSample[8] == 'i' && szSample[9] == 'e')
			{
				ArrayGetString(g_aSoundsZombieDie, random(g_iSizeSoundsZombieDie), szSound, charsmax(szSound));
			
				emit_sound(iIndex, iChannel, szSound, fVolume, fAttn, iFlag, iPitch);
				
				return FMRES_SUPERCEDE;
			}
		}
	}
	
	return FMRES_IGNORED;
}

/*================================================================================
 [Hamsandwich]
=================================================================================*/
Hamsandwich_Init()	{
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "HamHook_Knife_Deploy_Post", true);
	RegisterHam(g_iHamFwd_Player_Speed, "player", "HamHook_Player_MaxSpeed_Post", true);
	
	new const szEntityClass[][] =
	{
		"func_vehicle", 		// Управляемая машина
		"func_tracktrain", 		// Управляемый поезд
		"func_tank", 			// Управляемая пушка
		"game_player_hurt",	 	// При активации наносит игроку повреждения
		"func_recharge", 		// Увеличение запаса бронижелета
		"func_healthcharger", 	// Увеличение процентов здоровья
		"game_player_equip", 	// Выдаёт оружие
		"player_weaponstrip", 	// Забирает всё оружие
		"trigger_hurt", 		// Наносит игроку повреждения
		"trigger_gravity", 		// Устанавливает игроку силу гравитации
		"armoury_entity", 		// Объект лежащий на карте, оружия, броня или гранаты
		"weaponbox", 			// Оружие выброшенное игроком
		"weapon_shield" 		// Щит
	};
	
	new iCount;
	
	for(iCount = 0; iCount <= 7; iCount++)
	{
		DisableHamForward(
			g_iHamFwd_Entity_Block[iCount] = RegisterHam(
				Ham_Use, szEntityClass[iCount], "HamHook_EntityBlock_Pre", false
			)
		);
	}
	
	for(iCount = 8; iCount <= 12; iCount++)
	{
		DisableHamForward(
			g_iHamFwd_Entity_Block[iCount] = RegisterHam(
				Ham_Touch, szEntityClass[iCount], "HamHook_EntityBlock_Pre", false
			)
		);
	}
}

public HamHook_Knife_Deploy_Post(const iEntity)	{
	new iIndex = get_member(iEntity, m_pPlayer);

	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		if(g_infoZombieClass[gp_iClass[iIndex]][CLASS_KNIFE_MODEL])
		{
			static sViewModel;
			
			if(sViewModel || (sViewModel = engfunc(EngFunc_AllocString, g_infoZombieClass[gp_iClass[iIndex]][CLASS_KNIFE_MODEL])))
			{
				set_pev_string(iIndex, pev_viewmodel2, sViewModel);
			}
			
			set_pev(iIndex, pev_weaponmodel2, "");
		}
	}
	
	return HAM_IGNORED;
}

public HamHook_Player_MaxSpeed_Post(iIndex)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		if(g_infoZombieClass[gp_iClass[iIndex]][CLASS_SPEED])
		{
			set_entvar(iIndex, var_maxspeed, g_infoZombieClass[gp_iClass[iIndex]][CLASS_SPEED]);
		}
	}
}

public HamHook_EntityBlock_Pre(const iEntity, const iIndex)	{
	if(IsPlayer(iIndex))
	{
		if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

/*================================================================================
 [ClCmd]
=================================================================================*/
ClCmd_Init()	{
	register_clcmd("drop", "ClCmd_Drop");
	
	register_clcmd("say /equip", "ClCmd_Equipment");
	
	register_clcmd("jointeam", "ClCmd_Block");
	register_clcmd("joinclass", "ClCmd_Block");
}

public ClCmd_Drop(const iIndex)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		if(get_user_weapon(iIndex) == CSW_KNIFE)
		{
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE;
}

public ClCmd_Equipment(const iIndex)	{
	SetBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex);
	
	return PLUGIN_HANDLED;
}

public ClCmd_Block()	{
	return PLUGIN_HANDLED;
}

/*================================================================================
 [MenuCmd]
=================================================================================*/
MenuCmd_Init()	{
	register_menucmd(register_menuid("ShowMenu_Main"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0, "Handler_Main");
	register_menucmd(register_menuid("ShowMenu_Equipment"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0, "Handler_Equipment");
	register_menucmd(register_menuid("ShowMenu_ChooseClass"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "Handler_ChooseClass");
	register_menucmd(register_menuid("ShowMenu_PrimaryWeapons"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "Handler_PrimaryWeapons");
	register_menucmd(register_menuid("ShowMenu_SecondaryWeapons"), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, "Handler_SecondaryWeapons");
}

ShowMenu_Main(const iIndex)	{
	static szMenu[512]; new iBitKeys = MENU_KEY_1|MENU_KEY_3|MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wГлавное меню^n^n");

	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[1] \wВыбрать класс^n^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[2] \dМагазин^n");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[3] \wМеню обмундирования \r[ \y%s \r]^n^n^n^n^n^n^n", IsSetBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex) ? "ON" : "OFF");
	
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[0] \wВыход");
	
	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_Main");
}

public Handler_Main(const iIndex, const iKey)	{
	switch(iKey)
	{
		case 0:
		{
			return ShowMenu_ChooseClass(iIndex, gp_iMenuPosition[iIndex] = 0);
		}
		case 2:
		{
			InvertBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex);
			
			return ShowMenu_Main(iIndex);
		}
	}
	
	return PLUGIN_HANDLED;
}

ShowMenu_ChooseClass(const iIndex, const iPos)	{
	if(iPos < 0)
	{
		return PLUGIN_HANDLED;
	}
	
	static iStart; iStart = iPos * 8;
	
	if(iStart > g_iZombieClasses)
	{
		iStart = g_iZombieClasses;
	}

	iStart = iStart - (iStart % 8);
	
	gp_iMenuPosition[iIndex] = iStart / 8;

	static iEnd; iEnd = iStart + 8;
	
	if(iEnd > g_iZombieClasses)
	{
		iEnd = g_iZombieClasses;
	}
	
	static iPagesNum; iPagesNum = (g_iZombieClasses / 8 + ((g_iZombieClasses % 8) ? 1 : 0));
	
	static szMenu[512]; new iBitKeys = MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wКлассы зомби \d[%d|%d]^n^n", iPos + 1, iPagesNum);

	new iItem = 0, iCount;
	for(iCount = iStart + 1; iCount < iEnd + 1; iCount++)
	{
		if(gp_iClass[iIndex] == iCount)
		{
			iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
		}
		else
		{
			iBitKeys |= (1 << iItem);
			
			if(gp_iSelectedClass[iIndex] == iCount)
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \d%s \r[ \yON SPAWN \r]^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
			}
			else
			{
				iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, g_infoZombieClass[iCount][CLASS_NAME]);
			}
		}
	}
	
	for(iCount = iItem; iCount < 8; iCount++)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	
	if(iEnd < g_iZombieClasses)
	{
		iBitKeys |= MENU_KEY_9;
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	else
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	
	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_ChooseClass");
}

public Handler_ChooseClass(const iIndex, const iKey)	{
	switch(iKey)
	{
		case 8:
		{
			return ShowMenu_ChooseClass(iIndex, ++gp_iMenuPosition[iIndex]);
		}
		case 9:
		{
			return ShowMenu_ChooseClass(iIndex, --gp_iMenuPosition[iIndex]);
		}
		default:
		{
			new iClass = gp_iMenuPosition[iIndex] * 8 + iKey + 1;
			
			if(is_user_alive(iIndex) && IsNotSetBit(gp_iBit[BIT_INFECT], iIndex))
			{
				gp_iClass[iIndex] = iClass;
			}
			else
			{
				if(gp_iSelectedClass[iIndex] == iClass)
				{
					gp_iSelectedClass[iIndex] = CLASS_NONE;
				}
				else
				{
					gp_iSelectedClass[iIndex] = iClass;
				}
				
				/*
					TODO:
						Добавть сообщение, что класс будет доступен
						с нового раунда
				*/
			}
		}
	}
	
	return PLUGIN_HANDLED;
}

ShowMenu_Equipment(const iIndex)	{
	static szMenu[512]; new iBitKeys = MENU_KEY_1|MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wОбмундирование^n^n");
	
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[1] \wНовое оружие^n");
	
	static iPrimaryWeaponId; iPrimaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY];
	static iSecondaryWeaponId; iSecondaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY];

	if(!(iPrimaryWeaponId) || !(iSecondaryWeaponId))
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[2] \dПредыдущие снаряжие^n^n");
	}
	else
	{
		iBitKeys |= MENU_KEY_2;
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[2] \wПредыдущие снаряжие \r[ \d%s | %s \r]^n^n", g_listPrimaryWeaponszMenu[iPrimaryWeaponId], g_listSecondaryWeaponszMenu[iSecondaryWeaponId]);
	}
	
	if(!(iPrimaryWeaponId) || !(iSecondaryWeaponId))
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[3] \dБольше не показывать меню^n^n^n^n^n^n^n");
	}
	else
	{
		iBitKeys |= MENU_KEY_3;
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[3] \wБольше не показывать меню^n^n^n^n^n^n^n");
	}
	
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[0] \wВыход");

	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_Equipment");
}

public Handler_Equipment(const iIndex, const iKey)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	switch(iKey)
	{
		case 0:
		{
			return ShowMenu_PrimaryWeapons(iIndex, gp_iMenuPosition[iIndex] = 0);
		}
		case 1, 2:
		{
			new iPrimaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY];
			new iSecondaryWeaponId = gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY];
			
			givePlayerPrimaryWeapon(iIndex, iPrimaryWeaponId);
			givePlayerSecondaryWeapon(iIndex, iSecondaryWeaponId);
			
			givePlayerGrenades(iIndex);

			if(iKey == 2) ClearBit(gp_iBit[BIT_MENU_EQUIPMENT], iIndex);
		}
	}
	
	return PLUGIN_HANDLED;
}

ShowMenu_PrimaryWeapons(const iIndex, const iPos)	{
	if(iPos < 0 || !(g_iPrimaryWeapons))
	{
		return PLUGIN_HANDLED;
	}
	
	static iStart; iStart = iPos * 8;
	
	if(iStart > g_iPrimaryWeapons)
	{
		iStart = g_iPrimaryWeapons;
	}
	
	iStart = iStart - (iStart % 8);
	
	gp_iMenuPosition[iIndex] = iStart / 8;

	static iEnd; iEnd = iStart + 8;
	
	if(iEnd > g_iPrimaryWeapons)
	{
		iEnd = g_iPrimaryWeapons;
	}
	
	static iPagesNum; iPagesNum = (g_iPrimaryWeapons / 8 + ((g_iPrimaryWeapons % 8) ? 1 : 0));
	
	static szMenu[512], iBitKeys = MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wОсновное оружие \d[%d|%d]^n^n", iPos + 1, iPagesNum);

	new iItem = 0, iCount;
	for(iCount = iStart + 1; iCount < iEnd; iCount++)
	{
		iBitKeys |= (1 << iItem);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, g_listPrimaryWeaponszMenu[iCount][WEAPON_NAME]);
	}
	
	for(iCount = iItem; iCount < 8; iCount++)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	
	if(iEnd < g_iPrimaryWeapons)
	{
		iBitKeys |= MENU_KEY_9;
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	else
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	
	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_PrimaryWeapons");
}

public Handler_PrimaryWeapons(const iIndex, const iKey)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	switch(iKey)
	{
		case 8:
		{
			return ShowMenu_PrimaryWeapons(iIndex, ++gp_iMenuPosition[iIndex]);
		}
		case 9:
		{
			return ShowMenu_PrimaryWeapons(iIndex, --gp_iMenuPosition[iIndex]);
		}
		default:
		{
			if(is_user_alive(iIndex))
			{
				new iWeaponId = gp_iMenuPosition[iIndex] * 8 + iKey + 1;
				
				givePlayerPrimaryWeapon(iIndex, iWeaponId);
			}

			return ShowMenu_SecondaryWeapons(iIndex, gp_iMenuPosition[iIndex] = 0);
		}
	}
	return PLUGIN_HANDLED;
}

ShowMenu_SecondaryWeapons(const iIndex, const iPos)	{
	if(iPos < 0 || !(g_iSecondaryWeapons))
	{
		return PLUGIN_HANDLED;
	}
	
	static iStart; iStart = iPos * 8;
	
	if(iStart > g_iSecondaryWeapons)
	{
		iStart = g_iSecondaryWeapons;
	}
	
	iStart = iStart - (iStart % 8);
	
	gp_iMenuPosition[iIndex] = iStart / 8;

	static iEnd; iEnd = iStart + 8;
	
	if(iEnd > g_iSecondaryWeapons)
	{
		iEnd = g_iSecondaryWeapons;
	}
	
	static iPagesNum; iPagesNum = (g_iSecondaryWeapons / 8 + ((g_iSecondaryWeapons % 8) ? 1 : 0));
	
	static szMenu[512], iBitKeys = MENU_KEY_0;
	new iLen = formatex(szMenu, charsmax(szMenu), "\r[ZMB] \wЗапасное оружие \d[%d|%d]^n^n", iPos + 1, iPagesNum);

	new iItem = 0, iCount;
	for(iCount = iStart + 1; iCount < iEnd; iCount++)
	{
		iBitKeys |= (1 << iItem);
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r[%d] \w%s^n", ++iItem, g_listSecondaryWeaponszMenu[iCount][WEAPON_NAME]);
	}
	
	for(iCount = iItem; iCount < 8; iCount++)
	{
		iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
	}
	
	if(iEnd < g_iSecondaryWeapons)
	{
		iBitKeys |= MENU_KEY_9;
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r[9] \wДалее^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	else
	{
		formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n^n\r[0] \w%s", iPos ? "Назад" : "Выход");
	}
	
	return show_menu(iIndex, iBitKeys, szMenu, -1, "ShowMenu_SecondaryWeapons");
}

public Handler_SecondaryWeapons(const iIndex, const iKey)	{
	if(IsSetBit(gp_iBit[BIT_INFECT], iIndex))
	{
		return PLUGIN_HANDLED;
	}
	
	switch(iKey)
	{
		case 8:
		{
			return ShowMenu_SecondaryWeapons(iIndex, ++gp_iMenuPosition[iIndex]);
		}
		case 9:
		{
			return ShowMenu_SecondaryWeapons(iIndex, --gp_iMenuPosition[iIndex]);
		}
		default:
		{
			if(is_user_alive(iIndex))
			{
				new iWeaponId = gp_iMenuPosition[iIndex] * 8 + iKey + 1;
				
				givePlayerSecondaryWeapon(iIndex, iWeaponId);
				givePlayerGrenades(iIndex);
			}
		}
	}
	
	return PLUGIN_HANDLED;
}

/*================================================================================
 [ZMB]
=================================================================================*/
public taskInfect()	{
	g_bInfectionBegan = true;
	
	new iIndex, iPlayersNum, iPlayers[MAX_PLAYERS + 1];

	for(iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)
	{
		if(is_user_alive(iIndex))
		{
			iPlayers[iPlayersNum++] = iIndex;
		}
	}
	
	if(iPlayersNum)
	{
		new iTotalInfected = clamp(floatround(iPlayersNum * g_iCvar_ZombieRatio / 10.0), 1, 31);

		while(iTotalInfected--)
		{
			new iInfected = iPlayers[random(iPlayersNum)];
			
			if(IsNotSetBit(gp_iBit[BIT_INFECT], iInfected))
			{
				setPlayerInfect(iInfected);
			}
		}
	}
	
	for(iIndex = 1; iIndex <= g_iMaxPlayers; iIndex++)
	{
		if(is_user_alive(iIndex) && IsNotSetBit(gp_iBit[BIT_INFECT], iIndex))
		{
			rg_set_user_team(iIndex, TEAM_CT);
		}
	}
}

stock addZombieClass(const szName[], const szKnifeModel[], const szPlayerModel[], const Float: fSpeed, const Float: fHealth, const Float: fGravity, const Float: fFactorDmg)	{
	new iClass = g_iZombieClasses += 1;

	copy(g_infoZombieClass[iClass][CLASS_NAME], 64, szName);
	copy(g_infoZombieClass[iClass][CLASS_KNIFE_MODEL], 64, szKnifeModel);
	copy(g_infoZombieClass[iClass][CLASS_PLAYER_MODEL], 64, szPlayerModel);
	
	g_infoZombieClass[iClass][CLASS_SPEED] = _: fSpeed;
	g_infoZombieClass[iClass][CLASS_HEALTH] = _: fHealth;
	g_infoZombieClass[iClass][CLASS_GRAVITY] = _: fGravity;
	g_infoZombieClass[iClass][CLASS_FACTOR_DMG] = _: fFactorDmg;
}

stock setPlayerInfect(const iIndex)	{
	SetBit(gp_iBit[BIT_INFECT], iIndex);

	rg_set_user_team(iIndex, TEAM_TERRORIST);
	
	new iClass = gp_iClass[iIndex];
	
	if(g_infoZombieClass[iClass][CLASS_PLAYER_MODEL])
	{
		rg_set_user_model(iIndex, g_infoZombieClass[iClass][CLASS_PLAYER_MODEL], true);
	}
	
	if(g_infoZombieClass[iClass][CLASS_HEALTH])
	{
		set_entvar(iIndex, var_health, g_infoZombieClass[iClass][CLASS_HEALTH]);
	}
	
	if(g_infoZombieClass[iClass][CLASS_GRAVITY])
	{
		set_entvar(iIndex, var_gravity, g_infoZombieClass[iClass][CLASS_GRAVITY]);
	}
	
	removePlayerAllWeapons(iIndex);
	
	ExecuteHamB(g_iHamFwd_Player_Speed, iIndex);

	message_begin(MSG_ONE, MsgId_ScreenFade, {0, 0, 0}, iIndex);
	{
		write_short(1 << 12);
		write_short(1 << 12);
		write_short(0);
		write_byte(0);
		write_byte(255);
		write_byte(0);
		write_byte(110);
	}
	message_end();

	static szSound[64];
	ArrayGetString(g_aSoundsZombieScream, random(g_iSizeSoundsZombieScream), szSound, charsmax(szSound));

	emit_sound(0, CHAN_AUTO, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	set_task(1.0, "taskPlayerHud", TASK_ID_PLAYER_HUD + iIndex, .flags = "b");
}

public taskPlayerHud(iIndex)	{
	iIndex -= TASK_ID_PLAYER_HUD;

	static Float: fHealth; fHealth = get_entvar(iIndex, var_health);

	switch(g_iCvar_HudType)
	{
		case 0:	/* [HUD] */
		{
			set_hudmessage(g_iCvar_HudColor[COLOR_RED], g_iCvar_HudColor[COLOR_GREEN], g_iCvar_HudColor[COLOR_BLUE], g_fCvar_HudPosition[POS_X], g_fCvar_HudPosition[POS_Y], 0, 0.0, 0.9, 0.1, 0.1, -1);
			ShowSyncHudMsg(iIndex, g_iSyncPlayerHud, "Жизни [%.f] Класс ^"%s^"", fHealth, g_infoZombieClass[gp_iClass[iIndex]]);
		}
		case 1:	/* [DHUD] */
		{
			set_dhudmessage(g_iCvar_HudColor[COLOR_RED], g_iCvar_HudColor[COLOR_GREEN], g_iCvar_HudColor[COLOR_BLUE], g_fCvar_HudPosition[POS_X], g_fCvar_HudPosition[POS_Y], 0, 0.0, 0.9, 0.1, 0.1);
			show_dhudmessage(iIndex, "Жизни [%.f] Класс ^"%s^"", fHealth, g_infoZombieClass[gp_iClass[iIndex]]);
		}
	}
}

stock givePlayerPrimaryWeapon(const iIndex, const iPrimaryWeaponId)	{
	if(iPrimaryWeaponId != 0)
	{
		gp_iEquipment[iIndex][PLAYER_EQUIPMENT_PRIMARY] = iPrimaryWeaponId;

		rg_give_item(iIndex, g_listPrimaryWeaponszMenu[iPrimaryWeaponId][WEAPON_CLASSNAME], GT_REPLACE);
		rg_set_user_bpammo(iIndex, g_listPrimaryWeaponszMenu[iPrimaryWeaponId][WEAPON_ID], g_listPrimaryWeaponszMenu[iPrimaryWeaponId][WEAPON_BPAMMO]);
	}
}

stock givePlayerSecondaryWeapon(const iIndex, const iSecondaryWeaponId)	{
	if(iSecondaryWeaponId)
	{
		gp_iEquipment[iIndex][PLAYER_EQUIPMENT_SECONDARY] = iSecondaryWeaponId;

		rg_give_item(iIndex, g_listSecondaryWeaponszMenu[iSecondaryWeaponId][WEAPON_CLASSNAME], GT_REPLACE);
		rg_set_user_bpammo(iIndex, g_listSecondaryWeaponszMenu[iSecondaryWeaponId][WEAPON_ID], g_listSecondaryWeaponszMenu[iSecondaryWeaponId][WEAPON_BPAMMO]);
	}
}

stock givePlayerGrenades(const iIndex)	{
	for(new iCount = 0; iCount < sizeof(g_listGrenades); iCount++)
	{
		rg_give_item(iIndex, g_listGrenades[iCount]);
	}
}

stock removePlayerAllWeapons(const iIndex, const bool: bKnife = true)	{
	rg_remove_all_items(iIndex);
	
	if(bKnife) rg_give_item(iIndex, "weapon_knife");
}

/*================================================================================
 [UTIL]
=================================================================================*/
stock UTIL_SetKvd(const iEnt, const szClssName[], const szKeyName[], const szValue[])	{
	set_kvd(0, KV_ClassName, szClssName);
	set_kvd(0, KV_KeyName, szKeyName);
	set_kvd(0, KV_Value, szValue);
	set_kvd(0, KV_fHandled, 0);

	return dllfunc(DLLFunc_KeyValue, iEnt, 0);
}

stock UTIL_SetFileState(const zsPlugin[], const zsMessage[], any:...)	{
	new szLog[256];
	vformat(szLog, charsmax(szLog), zsMessage, 3);
	
	new szDate[20];
	get_time("error_%Y%m%d.log", szDate, charsmax(szDate));
	
	log_to_file(szDate, "[%s] %s", zsPlugin, szLog);
}

stock UTIL_ParseHEXColor(const szValue[])	{
	new iColor[Color];
	
	if(szValue[0] != '#' && strlen(szValue) != 7)
	{
		return iColor;
	}

	iColor[COLOR_RED] = UTIL_Parse16bit(szValue[1], szValue[2]);
	iColor[COLOR_GREEN] = UTIL_Parse16bit(szValue[3], szValue[4]);
	iColor[COLOR_BLUE] = UTIL_Parse16bit(szValue[5], szValue[6]);

	return iColor;
}

stock UTIL_Parse16bit(const cSymbol1, const cSymbol2)	{
	return UTIL_ParseHex(cSymbol1) * 16 + UTIL_ParseHex(cSymbol2);
}

stock UTIL_ParseHex(const cSymbol)	{
	switch(cSymbol)
	{
		case '0'..'9':
		{
			return cSymbol - '0';
		}
		case 'a'..'f':
		{
			return 10 + cSymbol - 'a';
		}
		case 'A'..'F':
		{
			return 10 + cSymbol - 'A';
		}
	}

	return 0;
}