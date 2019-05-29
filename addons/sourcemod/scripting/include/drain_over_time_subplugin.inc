/**
 * General notes about the actions below:
 * - I don't like how the FF2 plug-in allows user to not specify a plugin name (can be multiple matches) so I'm not allowing it here.
 */
public Action:OnDOTAbilityActivatedInternal(clientIdx)
{
	OnDOTAbilityActivated(clientIdx);
	return Plugin_Continue;
}

public Action:OnDOTAbilityDeactivatedInternal(clientIdx)
{
	OnDOTAbilityDeactivated(clientIdx);
	return Plugin_Continue;
}

public Action:OnDOTAbilityTickInternal(clientIdx, tickCount)
{
	OnDOTAbilityTick(clientIdx, tickCount);
	return Plugin_Continue;
}

public Action:DOTPostRoundStartInitInternal()
{
	DOTPostRoundStartInit();
	return Plugin_Continue;
}

public Action:OnDOTUserDeathInternal(clientIdx, isInGame)
{
	OnDOTUserDeath(clientIdx, isInGame);
	return Plugin_Continue;
}

