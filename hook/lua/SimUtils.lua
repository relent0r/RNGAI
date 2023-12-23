local RNGOldTransferUnitsOwnership = TransferUnitsOwnership
TransferUnitsOwnership = function(units, toArmy, captured)
    --LOG('TransferUnitsOwnership is running')
    local transferedUnits = RNGOldTransferUnitsOwnership(units, toArmy, captured)
    ForkThread(import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua').OnTransfered, transferedUnits, toArmy, captured)
    return transferedUnits
end