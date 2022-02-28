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
    elseif aiBrain.UpgradeMode == 'Aggressive' then
        if GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio * 1.5 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
            return true
        end
    elseif mult == true then
        if GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio * aiBrain.EcoManager.EcoMultiplier and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
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
    --RNGLOG('Mass Wanted :'..MassEfficiency..'Actual :'..aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime)
    if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= MassEfficiency and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --RNGLOG('GreaterThanEconEfficiencyOverTime passed True')
        local EnergyEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
        local MassEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
        --RNGLOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
        if (MassEfficiencyOverTime >= MassEfficiency and EnergyEfficiencyOverTime >= EnergyEfficiency) then
            return true
        end
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
        LOG('PreEmptive Power Check is true')
        return true
    end
    if aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime < EnergyTrend then
        if GetEconomyTrend(aiBrain, 'ENERGY') < EnergyTrend then
            return true
        end
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

function GreaterThanMassIncomeToFactoryRNG(aiBrain, t1Drain, t2Drain, t3Drain)

    # T1 Test
    local testCat = categories.TECH1 * categories.FACTORY
    local unitCount = aiBrain:GetCurrentUnits(testCat)
    # Find units of this type being built or about to be built
    unitCount = unitCount + aiBrain:GetEngineerManagerUnitsBeingBuilt((categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.FACTORY)

    local massTotal = unitCount * t1Drain

    # T2 Test
    testCat = categories.TECH2 * categories.FACTORY
    unitCount = aiBrain:GetCurrentUnits(testCat)

    massTotal = massTotal + (unitCount * t2Drain)

    # T3 Test
    testCat = categories.TECH3 * categories.FACTORY
    unitCount = aiBrain:GetCurrentUnits(testCat)

    massTotal = massTotal + (unitCount * t3Drain)

    if not CompareBody((aiBrain.EconomyOverTimeCurrent.MassIncome * 10), massTotal, '>') then
        --RNGLOG('MassToFactoryRatio false')
        --RNGLOG('aiBrain.EconomyOverTimeCurrent.MassIncome * 10 : '..(aiBrain.EconomyOverTimeCurrent.MassIncome * 10))
        --RNGLOG('Factory massTotal : '..massTotal)
        return false
    end
    --RNGLOG('MassToFactoryRatio true')
    --RNGLOG('aiBrain.EconomyOverTimeCurrent.MassIncome * 10 : '..(aiBrain.EconomyOverTimeCurrent.MassIncome * 10))
    --RNGLOG('Factory massTotal : '..massTotal)
    return true
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

function MassToFactoryRatioBaseCheckRNG(aiBrain, locationType)
    local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
    if not factoryManager then
        WARN('*AI WARNING: FactoryCapCheck - Invalid location - ' .. locationType)
        return false
    end

    local t1
    local t2
    local t3
    if aiBrain.CheatEnabled then
        t1 = (aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T1Value or 8) * tonumber(ScenarioInfo.Options.BuildMult)
        t2 = (aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T2Value or 20) * tonumber(ScenarioInfo.Options.BuildMult)
        t3 = (aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T3Value or 30) * tonumber(ScenarioInfo.Options.BuildMult)
    else
        t1 = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T1Value or 8
        t2 = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T2Value or 20
        t3 = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T3Value or 30
    end

    return GreaterThanMassIncomeToFactoryRNG(aiBrain, t1, t2, t3)
end

function FactorySpendRatioRNG(aiBrain,uType, noStorageCheck)
    --RNGLOG('Current Spend Ratio '..(aiBrain.cmanager.categoryspend.fact[uType] / aiBrain.cmanager.income.r.m))
    local mexSpend = (aiBrain.cmanager.categoryspend.mex.T1 + aiBrain.cmanager.categoryspend.mex.T2 + aiBrain.cmanager.categoryspend.mex.T3) or 0
    if aiBrain.cmanager.categoryspend.fact[uType] / (aiBrain.cmanager.income.r.m - mexSpend) < aiBrain.ProductionRatios[uType] then
        if aiBrain.ChokeFlag and uType == 'Land' then 
            if (GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.10 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.95) then
                return true
            end
        elseif noStorageCheck then
            return true
        elseif (GetEconomyStored(aiBrain, 'MASS') >= 20 and GetEconomyStored(aiBrain, 'ENERGY') >= 100) then
            return true
        end
    end
    return false
end
