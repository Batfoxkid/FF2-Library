/**
 * Dynamic Defaults Include
 *
 * Due to load order issues, need to use reflection for these accessor methods.
 * Same problem I had with my Drain Over Time plugin.
 */
stock Handle:FindDDPlugin()
{
	decl String:buffer[256];
	
	new Handle:iter = GetPluginIterator();
	new Handle:pl = INVALID_HANDLE;
	
	while (MorePlugins(iter))
	{
		pl = ReadPlugin(iter);
		
		GetPluginFilename(pl, buffer, sizeof(buffer));
		if (StrContains(buffer, "ff2_dynamic_defaults.ff2", false) != -1)
			break;
		else
			pl = INVALID_HANDLE;
	}
	
	CloseHandle(iter);

	return pl;
}

// last parameter is default because it was added after the first release
stock DD_SetDisabled(clientIdx, bool:superjump, bool:teleport, bool:weighdown, bool:glide = false)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DD_SetDisabled");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(superjump);
			Call_PushCell(teleport);
			Call_PushCell(weighdown);
			Call_PushCell(glide);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DD_SetDisabled().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DD_SetDisabled() failed.");
}

// invoking this method does not require teleport to be in your boss config
// return value tells you if teleport succeeded
stock bool:DD_PerformTeleport(clientIdx, Float:stunDuration, bool:tryAbove = false, bool:trySide = false, bool:sameTeam = false, bool:reverseTeleport = false)
{
	new bool:result = false;

	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DD_PerformTeleport");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(stunDuration);
			Call_PushCell(tryAbove);
			Call_PushCell(trySide);
			Call_PushCell(sameTeam);
			Call_PushCell(reverseTeleport);
			Call_Finish(result);
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DD_PerformTeleport().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DD_PerformTeleport() failed.");
		
	return result;
}

stock DD_SetForceHUDEnabled(clientIdx, bool:force)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DD_SetForceHUDEnabled");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(force);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DD_SetForceHUDEnabled().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DD_SetForceHUDEnabled() failed.");
}

// returns -1.0 if invalid (i.e. hale has no enabled mobility options at the time, DOES NOT MEAN they won't the entire round though!)
stock Float:DD_GetMobilityCooldown(clientIdx)
{
	new Float:result = -1.0;

	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DD_GetMobilityCooldown");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_Finish(result);
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DD_GetMobilityCooldown().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DD_GetMobilityCooldown() failed.");
		
	return result;
}

// returns -1.0 if invalid (i.e. hale has no enabled mobility options at the time, DOES NOT MEAN they won't the entire round though!)
stock Float:DD_GetChargePercent(clientIdx)
{
	new Float:result = -1.0;

	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DD_GetChargePercent");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_Finish(result);
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DD_GetChargePercent().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DD_GetChargePercent() failed.");
		
	return result;
}

stock bool:DD_IsSpotSafe(clientIdx, const Float:pos[3], Float:sizeMultiplier = 1.0)
{
	new bool:result = false;

	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "IsSpotSafe"); // not a mistake. this method has no prefix.
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(pos[0]);
			Call_PushFloat(pos[1]);
			Call_PushFloat(pos[2]);
			Call_PushFloat(sizeMultiplier);
			Call_Finish(result);
		}
		else
			PrintToServer("ERROR: Could not find ff2_sarysamods8.sp:IsSpotSafe().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_sarysamods8 plugin. IsSpotSafe() failed.");
		
	return result;
}

stock DJ_SetUsesRemaining(clientIdx, usesRemaining)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DJ_SetUsesRemaining");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(usesRemaining);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DJ_SetUsesRemaining().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DJ_SetUsesRemaining() failed.");
}

stock DJ_CooldownUntil(clientIdx, Float:cooldownEndTime)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DJ_CooldownUntil");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(cooldownEndTime);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DJ_CooldownUntil().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DJ_CooldownUntil() failed.");
}

stock DJ_AdjustCooldownTimer(clientIdx, Float:offset)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DJ_AdjustCooldownTimer");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(offset);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DJ_AdjustCooldownTimer().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DJ_AdjustCooldownTimer() failed.");
}

// NOTE: Set any of the floats below to -1.0 to preserve the existing value.
stock DJ_ChangeFundamentalStats(clientIdx, Float:chargeTime, Float:cooldown, Float:multiplier)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DJ_ChangeFundamentalStats");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(chargeTime);
			Call_PushFloat(cooldown);
			Call_PushFloat(multiplier);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DJ_ChangeFundamentalStats().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DJ_ChangeFundamentalStats() failed.");
}

stock DT_SetUsesRemaining(clientIdx, usesRemaining)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DT_SetUsesRemaining");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(usesRemaining);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DT_SetUsesRemaining().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DT_SetUsesRemaining() failed.");
}

stock DT_CooldownUntil(clientIdx, Float:cooldownEndTime)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DT_CooldownUntil");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(cooldownEndTime);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DT_CooldownUntil().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DT_CooldownUntil() failed.");
}

stock DT_AdjustCooldownTimer(clientIdx, Float:offset)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DT_AdjustCooldownTimer");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(offset);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DT_AdjustCooldownTimer().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DT_AdjustCooldownTimer() failed.");
}

// NOTE: Set any of the floats below to -1.0 to preserve the existing value.
stock DT_ChangeFundamentalStats(clientIdx, Float:chargeTime, Float:cooldown, Float:stunDuration)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DT_ChangeFundamentalStats");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(chargeTime);
			Call_PushFloat(cooldown);
			Call_PushFloat(stunDuration);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DT_ChangeFundamentalStats().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DT_ChangeFundamentalStats() failed.");
}

