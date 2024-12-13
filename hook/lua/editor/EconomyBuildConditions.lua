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

function LessThanEnergyTrendCombinedRNG(aiBrain, EnergyTrend)

    if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime < EnergyTrend then
        if GetEconomyTrend(aiBrain, 'ENERGY') < EnergyTrend then
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


function MassIncomeToFactoryRNG(aiBrain, compareType, factoryDrain, requireBuilt, baseName)

    local factoryList = aiBrain:GetListOfUnits(categories.STRUCTURE * categories.FACTORY)
    local t1LandFactories = 0
    local t2LandFactories = 0
    local t3LandFactories = 0
    local t1AirFactories = 0
    local t2AirFactories = 0
    local t3AirFactories = 0
    local t1NavalFactories = 0
    local t2NavalFactories = 0
    local t3NavalFactories = 0

    for _, v in factoryList do
        if requireBuilt and v:GetFractionComplete() ~= 1 then
            continue
        end
        if v.Blueprint.CategoriesHash.TECH1 then
            if v.Blueprint.CategoriesHash.LAND then
                t1LandFactories = t1LandFactories + 1
            elseif v.Blueprint.CategoriesHash.AIR then
                t1AirFactories = t1AirFactories + 1
            elseif v.Blueprint.CategoriesHash.NAVAL then
                t1NavalFactories = t1NavalFactories + 1
            end
        elseif v.Blueprint.CategoriesHash.TECH2 then
            if v.Blueprint.CategoriesHash.LAND then
                t2LandFactories = t2LandFactories + 1
            elseif v.Blueprint.CategoriesHash.AIR then
                t2AirFactories = t2AirFactories + 1
            elseif v.Blueprint.CategoriesHash.NAVAL then
                t2NavalFactories = t2NavalFactories + 1
            end
        elseif v.Blueprint.CategoriesHash.TECH3 then
            if v.Blueprint.CategoriesHash.LAND then
                t3LandFactories = t3LandFactories + 1
            elseif v.Blueprint.CategoriesHash.AIR then
                t3AirFactories = t3AirFactories + 1
            elseif v.Blueprint.CategoriesHash.NAVAL then
                t3NavalFactories = t3NavalFactories + 1
            end
        end
    end
    --RNGLOG('T1 Land Factories '..t1LandFactories)
    --RNGLOG('T2 Land Factories '..t2LandFactories)
    --RNGLOG('T3 Land Factories '..t3LandFactories)
    --RNGLOG('T1 Air Factories '..t1AirFactories)
    --RNGLOG('T2 Air Factories '..t2AirFactories)
    --RNGLOG('T3 Air Factories '..t3AirFactories)
    --RNGLOG('T1 Naval Factories '..t1NavalFactories)
    --RNGLOG('T2 Naval Factories '..t2NavalFactories)
    --RNGLOG('T3 Naval Factories '..t3NavalFactories)

    local massTotal = (t1LandFactories * factoryDrain.t1LandDrain) + (t2LandFactories * factoryDrain.t2LandDrain) + (t3LandFactories * factoryDrain.t3LandDrain)
    --RNGLOG('massTotal land '..massTotal)
    massTotal = massTotal + (t1AirFactories * factoryDrain.t1AirDrain) + (t2AirFactories * factoryDrain.t2AirDrain) + (t3AirFactories * factoryDrain.t3AirDrain)
    --RNGLOG('massTotal air '..massTotal)
    massTotal = massTotal + (t1NavalFactories * factoryDrain.t1NavalDrain) + (t2NavalFactories * factoryDrain.t2NavalDrain) + (t3NavalFactories * factoryDrain.t3NavalDrain)
    --RNGLOG('massTotal naval '..massTotal)
    
    -- T4 Test
    local unitCount = aiBrain:GetEngineerManagerUnitsBeingBuilt(categories.EXPERIMENTAL + (categories.STRATEGIC * categories.TECH3))
    massTotal = massTotal + (unitCount * 40)

    aiBrain.EcoManager.ApproxFactoryMassConsumption = massTotal
    if not CompareBody((aiBrain.EconomyOverTimeCurrent.MassIncome * 10), massTotal, compareType) then
        --RNGLOG('Mass to factory ratio false, mass consumption is '..massTotal)
        return false
    end
    return true
end

