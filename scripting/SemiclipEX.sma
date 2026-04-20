#include <amxmodx>

#if AMXX_VERSION_NUM < 1100
#error "AMX Mod X versions 1.9 and below are not supported."
#endif

#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <SemiclipEX_const>
#tryinclude <reapi>
#if !defined _reapi_included
#include <orpheu>
#endif

new bool:g_bShouldSemiClip[MAX_EDICTS];
new bool:g_rgSemiClipTargetsFast[MAX_EDICTS][MAX_EDICTS];
new Array:g_hSemiClipTargetsArray[MAX_EDICTS];
new g_rgFlags[MAX_EDICTS][MAX_EDICTS];
new g_iOriginalGroupInfoBuffer[MAX_FUNCTIONS][MAX_EDICTS]; //this is needed to restore the proper group info state on each step, see BufferFunction
new Float:g_fPassthroughSpeed;
new Float:g_fFadeDistance;
new bool:g_bTracing = false;

#if defined _orpheu_included
new OrpheuFunction:g_hTestEntityPositionFunction;
new OrpheuHook:g_hTestEntityPositionPreHook, OrpheuHook:g_hTestEntityPositionPostHook;
#endif

new g_cvarPassthroughSpeed;
new g_cvarFadeDistance;

public plugin_init()
{
    register_plugin(SCE_PLUGIN_NAME, SCE_PLUGIN_VERSION, SCE_PLUGIN_AUTHOR, SCE_PLUGIN_WEBSITE, SCE_PLUGIN_DESCRIPTION);

    for (new i = 0; i < MAX_FUNCTIONS; i++)
        arrayset(g_iOriginalGroupInfoBuffer[i], -1, sizeof g_iOriginalGroupInfoBuffer[]);

    g_cvarPassthroughSpeed = create_cvar("amx_semiclip_passthrough_speed", "500.0", FCVAR_NONE, "Vertical speed threshold under which semiclip allows players to pass through each other. 0.0 to disable.", true, 0.0);
    g_cvarFadeDistance = create_cvar("amx_semiclip_fade_distance", "64.0", FCVAR_NONE, "Distance where semiclipping entities should fade from a player's POV. 0.0 to disable.", true, 0.0);
    
    bind_pcvar_float(g_cvarPassthroughSpeed, g_fPassthroughSpeed);
    bind_pcvar_float(g_cvarFadeDistance, g_fFadeDistance);

    register_forward(FM_AddToFullPack, "MetaFwd_AddToFullPack_Post", true);
    register_forward(FM_EmitSound, "MetaFwd_EmitSound_Pre");
    register_forward(FM_EmitSound, "MetaFwd_EmitSound_Post", true);
    register_forward(FM_ShouldCollide, "MetaFwd_ShouldCollide_Pre");
    register_forward(FM_RemoveEntity, "MetaFwd_RemoveEntity_Post", true);

    // These two break semiclip, my original idea was to automatically handle passthrough between shots on semiclip targets 
    // but GoldSrc has forced my hand. The best next thing I could've come up with was to just expose the two internal functions
    // so we can add support for mods individually, by hooking each entity's attack
    // register_forward(FM_TraceLine, "MetaFwd_TraceLine_Pre");
    // register_forward(FM_TraceLine, "MetaFwd_TraceLine_Post", true);
    
    RegisterHam(Ham_Player_PreThink, "player", "HamFwd_PlayerPreThink_Post", false, true);
    RegisterHam(Ham_Player_PostThink, "player", "HamFwd_PlayerPostThink_Post", true, true);
}

public plugin_cfg()
{
    #if defined _orpheu_included
    g_hTestEntityPositionFunction = OrpheuGetFunction("SV_TestEntityPosition");

    if(g_hTestEntityPositionFunction)
    {
        g_hTestEntityPositionPreHook = OrpheuRegisterHook(g_hTestEntityPositionFunction,"OrpheuFwd_TestEntityPosition_Pre");
        g_hTestEntityPositionPostHook = OrpheuRegisterHook(g_hTestEntityPositionFunction,"OrpheuFwd_TestEntityPosition_Post", OrpheuHookPost);
    }
    else
        set_fail_state("Missing signatures for SV_TestEntityPosition.");
    #else
    // At the time of writing, RH_SV_TestEntityPosition is a custom implementation
    // The plugin won't work on vanilla ReHLDS, and you'll need to compile it yourself with the patch
    // (Or wait until the patch is merged and released, which may take a while)
    RegisterHookChain(RH_SV_TestEntityPosition, "ReFwd_SV_TestEntityPosition_Pre");
    RegisterHookChain(RH_SV_TestEntityPosition, "ReFwd_SV_TestEntityPosition_Post", true);
    #endif
}

