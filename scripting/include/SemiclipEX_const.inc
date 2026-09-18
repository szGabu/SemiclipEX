#if defined _semiclipex_const_included
	#endinput
#endif
#define _semiclipex_const_included

enum ToggleType 
{
    Toggle_Standard = 0,
    Toggle_Traces,
    Toggle_WorldMoving
}

enum BufferFunction 
{
    Buffer_TestEntityPosition = 0,
    Buffer_EmitSound,
    Buffer_PlayerThink,
    Buffer_TraceLine, //unused, added for legacy reasons
    Buffer_ThirdParty, //entry itself is unused, entries are done using this entry + plugin ID
}

#define SCF_NONE                        0   // No special behavior
#define SCF_ALLOW_BOOSTING              1   // Allow players to boost each other by jumping on top of each other
#define SCF_TRACE_BLOCK                 2   // Traces should hit the opposing entity
#define SCF_FADE                        4   // Entity should fade out when close to each other

#define SCE_PLUGIN_NAME                 "SemiclipEX: Master Plugin"
#define SCE_PLUGIN_AUTHOR               "szGabu"
#define SCE_PLUGIN_VERSION              "26w17a"
#define SCE_PLUGIN_WEBSITE              "https://github.com/szGabu/SemiclipEX"
#define SCE_PLUGIN_DESCRIPTION          "A new era of Semiclip for GoldSrc"

#if !defined MAX_EDICT_BITS
#define MAX_EDICT_BITS                  11                  // How many bits to use to encode an edict. # of bits needed to represent max edicts
#endif
#if !defined MAX_EDICTS
#define MAX_EDICTS                      (1<<MAX_EDICT_BITS) // Max # of edicts in a level (2048)
#endif

#define MAX_FUNCTIONS                   64

#define CALIBRATION                     3 //do not change this unless you know what are you doing