#include <amxmodx>

#if AMXX_VERSION_NUM < 1100
#error "AMX Mod X versions 1.9 and below are not supported."
#endif

#include <amxmisc>
#include <cstrike>
#include <hamsandwich>
#include <fakemeta>
#include <SemiclipEX>

#define PLUGIN_NAME                     "SemiclipEX: Counter-Strike"
#define PLUGIN_DESCRIPTION              "Counter-Strike support for SemiclipEX"

new g_szWeapons[][] =
{	
	"weapon_knife",
	"weapon_p228",
	"weapon_scout",
	"weapon_hegrenade",
	"weapon_xm1014",
	"weapon_mac10",
	"weapon_aug",
	"weapon_smokegrenade",
	"weapon_elite",
	"weapon_fiveseven",
	"weapon_ump45",
	"weapon_sg550",
	"weapon_galil",
	"weapon_famas",
	"weapon_usp",
	"weapon_glock18",
	"weapon_awp",
	"weapon_mp5navy",
	"weapon_m249",
	"weapon_m3",
	"weapon_m4a1",
	"weapon_tmp",
	"weapon_g3sg1",
	"weapon_flashbang",
	"weapon_deagle",
	"weapon_sg552",
	"weapon_ak47",
	"weapon_p90"
};

public plugin_init()
{
    register_plugin(PLUGIN_NAME, SCE_PLUGIN_VERSION, SCE_PLUGIN_AUTHOR, SCE_PLUGIN_WEBSITE, PLUGIN_DESCRIPTION);

    RegisterHam(Ham_Spawn, "player", "HamFwd_PlayerSpawn_Post", true, true);
    RegisterHam(Ham_CS_RoundRespawn, "player", "HamFwd_PlayerSpawn_Post", true, true);

    for(new iCursor = 0; iCursor < sizeof g_szWeapons; iCursor++)
    {
        RegisterHam(Ham_Weapon_PrimaryAttack, g_szWeapons[iCursor], "HamFwd_WeaponAttack_Pre", false);
        RegisterHam(Ham_Weapon_PrimaryAttack, g_szWeapons[iCursor], "HamFwd_WeaponAttack_Post", true);
        RegisterHam(Ham_Weapon_SecondaryAttack, g_szWeapons[iCursor], "HamFwd_WeaponAttack_Pre", false);
        RegisterHam(Ham_Weapon_SecondaryAttack, g_szWeapons[iCursor], "HamFwd_WeaponAttack_Post", true);
    }
}

public HamFwd_WeaponAttack_Pre(iWeapon)
{
	new iClient = get_ent_data_entity(iWeapon, "CBasePlayerItem", "m_pPlayer");
	if(iClient)
		SCEX_ToggleSemiClipOnTarget(iClient, Toggle_Traces, true);
}

public HamFwd_WeaponAttack_Post(iWeapon)
{
	new iClient = get_ent_data_entity(iWeapon, "CBasePlayerItem", "m_pPlayer");
	if(iClient)
		SCEX_ToggleSemiClipOnTarget(iClient, Toggle_Traces, false);
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
		new CsTeams:iPlayerTeam = cs_get_user_team(iClient);
		new rgPlayers[MAX_PLAYERS], iPlayerCount, iOther;
		get_players_ex(rgPlayers, iPlayerCount, GetPlayers_ExcludeDead | GetPlayers_ExcludeHLTV | GetPlayers_MatchTeam, iPlayerTeam == CS_TEAM_T ? "TERRORIST" : "CT");
		for(new iIndex = 0; iIndex < iPlayerCount; iIndex++)
		{
			iOther = rgPlayers[iIndex];
			SCEX_MakeEntsSemiclippable(iClient, iOther);
			SCEX_EnableSemiclipFlags(iClient, iOther, SCF_ALLOW_BOOSTING | SCF_FADE);
		}
	}
}