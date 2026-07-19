--[[
    File    :   /lua/AI/AIBaseTemplates/EconomyBuildConditions.lua
    Author  :   relentless
    Summary :
        Economy Build Conditions
]]
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored

function MexUpgradeEco(aiBrain)
    if aiBrain.EnemyIntel.ChokeFlag then
        if aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 0.9 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.0 then
            return true
        end
    elseif GetEconomyTrend(aiBrain, 'MASS') >= 0.0 and GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.70 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.90 then
        return true
    end
    return false
end

function GreaterThanEconStorageRatioRNG(aiBrain, mStorageRatio, eStorageRatio, mult)

    if aiBrain.EnemyIntel.ChokeFlag then
        if mult == 'LAND' then
            if GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.20 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.80 then
                return true
            end
        elseif mult == 'FACTORY' then
            if GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.10 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.80 then
                return true
            end
        elseif mult == 'DEFENSE' then
            if GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.20 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.80 then
                return true
            end
        elseif GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
            return true
        end
    elseif mult == true then
        if GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
            return true
        end
    elseif GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
        return true
    end
    return false
end

function LessThanEconStorageRatioRNG(aiBrain, mStorageRatio, eStorageRatio)

    if GetEconomyStoredRatio(aiBrain, 'MASS') < mStorageRatio and GetEconomyStoredRatio(aiBrain, 'ENERGY') < eStorageRatio then
        return true
    end
    return false
end

function GreaterThanEconTrendRNG(aiBrain, MassTrend, EnergyTrend)

    if GetEconomyTrend(aiBrain, 'MASS') >= MassTrend and GetEconomyTrend(aiBrain, 'ENERGY') >= EnergyTrend then
        return true
    end
    return false
end

function GreaterThanEnergyStorageRatioRNG(aiBrain, eStorageRatio)
    if GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
        return true
    end
    return false
end

function GreaterThanEnergyTrendRNG(aiBrain, eTrend)

    if GetEconomyTrend(aiBrain, 'ENERGY') > eTrend then
        --RNGLOG('Greater than Energy Trend Returning True : '..econ.EnergyTrend)
        return true
    else
        --RNGLOG('Greater than Energy Trend Returning False : '..econ.EnergyTrend)
        return false
    end
end

function GreaterThanMassTrendRNG(aiBrain, mTrend)

    if GetEconomyTrend(aiBrain, 'MASS') > mTrend then
        return true
    else
        return false
    end
end

function LessThanMassTrendRNG(aiBrain, mTrend)

    if GetEconomyTrend(aiBrain, 'MASS') < mTrend then
        return true
    else
        return false
    end
end

--            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 50.0 } },
function LessThanEnergyTrendRNG(aiBrain, eTrend)

    if GetEconomyTrend(aiBrain, 'ENERGY') < eTrend then
        return true
    else
        return false
    end
end
-- not used yet
function GreaterThanEconEfficiencyOverTimeRNG(aiBrain, MassEfficiency, EnergyEfficiency)
    -- Using eco over time values from the EconomyOverTimeRNG thread.
    --RNGLOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= MassEfficiency and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --RNGLOG('GreaterThanEconEfficiencyOverTime Returned True')
        return true
    end
    --RNGLOG('GreaterThanEconEfficiencyOverTime Returned False')
    return false
end

function GreaterThanEconEfficiencyCombinedRNG(aiBrain, MassEfficiency, EnergyEfficiency)
    -- Using eco over time values from the EconomyOverTimeRNG thread.
    if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= MassEfficiency and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --RNGLOG('GreaterThanEconEfficiencyOverTime passed True')
        local EnergyEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
        local MassEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
        if (MassEfficiencyOverTime >= MassEfficiency and EnergyEfficiencyOverTime >= EnergyEfficiency) then
            return true
        end
    end
    return false
end

function GreaterThanEconEfficiencyOrAirStrategyRNG(aiBrain, MassEfficiency, EnergyEfficiency)
    -- Using eco over time values from the EconomyOverTimeRNG thread.
    if aiBrain.BrainIntel.PlayerStrategy.T3AirRush then
        return true
    end
    if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= MassEfficiency and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --RNGLOG('GreaterThanEconEfficiencyOverTime passed True')
        local EnergyEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
        local MassEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
        if (MassEfficiencyOverTime >= MassEfficiency and EnergyEfficiencyOverTime >= EnergyEfficiency) then
            return true
        end
    end
    return false