stock DT_SetTargetTeam(clientIdx, bool:sameTeam)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DT_SetTargetTeam");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(sameTeam);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DT_SetTargetTeam().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DT_SetTargetTeam() failed.");
}

stock DT_SetIsReverse(clientIdx, bool:isReverse)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DT_SetIsReverse");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(isReverse);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DT_SetIsReverse().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DT_SetIsReverse() failed.");
}

stock DT_SetAboveSide(clientIdx, bool:canTeleportAbove, bool:canTeleportSide)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DT_SetAboveSide");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(canTeleportAbove);
			Call_PushCell(canTeleportSide);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DT_SetAboveSide().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DT_SetAboveSide() failed.");
}

stock DW_SetUsesRemaining(clientIdx, usesRemaining)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DW_SetUsesRemaining");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(usesRemaining);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DW_SetUsesRemaining().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DW_SetUsesRemaining() failed.");
}

stock DW_CooldownUntil(clientIdx, Float:cooldownEndTime)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DW_CooldownUntil");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(cooldownEndTime);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DW_CooldownUntil().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DW_CooldownUntil() failed.");
}

// note, this is to set the player's normal gravity. weighdown gravity is always 6.0.
stock DW_SetDefaultGravity(clientIdx, Float:gravity)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DW_SetDefaultGravity");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(gravity);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DW_SetDefaultGravity().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DW_SetDefaultGravity() failed.");
}

// NOTE: Set any of the floats below to -1.0 to preserve the existing value.
stock DG_ChangeFundamentalStats(clientIdx, Float:startVelocity, Float:decayPerSecond, Float:cooldown, Float:maxDuration)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DG_ChangeFundamentalStats");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(startVelocity);
			Call_PushFloat(decayPerSecond);
			Call_PushFloat(cooldown);
			Call_PushFloat(maxDuration);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DG_ChangeFundamentalStats().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DG_ChangeFundamentalStats() failed.");
}

stock DSSG_PerformStun(clientIdx, Float:radius, Float:duration)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DSSG_PerformStun");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(radius);
			Call_PushFloat(duration);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DSSG_PerformStun().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DSSG_PerformStun() failed.");
}

stock DSSG_PerformStunFromCoords(clientIdx, const Float:coords[3], Float:radius, Float:duration)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DSSG_PerformStunFromCoords");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(coords[0]);
			Call_PushFloat(coords[1]);
			Call_PushFloat(coords[2]);
			Call_PushFloat(radius);
			Call_PushFloat(duration);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DSSG_PerformStunFromCoords().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DSSG_PerformStunFromCoords() failed.");
}

stock DSSG_StunOneSentry(sentry, Float:duration)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DSSG_StunOneSentry");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(sentry);
			Call_PushFloat(duration);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DSSG_StunOneSentry().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DSSG_StunOneSentry() failed.");
}

stock DSSG_UnstunOneSentry(sentry)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DSSG_UnstunOneSentry");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(sentry);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DSSG_UnstunOneSentry().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DSSG_UnstunOneSentry() failed.");
}

// NOTE: Set any of the floats below to -1.0 to maintain the existing setting
stock DSM_SetModifiers(clientIdx, Float:bfb, Float:rifle, Float:bow, Float:minigun, Float:slowed, Float:critcola, Float:whip, Float:dazed)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DSM_SetModifiers");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(bfb);
			Call_PushFloat(rifle);
			Call_PushFloat(bow);
			Call_PushFloat(minigun);
			Call_PushFloat(slowed);
			Call_PushFloat(critcola);
			Call_PushFloat(whip);
			Call_PushFloat(dazed);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DSM_SetModifiers().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DSM_SetModifiers() failed.");
}

stock DSM_SetDisguiseSettings(clientIdx, bool:useDisguiseSpeed, bool:disguiseIncreasesSpeed)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DSM_SetDisguiseSettings");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushCell(useDisguiseSpeed);
			Call_PushCell(disguiseIncreasesSpeed);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DSM_SetDisguiseSettings().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DSM_SetDisguiseSettings() failed.");
}

// set a temporary override speed, completely ignoring DSM's calculated speed
// set overrideSpeed to -1.0 to clear it. (or just call it with no params except clientIdx)
stock DSM_SetOverrideSpeed(clientIdx, Float:overrideSpeed = -1.0, bool:applyModifiers = false)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DSM_SetOverrideSpeed");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_PushFloat(overrideSpeed);
			Call_PushCell(applyModifiers);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DSM_SetOverrideSpeed().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DSM_SetOverrideSpeed() failed.");
}

stock DMM_ResetWeapon(clientIdx)
{
	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DMM_ResetWeapon");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_Finish();
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DMM_ResetWeapon().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DMM_ResetWeapon() failed.");
}

stock bool:DP_IsLatched(clientIdx)
{
	new bool:latched = false;

	new Handle:plugin = FindDDPlugin();
	if (plugin != INVALID_HANDLE)
	{
		new Function:func = GetFunctionByName(plugin, "DP_IsLatched");
		if (func != INVALID_FUNCTION)
		{
			Call_StartFunction(plugin, func);
			Call_PushCell(clientIdx);
			Call_Finish(latched);
		}
		else
			PrintToServer("ERROR: Could not find ff2_dynamic_defaults.sp:DP_IsLatched().");
	}
	else
		PrintToServer("ERROR: Could not find ff2_dynamic_defaults plugin. DP_IsLatched() failed.");
		
	return latched;
}
