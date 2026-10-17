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

public plugin_init()
{
	register_plugin(PLUGIN_NAME, SCE_PLUGIN_VERSION, SCE_PLUGIN_AUTHOR, SCE_PLUGIN_WEBSITE, PLUGIN_DESCRIPTION);

	RegisterHam(Ham_Spawn, "player", "HamFwd_PlayerSpawn_Post", true, true);
	RegisterHam(Ham_SC_Player_SpecialSpawn, "player", "HamFwd_PlayerSpawn_Post", true);
}

public HamFwd_PlayerSpawn_Post(iClient)
{
    RequestFrame("FrameNext_PlayerSpawn_Post", iClient);
}

public FrameNext_PlayerSpawn_Post(iClient)
{
	if(is_user_alive(iClient))
	{
		SCEX_MakeEntNonSemiclippableAll(iClient);
		new rgPlayers[MAX_PLAYERS], iPlayerCount, iOther;
		get_players_ex(rgPlayers, iPlayerCount, GetPlayers_ExcludeDead | GetPlayers_ExcludeHLTV);
		for(new iIndex = 0; iIndex < iPlayerCount; iIndex++)
		{
			iOther = rgPlayers[iIndex];
			SCEX_MakeEntsSemiclippable(iClient, iOther);
			SCEX_EnableSemiclipFlags(iClient, iOther, SCF_ALLOW_BOOSTING);
		}
	}
}