end

function GreaterThanEnergyEfficiencyOverTimeRNG(aiBrain, EnergyEfficiency)

    if aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= EnergyEfficiency then
        return true
    end
    return false
end

function LessThanEnergyEfficiencyOverTimeRNG(aiBrain, EnergyEfficiency)

    if aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime <= EnergyEfficiency then
        return true
    end
    return false
end

function GreaterThanEconTrendOverTimeRNG(aiBrain, MassTrend, EnergyTrend)
    -- Using eco over time values from the EconomyOverTimeRNG thread.
    --RNGLOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (aiBrain.EconomyOverTimeCurrent.MassTrendOverTime >= MassTrend and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= EnergyTrend) then
        --RNGLOG('GreaterThanEconTrendOverTime Returned True')
        return true
    end
    --RNGLOG('GreaterThanEconTrendOverTime Returned False')
    return false
end

function GreaterThanEconTrendCombinedRNG(aiBrain, MassTrend, EnergyTrend)
    -- Using combined eco values values from the EconomyOverTimeRNG thread.
    --RNGLOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (aiBrain.EconomyOverTimeCurrent.MassTrendOverTime >= MassTrend and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= EnergyTrend) then
        if GetEconomyTrend(aiBrain, 'MASS') >= MassTrend and GetEconomyTrend(aiBrain, 'ENERGY') >= EnergyTrend then
            return true
        end
    end
    --RNGLOG('GreaterThanEconTrendOverTime Returned False')
    return false
end

function LessThanEnergyTrendOverTimeRNG(aiBrain, EnergyTrend)

    if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime < EnergyTrend then
        --RNGLOG('GreaterThanEconTrendOverTime Returned True')
        return true
    end
    --RNGLOG('GreaterThanEconTrendOverTime Returned False')
    return false
end

function LessThanEnergyTrendCombinedRNG(aiBrain, EnergyTrend, lateGameScale)

    if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime < EnergyTrend then
        if GetEconomyTrend(aiBrain, 'ENERGY') < EnergyTrend then
            return true
        end
    end
    if lateGameScale then
        local energyIncome = GetEconomyIncome(aiBrain, 'ENERGY')
        local massIncome = GetEconomyIncome(aiBrain, 'MASS')
        if massIncome * 50 < energyIncome then
            return true
        end
    end
    --RNGLOG('GreaterThanEconTrendOverTime Returned False')
    return false
end

function NegativeEcoPowerCheck(aiBrain, EnergyTrend)
    if aiBrain.EcoManager.EcoPowerPreemptive then
        --LOG('PreEmptive Power Check is true')
        return true
    end
    if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime < EnergyTrend then
        if GetEconomyTrend(aiBrain, 'ENERGY') < EnergyTrend then
            return true
        end
    end
    return false
end

function NegativeEcoPowerCheckInstant(aiBrain, EnergyTrend)
    if aiBrain.EcoManager.EcoPowerPreemptive then
        --LOG('PreEmptive Power Check is true')
        return true
    end
    if GetEconomyTrend(aiBrain, 'ENERGY') < EnergyTrend then
        return true
    end
    return false
end


function GreaterThanEnergyTrendOverTimeRNG(aiBrain, EnergyTrend)

    if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime > EnergyTrend then
        --RNGLOG('GreaterThanEconTrendOverTime Returned True')
        return true
    end
    --RNGLOG('GreaterThanEconTrendOverTime Returned False')
    return false
end