function ZoneBasedFactoryToMassSupported(aiBrain, locationType, layer, requireBuilt)
    local manager = aiBrain.BuilderManagers[locationType]
    if not manager.FactoryManager then
        WARN('*AI WARNING: No Factory Manager at location - ' .. locationType)
        return false
    end
    local ecoMultiplier = 1.0
    if aiBrain.CheatEnabled then 
        ecoMultiplier = aiBrain.EcoManager.EcoMultiplier
    end
    local baseLocation = manager.Position or aiBrain.BrainIntel.StartPos
    local pathableZones = manager.PathableZones
    local expansionSize = math.min((aiBrain.MapDimension / 2), 160)
    local index = aiBrain:GetArmyIndex()
    local resourceCount = 0
    local massSpendTotal = 0
    local zoneBasedIncome = 0
    local locationZone = aiBrain.BuilderManagers[locationType].Zone
    local highValue = 1
    local landZones = aiBrain.Zones.Land.zones
    if landZones[locationZone].teamvalue and landZones[locationZone].teamvalue < 1 then
        highValue = 2 - landZones[locationZone].teamvalue
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
                        if z.zoneincome then
                            zoneBasedIncome = zoneBasedIncome + z.zoneincome
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
            for _, v in manager.FactoryManager.FactoryList do
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
            massSpendTotal = (t1NavalFactories * factoryDrain.t1NavalDrain) + (t2NavalFactories * factoryDrain.t2NavalDrain) + (t3NavalFactories * factoryDrain.t3NavalDrain)
        end


        local mexSpend = (aiBrain.cmanager.categoryspend.mex.T1 + aiBrain.cmanager.categoryspend.mex.T2 + aiBrain.cmanager.categoryspend.mex.T3) or 0
        local rawIncome
        if locationType == 'MAIN' then
            rawIncome = ( aiBrain.cmanager.income.r.m - mexSpend * 0.5) or 0
        elseif manager.Layer == 'Water' then
            rawIncome = ( aiBrain.cmanager.income.r.m - (mexSpend * 0.5)) or 0
        else
            rawIncome = zoneBasedIncome * highValue
        end
         
        local availableResources = math.max(resourceCount * 2, rawIncome)
        --LOG('Zone based factory spend availability for location '..tostring(locationType))
        --LOG('massSpendTotal '..tostring(massSpendTotal))
        --LOG('mexSpend '..tostring(mexSpend))
        --LOG('rawIncome '..tostring(rawIncome))
        --LOG('resourceBased income potential '..tostring(resourceCount * 2))
        --LOG('availableResources '..tostring(availableResources))
        --LOG('Current ratio '..tostring(massSpendTotal / availableResources))
        --LOG('Expected ratio '..tostring(aiBrain.ProductionRatios[layer]))
        if massSpendTotal / availableResources < aiBrain.ProductionRatios[layer] then
            return true
        end
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

function GreaterThanMassToFactoryRatioBaseCheckRNG(aiBrain, locationType, requireBuilt)
    local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
    if not factoryManager then
        WARN('*AI WARNING: FactoryCapCheck - Invalid location - ' .. locationType)
        return false
    end
    --RNGLOG('Location Type '..locationType)

    local factoryDrain = {}
    local massToFactoryValues = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues
    local ecoMultiplier = aiBrain.EcoManager.EcoMultiplier
    if aiBrain.CheatEnabled then
        factoryDrain.t1LandDrain = (massToFactoryValues.T1LandValue or 8) * ecoMultiplier
        factoryDrain.t2LandDrain = (massToFactoryValues.T2LandValue or 20) * ecoMultiplier
        factoryDrain.t3LandDrain = (massToFactoryValues.T3LandValue or 30) * ecoMultiplier
        factoryDrain.t1AirDrain = (massToFactoryValues.T1AirValue or 8) * ecoMultiplier
        factoryDrain.t2AirDrain = (massToFactoryValues.T2AirValue or 20) * ecoMultiplier
        factoryDrain.t3AirDrain = (massToFactoryValues.T3AirValue or 30) * ecoMultiplier
        factoryDrain.t1NavalDrain = (massToFactoryValues.T1NavalValue or 8) * ecoMultiplier
        factoryDrain.t2NavalDrain = (massToFactoryValues.T2NavalValue or 20) * ecoMultiplier
        factoryDrain.t3NavalDrain = (massToFactoryValues.T3NavalValue or 30) * ecoMultiplier
    else
        factoryDrain.t1LandDrain = massToFactoryValues.T1LandValue or 8
        factoryDrain.t2LandDrain = massToFactoryValues.T2LandValue or 20
        factoryDrain.t3LandDrain = massToFactoryValues.T3LandValue or 30
        factoryDrain.t1AirDrain = massToFactoryValues.T1AirValue or 8
        factoryDrain.t2AirDrain = massToFactoryValues.T2AirValue or 20
        factoryDrain.t3AirDrain = massToFactoryValues.T3AirValue or 30
        factoryDrain.t1NavalDrain = massToFactoryValues.T1NavalValue or 8
        factoryDrain.t2NavalDrain = massToFactoryValues.T2NavalValue or 20
        factoryDrain.t3NavalDrain = massToFactoryValues.T3NavalValue or 30
    end
    --RNGLOG('Total Factory Drain '..repr(factoryDrain))

    return MassIncomeToFactoryRNG(aiBrain,'>', factoryDrain, requireBuilt, locationType)