#if defined _orpheu_included
public plugin_end()
{
    if(g_hTestEntityPositionPreHook)
        OrpheuUnregisterHook(g_hTestEntityPositionPreHook);

    if(g_hTestEntityPositionPostHook)
        OrpheuUnregisterHook(g_hTestEntityPositionPostHook);
}
#endif

#if defined _orpheu_included
public OrpheuFwd_TestEntityPosition_Pre(iEntity)
#else
public ReFwd_SV_TestEntityPosition_Pre(iEntity)
#endif
{
    ToggleSemiClipOnTarget(iEntity, Toggle_WorldMoving, Buffer_TestEntityPosition, true);
}

#if defined _orpheu_included
public OrpheuFwd_TestEntityPosition_Post(iEntity)
#else
public ReFwd_SV_TestEntityPosition_Post(iEntity)
#endif
{ 
    ToggleSemiClipOnTarget(iEntity, Toggle_WorldMoving, Buffer_TestEntityPosition, false);
}

public client_disconnected(iClient)
{
    MakeEntNonSemiclippableAll(iClient);
}

public plugin_natives()
{
    register_library("semiclipex");
    register_native("SCEX_MakeEntsSemiclippable", "API_MakeEntsSemiclippable");
    register_native("SCEX_MakeEntsNonSemiclippables", "API_MakeEntsNonSemiclippables");
    register_native("SCEX_MakeEntNonSemiclippableAll", "API_MakeEntNonSemiclippableAll");
    register_native("SCEX_EnableSemiclipFlags", "API_EnableSemiclipFlags");
    register_native("SCEX_DisableSemiclipFlags", "API_DisableSemiclipFlags");
    register_native("SCEX_ToggleSemiClipOnTarget", "API_ToggleSemiClipOnTarget");
}

public API_MakeEntsSemiclippable(iPlugin, iParams)
{
    new iEntity = get_param(1);
    new iOther = get_param(2);
    
    return MakeEntitiesSemiclippable(iEntity, iOther);
}

public API_MakeEntsNonSemiclippables(iPlugin, iParams)
{
    new iEntity = get_param(1);
    new iOther = get_param(2);
    
    MakeEntsNonSemiclippables(iEntity, iOther);
}

public API_MakeEntNonSemiclippableAll(iPlugin, iParams)
{
    new iEntity = get_param(1);
    
    MakeEntNonSemiclippableAll(iEntity);
}

public API_EnableSemiclipFlags(iPlugin, iParams)
{
    new iEntity = get_param(1);
    new iOther = get_param(2);
    new iFlags = get_param(3);
    
    return EnableSemiclipFlags(iEntity, iOther, iFlags);
}

public API_DisableSemiclipFlags(iPlugin, iParams)
{
    new iEntity = get_param(1);
    new iOther = get_param(2);
    new iFlags = get_param(3);
    
    return DisableSemiclipFlags(iEntity, iOther, iFlags);
}

public API_ToggleSemiClipOnTarget(iPlugin, iParams)
{
    new iEntity = get_param(1);
    new ToggleType:hType = ToggleType:get_param(2);
    new bool:bPre = get_param(3) == 1;
    
    ToggleSemiClipOnTarget(iEntity, hType, Buffer_ThirdParty+BufferFunction:iPlugin, bPre);
}

