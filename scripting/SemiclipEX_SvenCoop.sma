#include <amxmodx>

#if AMXX_VERSION_NUM < 1100
#error "AMX Mod X versions 1.9 and below are not supported."
#endif

#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <SemiclipEX>

#define PLUGIN_NAME                     "SemiclipEX: Sven Co-op"
#define PLUGIN_DESCRIPTION              "Sven Co-op support for SemiclipEX"

#define SC_CLASS_NONE               0
#define SC_CLASS_MACHINE            1
#define SC_CLASS_PLAYER             2
#define SC_CLASS_PLAYER_ALLY        3
#define SC_CLASS_HUMAN_PASSIVE      4
#define SC_CLASS_HUMAN_MILITARY     5
#define SC_CLASS_ALIEN_PASSIVE      6
#define SC_CLASS_ALIEN_MILITARY     7
#define SC_CLASS_ALIEN_MONSTER      8
#define SC_CLASS_ALIEN_PREY         9
#define SC_CLASS_ALIEN_PREDATOR     10
#define SC_CLASS_INSECT             11
#define SC_CLASS_PLAYER_BIOWEAPON   12
#define SC_CLASS_ALIEN_BIOWEAPON    13
#define SC_CLASS_RACE_X_PITDRONE    14
#define SC_CLASS_RACE_X_SHOCKTR     15
#define SC_CLASS_TEAM_A             16
#define SC_CLASS_TEAM_B             17
#define SC_CLASS_TEAM_C             18
#define SC_CLASS_TEAM_D             19

enum //relationship types
{
	R_AL = -2,      // (ALLY) pals. Good alternative to R_NO when applicable.
    R_FR = -1,      // (FEAR) will run
    R_NO = 0,       // (NO RELATIONSHIP) disregard
    R_DL,           // (DISLIKE) will attack
    R_HT,           // (HATE) will attack this character instead of any visible DISLIKEd characters
    R_NM            // (NEMESIS)  A monster Will ALWAYS attack its nemesis, no matter what
};

public plugin_init()
{
	register_plugin(PLUGIN_NAME, SCE_PLUGIN_VERSION, SCE_PLUGIN_AUTHOR, SCE_PLUGIN_WEBSITE, PLUGIN_DESCRIPTION);

	RegisterHam(Ham_Spawn, "player", "HamFwd_PlayerSpawn_Post", true, true);
	RegisterHam(Ham_SC_Player_SpecialSpawn, "player", "HamFwd_PlayerSpawn_Post", true);
	RegisterHam(Ham_SC_SetClassification, "player", "HamFwd_PlayerSpawn_Post", true);
}

public HamFwd_PlayerSpawn_Post(iClient)
{
    RequestFrame("FrameNext_PlayerSpawn_Post", get_user_userid(iClient));
}

public FrameNext_PlayerSpawn_Post(iUserId)
{
	new iClient = find_player_ex(FindPlayer_MatchUserId, iUserId);
	if(iClient && is_user_alive(iClient))
		AdjustSemiClip(iClient);
}

AdjustSemiClip(iClient)
{
	SCEX_MakeEntNonSemiclippableAll(iClient);
	new rgPlayers[MAX_PLAYERS], iPlayerCount, iOther;
	get_players_ex(rgPlayers, iPlayerCount, GetPlayers_ExcludeHLTV);
	for(new iIndex = 0; iIndex < iPlayerCount; iIndex++)
	{
		iOther = rgPlayers[iIndex];

		if(iOther == iClient)
			continue;

		if(ExecuteHamB(Ham_IRelationship, iClient, iOther) == R_AL)
		{
			SCEX_MakeEntsSemiclippable(iClient, iOther);
			SCEX_EnableSemiclipFlags(iClient, iOther, SCF_ALLOW_BOOSTING | SCF_FADE);
		}
	}
}