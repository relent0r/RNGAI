local RNGOldTransferUnitsOwnership = TransferUnitsOwnership
TransferUnitsOwnership = function(units, toArmy, captured)
    --LOG('TransferUnitsOwnership is running')
    local originBrain
    for _, v in units do
        local owner = v.Army
        if IsAlly(owner, toArmy) then
            originBrain = v:GetAIBrain()
        end
        break
    end
    local transferedUnits = RNGOldTransferUnitsOwnership(units, toArmy, captured)
    ForkThread(import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua').OnTransfered, transferedUnits, toArmy, captured, originBrain)
    return transferedUnits
end