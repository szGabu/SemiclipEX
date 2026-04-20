#if defined _semiclipex_included
	#endinput
#endif
#define _semiclipex_included

#include <amxmodx>
#include <SemiclipEX_const>

#if AMXX_VERSION_NUM < 1100
#error "AMX Mod X versions 1.9 and below are not supported."
#endif

#pragma reqlib semiclipex
#if !defined AMXMODX_NOAUTOLOAD
	#pragma loadlib semiclipex
#endif

/**
 * Enables two entities to pass through each other
 *
 * @param iEntity     First entity index
 * @param iOther      Second entity index
 *
 * @return            true if both entities are valid, false otherwise
 */
native bool:SCEX_MakeEntsSemiclippable(iEntity, iOther)

/**
 * Disables two entities from passing through each other, restoring original functionality.
 * 
 * Unlike SCEX_MakeEntsSemiclippable, this doesn't perform entity validation checks.
 *
 * @param iEntity     First entity index
 * @param iOther      Second entity index
 */
native SCEX_MakeEntsNonSemiclippables(iEntity, iOther)

/**
 * Completely makes the entity non-semiclippable against all entities.
 * 
 * Useful in cleanup operations and when assigning to a new group.
 *
 * @param iEntity     Entity index
 */
native SCEX_MakeEntNonSemiclippableAll(iEntity)

/**
 * Enables semiclip flags between two entities
 *
 * @param iEntity     First entity index
 * @param iOther      Second entity index
 * @param iFlags      Semiclip flags to enable
 *
 * @return            Resulting bitwise flags after enabling the specified ones, 0 if entities are invalid
 */
native SCEX_EnableSemiclipFlags(iEntity, iOther, iFlags)

/**
 * Disables semiclip flags between two entities
 *
 * @param iEntity     First entity index
 * @param iOther      Second entity index
 * @param iFlags      Semiclip flags to disable
 *
 * @return            Resulting bitwise flags after disabling the specified ones, 0 if entities are invalid
 */
native SCEX_DisableSemiclipFlags(iEntity, iOther, iFlags)

/**
 * Toggles semiclip status for this entity for fine frame calculations. Useful when temporarily enable collisions
 * in functions that requires them. For example, you can call this on your attack functions, both in pre and post. 
 * You NEED to call this again on post or bad things will happen.
 * 
 * A common use is, for example, your knife's primary attack function, with a pre and post hook and just call this 
 * native in each one. This will allow the attack go through the semiclippable entities that don't have the SCF_TRACE_BLOCK flag.
 *
 * @param iEntity     	First entity index
 * @param hType       	Behavior of temporary semiclipping:
 * 						Toggle_Standard, all other semiclippable entities aside from iEntity become passable. Useful for movement.
 * 						Toggle_Traces, iEntity and all semiclippable entities become solid. Useful for attacks.
 * 						Toggle_WorldMoving, iEntity and all semiclippable entities become non-solid. Useful for elevators, doors, BSP interactions, etc.
 * @param bPre       	Should be true if if in a pre-hook, false otherwise
 */
native SCEX_ToggleSemiClipOnTarget(iEntity, ToggleType:hType, bool:bPre)