function GreaterThanEconEfficiencyRNG(aiBrain, MassEfficiency, EnergyEfficiency)

    local EnergyEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
    local MassEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
    --RNGLOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (MassEfficiencyOverTime >= MassEfficiency and EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --RNGLOG('GreaterThanEconEfficiencyOverTime Returned True')
        return true
    end
    --RNGLOG('GreaterThanEconEfficiencyOverTime Returned False')
    return false
end

function LessThanEconEfficiencyRNG(aiBrain, MassEfficiency, EnergyEfficiency)

    local EnergyEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
    local MassEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
    --RNGLOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (MassEfficiencyOverTime <= MassEfficiency and EnergyEfficiencyOverTime <= EnergyEfficiency) then
        --RNGLOG('LessThanEconEfficiencyOverTime Returned True')
        return true
    end
    --RNGLOG('LessThanEconEfficiencyOverTime Returned False')
    return false
end

function GreaterThanMassStorageOrEfficiency(aiBrain, mStorage, massEfficiency)
    -- For building something that you only care about the mass stuff
    if aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= massEfficiency then
        local MassEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
        if MassEfficiencyOverTime >= massEfficiency then
            return true
        end
    elseif GetEconomyStored(aiBrain, 'MASS') >= mStorage then
        return true
    end
    return false
end

function GreaterThanEconStorageCurrentRNG(aiBrain, mStorage, eStorage)

    if (GetEconomyStored(aiBrain, 'MASS') >= mStorage and GetEconomyStored(aiBrain, 'ENERGY') >= eStorage) then
        return true
    end
    return false
end

function LessThanEnergyStorageCurrentRNG(aiBrain, eStorage)
    if GetEconomyStored(aiBrain, 'ENERGY') <= eStorage then
        return true
    end
    return false
end

-- { UCBC, 'EnergyToMassRatioIncomeRNG', { 10.0, '>=',true } },  -- True if we have 10 times more Energy then Mass income ( 100 >= 10 = true )
function EnergyToMassRatioIncomeRNG(aiBrain, ratio, compareType)

    return CompareBody(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyIncome(aiBrain,'MASS'), ratio, compareType)
end

function GreaterThanEconIncomeRNG(aiBrain, mIncome, eIncome)

    if (GetEconomyIncome(aiBrain,'MASS') >= mIncome and GetEconomyIncome(aiBrain,'ENERGY') >= eIncome) then
        return true
    end
    return false
end

function GreaterThanEconIncomeCombinedRNG(aiBrain, mIncome, eIncome)

    if aiBrain.EconomyOverTimeCurrent.MassIncome > mIncome and aiBrain.EconomyOverTimeCurrent.EnergyIncome > eIncome then
        if (GetEconomyIncome(aiBrain,'MASS') >= mIncome and GetEconomyIncome(aiBrain,'ENERGY') >= eIncome) then
            return true
        end
    end
    --RNGLOG('MassIncome Required '..mIncome)
    --RNGLOG('EnergyIncome Required '..eIncome)
    --RNGLOG('Mass Income Over time'..aiBrain.EconomyOverTimeCurrent.MassIncome)
    --RNGLOG('Mass Income '..GetEconomyIncome(aiBrain,'MASS'))
    --RNGLOG('Energy Income Over time'..aiBrain.EconomyOverTimeCurrent.EnergyIncome)
    --RNGLOG('Energy Income '..GetEconomyIncome(aiBrain,'ENERGY'))
    return false
end

function HighValueGateRNG(aiBrain)

    local multiplier = aiBrain.EcoManager.EcoMultiplier
    if GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.70 then
        return true
    end
    if aiBrain.EcoManager.CoreExtractorT3Percentage < 1.0 and aiBrain.cmanager.income.r.m < (160 * multiplier) and not aiBrain.RNGEXP then
        return false
    end
    return true
end

function ZoneBasedFactoryToMassSupported(aiBrain, locationType, compareType, layer, requireBuilt, storageBuild)
    -- Use '<' to add factories (we are under-producing)
    -- Use '>' to remove factories (we are over-producing)
    local manager = aiBrain.BuilderManagers[locationType]
    if not manager.FactoryManager then
        WARN('*AI WARNING: No Factory Manager at location - ' .. locationType)
        return false
    end
    local ecoMultiplier = 1.0
    if aiBrain.CheatEnabled then 
        ecoMultiplier = aiBrain.EcoManager.EcoMultiplier
    end
    local spendableStorage = 0
    if storageBuild then
        spendableStorage = math.max(0, aiBrain:GetEconomyStored('MASS') - 250)
    end
    local baseLocation = manager.Position or aiBrain.BrainIntel.StartPos
    local pathableZones = manager.PathableZones
    local expansionSize = math.min((aiBrain.MapDimension / 2), 160)
    local index = aiBrain:GetArmyIndex()
    local resourceCount = 0
    local massSpendTotal = 0
    local zoneBasedIncome = 0
    if manager.ZoneID then
        -- Check Land zones first, fallback to Water if managing a naval base
        local homeZone = aiBrain.Zones.Land.zones[manager.ZoneID] or aiBrain.Zones.Water.zones[manager.ZoneID]
        if homeZone and homeZone.resourcevalue then
            resourceCount = resourceCount + homeZone.resourcevalue
        end
    end
    if pathableZones and not table.empty(pathableZones.Zones) then
        for _, z in pathableZones.Zones do
            if z.ZoneID then
                local zone = aiBrain.Zones.Land.zones[z.ZoneID]
                if zone.resourcevalue > 0 and not zone.BuilderManager.FactoryManager.LocationActive then
                    local dx = baseLocation[1] - zone.pos[1]
                    local dz = baseLocation[3] - zone.pos[3]
                    local posDist = dx * dx + dz * dz
                    if posDist < (expansionSize * expansionSize) and zone.bestarmy == index then
                        if z.zoneincome.selfincome then
                            zoneBasedIncome = zoneBasedIncome + z.zoneincome.selfincome
                        end
                        if zone.resourcevalue then
                            resourceCount = resourceCount + zone.resourcevalue
                        end
                    end
                end
            end
        end
    end

    if manager.FactoryManager.LocationActive then
        local massToFactoryValues = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues
        local factoryDrain = {}
        if layer == 'Land' then
            local t1LandFactories = 0
            local t2LandFactories = 0
            local t3LandFactories = 0
            factoryDrain.t1LandDrain = (massToFactoryValues.T1LandValue or 8) * ecoMultiplier
            factoryDrain.t2LandDrain = (massToFactoryValues.T2LandValue or 20) * ecoMultiplier
            factoryDrain.t3LandDrain = (massToFactoryValues.T3LandValue or 30) * ecoMultiplier
            for _, v in manager.FactoryManager.FactoryList do
                if v.Blueprint.CategoriesHash.LAND then
                    if requireBuilt and v:GetFractionComplete() ~= 1 then
                        continue
                    end
                    if v.Blueprint.CategoriesHash.TECH1 then
                        t1LandFactories = t1LandFactories + 1
                    elseif v.Blueprint.CategoriesHash.TECH2 then
                        t2LandFactories = t2LandFactories + 1
                    elseif v.Blueprint.CategoriesHash.TECH3 then
                        t3LandFactories = t3LandFactories + 1
                    end
                end
            end
            massSpendTotal = (t1LandFactories * factoryDrain.t1LandDrain) + (t2LandFactories * factoryDrain.t2LandDrain) + (t3LandFactories * factoryDrain.t3LandDrain)
        elseif layer == 'Air' then
            local t1AirFactories = 0
            local t2AirFactories = 0
            local t3AirFactories = 0
            factoryDrain.t1AirDrain = (massToFactoryValues.T1AirValue or 8) * ecoMultiplier
            factoryDrain.t2AirDrain = (massToFactoryValues.T2AirValue or 20) * ecoMultiplier
            factoryDrain.t3AirDrain = (massToFactoryValues.T3AirValue or 30) * ecoMultiplier
            for _, v in manager.FactoryManager.FactoryList do
                if v.Blueprint.CategoriesHash.AIR then
                    if requireBuilt and v:GetFractionComplete() ~= 1 then
                        continue
                    end
                    if v.Blueprint.CategoriesHash.TECH1 then
                        t1AirFactories = t1AirFactories + 1
                    elseif v.Blueprint.CategoriesHash.TECH2 then
                        t2AirFactories = t2AirFactories + 1
                    elseif v.Blueprint.CategoriesHash.TECH3 then
                        t3AirFactories = t3AirFactories + 1
                    end
                end
            end
            massSpendTotal = (t1AirFactories * factoryDrain.t1AirDrain) + (t2AirFactories * factoryDrain.t2AirDrain) + (t3AirFactories * factoryDrain.t3AirDrain)
        elseif layer == 'Naval' then
            local t1NavalFactories = 0
            local t2NavalFactories = 0
            local t3NavalFactories = 0
            factoryDrain.t1NavalDrain = (massToFactoryValues.T1NavalValue or 8) * ecoMultiplier
            factoryDrain.t2NavalDrain = (massToFactoryValues.T2NavalValue or 20) * ecoMultiplier
            factoryDrain.t3NavalDrain = (massToFactoryValues.T3NavalValue or 30) * ecoMultiplier
            for k, m in aiBrain.BuilderManagers do
                if m.Layer == 'Water' and m.FactoryManager and m.FactoryManager.LocationActive then
                    for _, v in m.FactoryManager.FactoryList do
                        if requireBuilt and v:GetFractionComplete() ~= 1 then
                            continue
                        end
                        if v.Blueprint.CategoriesHash.NAVAL then
                            if v.Blueprint.CategoriesHash.TECH1 then
                                t1NavalFactories = t1NavalFactories + 1
                            elseif v.Blueprint.CategoriesHash.TECH2 then
                                t2NavalFactories = t2NavalFactories + 1
                            elseif v.Blueprint.CategoriesHash.TECH3 then
                                t3NavalFactories = t3NavalFactories + 1
                            end
                        end
                    end
                end
            end
            massSpendTotal = (t1NavalFactories * factoryDrain.t1NavalDrain) + (t2NavalFactories * factoryDrain.t2NavalDrain) + (t3NavalFactories * factoryDrain.t3NavalDrain)
        end


        local mexSpend = (aiBrain.cmanager.categoryspend.mex.T1 + aiBrain.cmanager.categoryspend.mex.T2 + aiBrain.cmanager.categoryspend.mex.T3) or 0
        local rawIncome
        if locationType == 'MAIN' then
            rawIncome = ( aiBrain.cmanager.income.r.m - mexSpend * 0.5) or 0
        elseif manager.Layer == 'Water' then
            rawIncome = ( aiBrain.cmanager.income.r.m - (mexSpend * 0.5)) or 0
        else
            rawIncome = zoneBasedIncome
        end
         
        local availableResources = math.max(resourceCount * 2, rawIncome, spendableStorage)
        if aiBrain.LowResourceMapProfile then
            local factoryCategory
            if layer == 'Land' then
                factoryCategory = categories.LAND
            elseif layer == 'Air' then
                factoryCategory = categories.AIR
            elseif layer == 'Naval' then
                factoryCategory = categories.NAVAL
            end
            local highTechCount = manager.FactoryManager:GetNumCategoryFactories(factoryCategory * (categories.TECH2 + categories.TECH3))
            -- Only throttle if we have transitioned to higher tech.
            -- This preserves normal T1 scaling early game, but applies tight economic
            -- discipline the moment high-drain T2/T3 structures exist.
            if highTechCount > 0 then
                availableResources = math.max(rawIncome, 0)
                if availableResources <= 0 then availableResources = 2 end
            end
        end
        local productionRatio 
        if aiBrain.ProductionRatios[layer] == 0 then
            productionRatio = aiBrain.DefaultProductionRatios[layer] 
        elseif aiBrain.BrainIntel.HighestPhase > 2 then
            productionRatio = aiBrain.ProductionRatios[layer]
        else
            productionRatio = aiBrain.ProductionIntent[layer]
        end
        --LOG('Production rato is '..tostring(productionRatio))
        local currentRatio = massSpendTotal / availableResources
        --LOG('currentRatio '..tostring(currentRatio)..' productionRatio '..tostring(productionRatio)..' compareType '..tostring(compareType))
        local globalTrend = aiBrain.EconomyOverTimeCurrent.MassTrendOverTime or 0
        --------
        local actualTrend = aiBrain:GetEconomyTrend('MASS')
        local zonePotential = resourceCount * 2
        local isMaskingDeficit = (actualTrend < 0 and zonePotential > rawIncome)
        --[[
        LOG(string.format('ZONE_LOGIC_AUDIT: Loc: %s | ZonePot: %.2f | RawInc: %.2f | ActualTrend: %.2f | Masking: %s', tostring(locationType), zonePotential, rawIncome, actualTrend, tostring(isMaskingDeficit)))
        local willReturnTrue = (massSpendTotal / availableResources) < productionRatio
        if isMaskingDeficit and willReturnTrue then
            LOG(string.format('ECON_TRAP_TRIGGERED: Stalling at %.2f but logic says "Build More" due to ZonePot!', actualTrend))
        end
        ----------
        LOG(string.format("RNGLOG_T3_STALL_AUDIT | Loc: %s | Intent: %.2f | CurrRatio: %.2f | AvailRes: %.2f | GlobalTrend: %.2f", tostring(locationType), productionRatio, currentRatio, availableResources, globalTrend))
        ]]
        return CompareBody(currentRatio, productionRatio, compareType)
    end
    return false
end

function GreaterThanEconIncomeOverTimeRNG(aiBrain, massIncome, energyIncome)
    if aiBrain.EconomyOverTimeCurrent.MassIncome > massIncome and aiBrain.EconomyOverTimeCurrent.EnergyIncome > energyIncome then
        return true
    end
    return false
end

function LessThanEconIncomeOverTimeRNG(aiBrain, massIncome, energyIncome)
    if aiBrain.EconomyOverTimeCurrent.MassIncome < massIncome and aiBrain.EconomyOverTimeCurrent.EnergyIncome < energyIncome then
        return true
    end
    return false
end

function FactorySpendRatioRNG(aiBrain, LocationType, uType, upgradeType, noStorageCheck, demandBuilder)
    local fmgr = aiBrain.BuilderManagers[LocationType].FactoryManager
    
    -- 1. Budget Gate (Command Economy for Land, Global for others)
    local productionRatio = fmgr["Base"..uType.."Ratio"] or aiBrain.ProductionRatios[uType] or 0

    if demandBuilder then
        productionRatio = math.max(productionRatio, aiBrain.DefaultProductionRatios[uType] or 0)
    end

    local cman = aiBrain.cmanager
    local factorySpend = cman.categoryspend.fact[uType] - cman.categoryspend.fact[upgradeType]
    local availableIncome = math.max(cman.income.r.m, 0.1)
    local currentRatio = factorySpend / math.max(availableIncome, 0.1)
    local mStored = GetEconomyStored(aiBrain, 'MASS')
    local eStored = GetEconomyStored(aiBrain, 'ENERGY')
    local isSpamLandException = (uType == 'Land' and aiBrain.BrainIntel.PlayerRole.SpamPlayer and mStored > 100)

    -- If we are over our allocated budget, stop here
    if currentRatio >= productionRatio and not isSpamLandException then
        --LOG('Ratio is false, our current mass stored is '..tostring(GetEconomyStored(aiBrain, 'MASS')..' enemy stored is '..tostring(GetEconomyStored(aiBrain, 'ENERGY'))))
        return false 
    end

    -- 2. Immediate Overrides
    if noStorageCheck or fmgr.NoStoragePriority then
        return true
    end

    if uType == 'Land' then
        -- Spam players ignore storage constraints for land units
        if aiBrain.BrainIntel.PlayerRole.SpamPlayer then 
            return true 
        end
        
        -- Stricter requirements if the AI is being choked/contained
        if aiBrain.EnemyIntel.ChokeFlag then
            if GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.10 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.95 then
                return true
            end
        end
        
        -- Standard Land Floor
        if mStored >= 5 and eStored >= 100 then
            return true
        end
    elseif uType == 'Air' then
        -- High energy buffer for Air to prevent T3/Exp Air from stalling the grid
        if mStored >= 5 and eStored >= 1000 then
            return true

        end
    else
        -- Naval/Other
        if mStored >= 5 and eStored >= 500 then
            return true
        end
    end
    return false
end

function NavalAssistControlRNG(aiBrain, MassEfficiency, EnergyEfficiency, locationType, threatType)
    -- Used to try and get the engineer assist to work at the correct times.
    if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= MassEfficiency and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --RNGLOG('Naval Assist GreaterThanEconEfficiencyOverTime Returned True')
        return true
    elseif aiBrain.BaseMonitor.AlertSounded and (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 0.7 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 0.9) then
        if threatType == 'NAVAL' and aiBrain.BasePerimeterMonitor[locationType].NavalUnits > 0 then
            --RNGLOG('Naval Assist Alert sounded and GreaterThanEconEfficiencyOverTime Returned True')
            return true
        end
    end
    return false
end

function MinimumPowerRequired(aiBrain, trend)
    local energyIncome = aiBrain.EconomyOverTimeCurrent.EnergyIncome * 10
    if energyIncome < aiBrain.EcoManager.MinimumPowerRequired then
        return true
    end
    local energyTrend = aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime
    if energyTrend < trend then
        return true
    end
    return false
end

function LateGamePowerScale(aiBrain)
    local energyIncome = GetEconomyIncome(aiBrain, 'ENERGY')
    local massIncome = GetEconomyIncome(aiBrain, 'MASS')

    if massIncome * 4 < energyIncome then
        return true
    end

end

--- Returns true if the AI can afford to start a new high-drain project without stalling production.
---@param aiBrain AIBrain
---@param projectMassDrain number The expected mass-per-second drain of the construction project.
---@return boolean
function CanAffordLuxuryProject(aiBrain, projectMassDrain)
    local econ = aiBrain.EconomyAllocation

    -- Do not start new luxuries if the budget is already redlining.
    if econ.ConstructionBudgetStatus == 'Blocked' then
        return false
    end

    return true
end
    