public bool:MakeEntitiesSemiclippable(iEntity, iOther)
{
    if(pev_valid(iEntity) && pev_valid(iOther) && iEntity != iOther)
    {
        g_bShouldSemiClip[iEntity] = true;
        g_bShouldSemiClip[iOther] = true;

        if(!g_hSemiClipTargetsArray[iEntity])
            g_hSemiClipTargetsArray[iEntity] = ArrayCreate();

        if(!g_hSemiClipTargetsArray[iOther])
            g_hSemiClipTargetsArray[iOther] = ArrayCreate();

        if(ArrayFindValue(g_hSemiClipTargetsArray[iEntity], iOther) == -1)
            ArrayPushCell(g_hSemiClipTargetsArray[iEntity], iOther);

        if(ArrayFindValue(g_hSemiClipTargetsArray[iOther], iEntity) == -1)
            ArrayPushCell(g_hSemiClipTargetsArray[iOther], iEntity);
        
        g_rgSemiClipTargetsFast[iEntity][iOther] = true;
        g_rgSemiClipTargetsFast[iOther][iEntity] = true;

        return true;
    }

    return false;
}

public MakeEntsNonSemiclippables(iEntity, iOther)
{
    new Array:hArray = g_hSemiClipTargetsArray[iEntity];
    new iIndex = -1;
    if(hArray)
    {
        iIndex = ArrayFindValue(hArray, iOther);
        if(iIndex >= 0)
        {
            ArrayDeleteItem(hArray, iIndex);
            if(ArraySize(hArray) == 0)
            {
                g_bShouldSemiClip[iEntity] = false;
                ArrayDestroy(hArray);
                g_hSemiClipTargetsArray[iEntity] = Array:0;
            }
        }
    }

    hArray = g_hSemiClipTargetsArray[iOther];
    if(hArray)
    {
        iIndex = ArrayFindValue(hArray, iEntity);
        if(iIndex >= 0)
        {
            ArrayDeleteItem(hArray, iIndex);
            if(ArraySize(hArray) == 0)
            {
                g_bShouldSemiClip[iOther] = false;
                ArrayDestroy(hArray);
                g_hSemiClipTargetsArray[iOther] = Array:0;
            }
        }
    }

    g_rgSemiClipTargetsFast[iEntity][iOther] = false;
    g_rgSemiClipTargetsFast[iOther][iEntity] = false;
    g_rgFlags[iEntity][iOther] = SCF_NONE;
    g_rgFlags[iOther][iEntity] = SCF_NONE;
}

public MakeEntNonSemiclippableAll(iEntity)
{
    if(!g_bShouldSemiClip[iEntity])
        return;

    g_bShouldSemiClip[iEntity] = false;

    new Array:hArray = g_hSemiClipTargetsArray[iEntity];
    if(hArray)
    {
        ArrayDestroy(hArray);
        g_hSemiClipTargetsArray[iEntity] = Array:0;
    }

    for(new iOther = 0; iOther < MAX_EDICTS; iOther++)
    {
        if(!g_bShouldSemiClip[iOther] || iOther == iEntity)
            continue;

        g_rgSemiClipTargetsFast[iOther][iEntity] = false;
        g_rgSemiClipTargetsFast[iEntity][iOther] = false;
        g_rgFlags[iEntity][iOther] = SCF_NONE;
        g_rgFlags[iOther][iEntity] = SCF_NONE;

        hArray = g_hSemiClipTargetsArray[iOther];
        if(hArray)
        {
            new iIndex = ArrayFindValue(hArray, iEntity);
            if(iIndex >= 0)
            {
                ArrayDeleteItem(hArray, iIndex);
                if(ArraySize(hArray) == 0)
                {
                    g_bShouldSemiClip[iOther] = false;
                    ArrayDestroy(hArray);
                    g_hSemiClipTargetsArray[iOther] = Array:0;
                }
            }
        }
    }
}

public EnableSemiclipFlags(iEntity, iOther, iFlags)
{
    if(!g_rgSemiClipTargetsFast[iEntity][iOther])
        return SCF_NONE;

    g_rgFlags[iEntity][iOther] |= iFlags;
    g_rgFlags[iOther][iEntity] |= iFlags;

    return g_rgFlags[iEntity][iOther];
}

public DisableSemiclipFlags(iEntity, iOther, iFlags)
{
    if(!g_rgSemiClipTargetsFast[iEntity][iOther])
        return SCF_NONE;

    g_rgFlags[iEntity][iOther] &= ~iFlags;
    g_rgFlags[iOther][iEntity] &= ~iFlags;

    return g_rgFlags[iEntity][iOther];
}