end

function LessThanMassToFactoryRatioBaseCheckRNG(aiBrain, locationType,requireBuilt)
    local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
    if not factoryManager then
        WARN('*AI WARNING: FactoryCapCheck - Invalid location - ' .. locationType)
        return false
    end
    --RNGLOG('Location Type '..locationType)

    local factoryDrain = {}
    local massToFactoryValues = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues
    local ecoMultiplier = aiBrain.EcoManager.EcoMultiplier
    if aiBrain.CheatEnabled then
        factoryDrain.t1LandDrain = (massToFactoryValues.T1LandValue or 8) * ecoMultiplier
        factoryDrain.t2LandDrain = (massToFactoryValues.T2LandValue or 20) * ecoMultiplier
        factoryDrain.t3LandDrain = (massToFactoryValues.T3LandValue or 30) * ecoMultiplier
        factoryDrain.t1AirDrain = (massToFactoryValues.T1AirValue or 8) * ecoMultiplier
        factoryDrain.t2AirDrain = (massToFactoryValues.T2AirValue or 20) * ecoMultiplier
        factoryDrain.t3AirDrain = (massToFactoryValues.T3AirValue or 30) * ecoMultiplier
        factoryDrain.t1NavalDrain = (massToFactoryValues.T1NavalValue or 8) * ecoMultiplier
        factoryDrain.t2NavalDrain = (massToFactoryValues.T2NavalValue or 20) * ecoMultiplier
        factoryDrain.t3NavalDrain = (massToFactoryValues.T3NavalValue or 30) * ecoMultiplier
    else
        factoryDrain.t1LandDrain = massToFactoryValues.T1LandValue or 8
        factoryDrain.t2LandDrain = massToFactoryValues.T2LandValue or 20
        factoryDrain.t3LandDrain = massToFactoryValues.T3LandValue or 30
        factoryDrain.t1AirDrain = massToFactoryValues.T1AirValue or 8
        factoryDrain.t2AirDrain = massToFactoryValues.T2AirValue or 20
        factoryDrain.t3AirDrain = massToFactoryValues.T3AirValue or 30
        factoryDrain.t1NavalDrain = massToFactoryValues.T1NavalValue or 8
        factoryDrain.t2NavalDrain = massToFactoryValues.T2NavalValue or 20
        factoryDrain.t3NavalDrain = massToFactoryValues.T3NavalValue or 30
    end
    --RNGLOG('Total Factory Drain '..repr(factoryDrain))

    return MassIncomeToFactoryRNG(aiBrain,'<', factoryDrain, requireBuilt)
end

function FactorySpendRatioRNG(aiBrain,uType,upgradeType, noStorageCheck)
    local mexSpend = (aiBrain.cmanager.categoryspend.mex.T1 + aiBrain.cmanager.categoryspend.mex.T2 + aiBrain.cmanager.categoryspend.mex.T3) or 0
    local currentFactorySpend = aiBrain.cmanager.categoryspend.fact[uType] - aiBrain.cmanager.categoryspend.fact[upgradeType]
    if currentFactorySpend / ( aiBrain.cmanager.income.r.m - (mexSpend * 0.5)) < aiBrain.ProductionRatios[uType] then
        if aiBrain.EnemyIntel.ChokeFlag and uType == 'Land' then 
            if (GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.10 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.95) then
                return true
            end
        elseif noStorageCheck then
            return true
        elseif uType == 'Air' then
            if (GetEconomyStored(aiBrain, 'MASS') >= 5 and GetEconomyStored(aiBrain, 'ENERGY') >= 1000) then
                return true
            end
        elseif uType == 'Land' then
            if GetEconomyStored(aiBrain, 'MASS') >= 5 and GetEconomyStored(aiBrain, 'ENERGY') >= 100 or aiBrain.BrainIntel.SpamPlayer then
                return true
            end
        else
            if GetEconomyStored(aiBrain, 'MASS') >= 5 and GetEconomyStored(aiBrain, 'ENERGY') >= 500 then
                return true
            end
        end
    end
    --[[
    if uType == 'Land' then
        LOG('Land factory spend is returning false so not enough funding')
        LOG('Current spend ration is '..tostring(currentFactorySpend / ( aiBrain.cmanager.income.r.m - mexSpend ) < aiBrain.ProductionRatios[uType]))
        LOG('Ratio without mex spend is  '..tostring(currentFactorySpend / ( aiBrain.cmanager.income.r.m ) < aiBrain.ProductionRatios[uType]))
        LOG('Production ratio is '..tostring(aiBrain.ProductionRatios[uType]))
    end]]
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

    