public MetaFwd_EmitSound_Pre(iEntity, iChannel, const szSample[], Float:fVolume, Float:fAttenuation, iFlags, iPitch)
{
    ToggleSemiClipOnTarget(iEntity, Toggle_Traces, Buffer_EmitSound, true);
}

public MetaFwd_EmitSound_Post(iEntity, iChannel, const szSample[], Float:fVolume, Float:fAttenuation, iFlags, iPitch)
{
    ToggleSemiClipOnTarget(iEntity, Toggle_Traces, Buffer_EmitSound, false);
}

public MetaFwd_TraceLine_Pre(Float:v1[3], Float:v2[3], iNoMonsters, iEntToSkip, hTraceResult)
{
    if(!iEntToSkip || !g_bShouldSemiClip[iEntToSkip] || iNoMonsters == 1)
        return;

    ToggleSemiClipOnTarget(iEntToSkip, Toggle_Traces, Buffer_TraceLine, true);
}

public MetaFwd_TraceLine_Post(Float:v1[3], Float:v2[3], iNoMonsters, iEntToSkip, hTraceResult)
{
    if(!iEntToSkip || !g_bShouldSemiClip[iEntToSkip] || iNoMonsters == 1)
        return;

    ToggleSemiClipOnTarget(iEntToSkip, Toggle_Traces, Buffer_TraceLine, false);
}  

public MetaFwd_AddToFullPack_Post(hEntState, iEdict, iOther, iClient, iHostFlags, bPlayer, hSet)
{
    if(iClient != iOther && pev_valid(iOther))
    {
        if(is_user_alive(iClient) && g_rgSemiClipTargetsFast[iClient][iOther])
        {
            static iClientFlags;
            static iOtherFlags;

            iClientFlags = pev(iClient, pev_flags);
            iOtherFlags = pev(iOther, pev_flags);
            
            if((iOtherFlags & FL_DORMANT) > 0 || (iClientFlags & FL_DORMANT) > 0 )
                return;

            if(g_rgFlags[iClient][iOther] & SCF_ALLOW_BOOSTING)
            {
                static iClientMoveType;
                static iOtherMoveType;

                iClientMoveType = pev(iClient, pev_movetype);
                iOtherMoveType = pev(iOther, pev_movetype);

                if((iClientMoveType == MOVETYPE_FLY || iOtherMoveType == MOVETYPE_FLY) && bPlayer)
                    set_es(hEntState, ES_Solid, SOLID_NOT); // prevents blocking of ladder players
                else
                {
                    static Float:fClientAbsMin[3], Float:fClientAbsMax[3];
                    static Float:fOtherAbsMin[3], Float:fOtherAbsMax[3];
                    static Float:fClientVelocity[3];

                    pev(iClient, pev_velocity, fClientVelocity);
                    pev(iClient, pev_absmin, fClientAbsMin);
                    pev(iClient, pev_absmax, fClientAbsMax);
                    pev(iOther, pev_absmin, fOtherAbsMin);
                    pev(iOther, pev_absmax, fOtherAbsMax);

                    if( (fClientAbsMin[2]+CALIBRATION >= fOtherAbsMax[2] && 
                        (g_fPassthroughSpeed == 0 || fClientVelocity[2] < g_fPassthroughSpeed)) || 
                        (fOtherAbsMin[2]+CALIBRATION >= fClientAbsMax[2]))
                        set_es(hEntState, ES_Solid, 1);
                    else
                        set_es(hEntState, ES_Solid, SOLID_NOT);
                }
            }
            else
                set_es(hEntState, ES_Solid, SOLID_NOT);

            if(g_rgFlags[iClient][iOther] & SCF_FADE)
            {
                static Float:fDistance, iRenderAmt;
                fDistance = entity_range(iClient, iOther)
                if(fDistance < g_fFadeDistance)
                {
                    set_es(hEntState, ES_RenderMode, kRenderTransAlpha);
                    iRenderAmt = floatround(255.0 * (fDistance / g_fFadeDistance));
                    set_es(hEntState, ES_RenderAmt, iRenderAmt);
                }
            }
        }
    }
}

public MetaFwd_ShouldCollide_Pre(iTouched, iOther)
{
    new bool:bIsPlayer = (0 < iTouched <= MaxClients);
    new bool:bShouldSupercede = false;
    if(g_rgSemiClipTargetsFast[iTouched][iOther])
    {
        if(bIsPlayer)
        {
            if(g_bTracing && (g_rgFlags[iTouched][iOther] & SCF_TRACE_BLOCK) == 0)
            {
                static Float:fDistance;
                fDistance = entity_range(iTouched, iOther)
                if(fDistance < g_fFadeDistance)
                    bShouldSupercede = true;
            }
        }
        else
            bShouldSupercede = true;
    }

    if(bShouldSupercede)
    {
        forward_return(FMV_CELL, 0);
        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public MetaFwd_RemoveEntity_Post(iEntity)
{
    MakeEntNonSemiclippableAll(iEntity);
}

public HamFwd_PlayerPreThink_Post(iClient)
{
    if(!is_user_alive(iClient) || !g_bShouldSemiClip[iClient])
        return;

    RemoveFromSemiclipping(iClient, Buffer_PlayerThink);
    static iIndex, Array:hArrayPointer, iArrayLength, iOther, bool:bPlayer;
    hArrayPointer = g_hSemiClipTargetsArray[iClient];
    iArrayLength = ArraySize(hArrayPointer);

    for(iIndex = 0; iIndex < iArrayLength; iIndex++)
    {
        iOther = ArrayGetCell(hArrayPointer, iIndex);

        if(pev_valid(iOther) && iOther != iClient)
        {
            bPlayer = (0 < iOther <= MaxClients);
            if(g_rgFlags[iClient][iOther] & SCF_ALLOW_BOOSTING)
            {
                static iClientMoveType;
                static iOtherMoveType;

                iClientMoveType = pev(iClient, pev_movetype);
                iOtherMoveType = pev(iOther, pev_movetype);

                if((iClientMoveType == MOVETYPE_FLY || iOtherMoveType == MOVETYPE_FLY) && bPlayer)
                    BecomeSemiclippable(iOther, Buffer_PlayerThink);
                else
                {
                    new Float:fClientAbsMin[3], Float:fClientAbsMax[3];
                    new Float:fOtherAbsMin[3], Float:fOtherAbsMax[3];
                    new Float:fClientVelocity[3];
                    pev(iClient, pev_absmin, fClientAbsMin);
                    pev(iClient, pev_absmax, fClientAbsMax);
                    pev(iClient, pev_velocity, fClientVelocity);
                    pev(iOther, pev_absmin, fOtherAbsMin);
                    pev(iOther, pev_absmax, fOtherAbsMax);

                    if((fClientAbsMin[2]+CALIBRATION >= fOtherAbsMax[2] && 
                        (g_fPassthroughSpeed == 0 || fClientVelocity[2] < g_fPassthroughSpeed)) || 
                        (fOtherAbsMin[2]+CALIBRATION >= fClientAbsMax[2]))
                        RemoveFromSemiclipping(iOther, Buffer_PlayerThink);
                    else 
                        BecomeSemiclippable(iOther, Buffer_PlayerThink);
                }
            }
            else
                BecomeSemiclippable(iOther, Buffer_PlayerThink);
        }
    }
}

public HamFwd_PlayerPostThink_Post(iClient)
{
    if(!is_user_alive(iClient) || !g_bShouldSemiClip[iClient] || !g_hSemiClipTargetsArray[iClient])
        return;

    RestoreOriginalState(iClient, Buffer_PlayerThink);
    static iIndex, Array:hArrayPointer, iArrayLength, iOther;
    hArrayPointer = g_hSemiClipTargetsArray[iClient];
    iArrayLength = ArraySize(hArrayPointer);
    for(iIndex = 0; iIndex < iArrayLength; iIndex++)
    {
        iOther = ArrayGetCell(hArrayPointer, iIndex);
        if(iOther != iClient && pev_valid(iOther))
            RestoreOriginalState(iOther, Buffer_PlayerThink);
    }
}

//type 0 standard
//type 1 for traces
//type 2 for world moving
stock ToggleSemiClipOnTarget(iEntity, ToggleType:hType, BufferFunction:hFunctionIndex, bool:bPre)
{
    if(g_bShouldSemiClip[iEntity])
    {
        if(bPre)
        {
            if(hType == Toggle_Traces)
                RemoveFromSemiclipping(iEntity, hFunctionIndex);
            else if(hType == Toggle_WorldMoving)
                BecomeSemiclippable(iEntity, hFunctionIndex);
        }  
        else
            RestoreOriginalState(iEntity, hFunctionIndex);

        static iIndex, Array:hArrayPointer, iArrayLength, iOther;
        hArrayPointer = g_hSemiClipTargetsArray[iEntity];
        iArrayLength = ArraySize(hArrayPointer);
        for(iIndex = 0; iIndex < iArrayLength; iIndex++)
        {
            iOther = ArrayGetCell(hArrayPointer, iIndex);

            if(iOther == iEntity || !pev_valid(iOther))
                continue;

            if(bPre)
            {
                if(hType == Toggle_Traces)
                {
                    g_bTracing = true;

                    if(g_rgFlags[iEntity][iOther] & SCF_TRACE_BLOCK)
                        RemoveFromSemiclipping(iOther, hFunctionIndex);
                    else
                    {
                        static Float:fDistance;
                        fDistance = entity_range(iEntity, iOther)
                        if(fDistance < g_fFadeDistance)
                            BecomeSemiclippable(iOther, hFunctionIndex);
                        else
                            RemoveFromSemiclipping(iOther, hFunctionIndex);
                    }
                }
                else if(hType == Toggle_WorldMoving)
                    BecomeSemiclippable(iOther, hFunctionIndex);
                else 
                    RemoveFromSemiclipping(iEntity, hFunctionIndex);
            }
            else 
            {
                if(hType == Toggle_Traces)
                    g_bTracing = false;

                RestoreOriginalState(iOther, hFunctionIndex);
            }
        }
    }
}

stock RemoveFromSemiclipping(iEntity, BufferFunction:hFunctionIndex)
{
    g_iOriginalGroupInfoBuffer[_:hFunctionIndex][iEntity] = pev(iEntity, pev_groupinfo);
    set_pev(iEntity, pev_groupinfo, 0);
}

stock BecomeSemiclippable(iEntity, BufferFunction:hFunctionIndex)
{
    g_iOriginalGroupInfoBuffer[_:hFunctionIndex][iEntity] = pev(iEntity, pev_groupinfo);
    set_pev(iEntity, pev_groupinfo, PlayerIdToBit((0 < iEntity <= MaxClients) ? iEntity : iEntity + 1));
}

stock RestoreOriginalState(iEntity, BufferFunction:hFunctionIndex)
{
    if(g_iOriginalGroupInfoBuffer[_:hFunctionIndex][iEntity] == -1)
        return; // nothing to restore

    set_pev(iEntity, pev_groupinfo, g_iOriginalGroupInfoBuffer[_:hFunctionIndex][iEntity]);
    g_iOriginalGroupInfoBuffer[_:hFunctionIndex][iEntity] = -1;
}

stock bool:IsColliding(iThis, iOther)
{
    new Float:cMin[3], Float:cMax[3], Float:oMin[3], Float:oMax[3];
    pev(iThis, pev_absmin, cMin);
    pev(iThis, pev_absmax, cMax);
    pev(iOther, pev_absmin, oMin);
    pev(iOther, pev_absmax, oMax);

    // if *any* axis doesn’t overlap, there’s no collision
    if (cMax[0] < oMin[0] || cMin[0] > oMax[0]) return false; // x‐axis gap
    if (cMax[1] < oMin[1] || cMin[1] > oMax[1]) return false; // y‐axis
    if (cMax[2] < oMin[2] || cMin[2] > oMax[2]) return false; // z‐axis

    return true;  // all axes overlap
}

stock PlayerIdToBit(const iClient)
{
    //thanks anggaranothing
	return ( 1<<( iClient & 31 ) );
}