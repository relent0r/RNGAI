--[[
    File    :   /lua/AI/AIBaseTemplates/EconomyBuildConditions.lua
    Author  :   relentless
    Summary :
        Economy Build Conditions
]]

local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio

function GreaterThanEconStorageRatioRNG(aiBrain, mStorageRatio, eStorageRatio)
    local econ = {}
    econ.MassStorageRatio = GetEconomyStoredRatio(aiBrain, 'MASS')
    econ.EnergyStorageRatio = GetEconomyStoredRatio(aiBrain, 'ENERGY')
    -- If a paragon is present and we not stall mass or energy, return true
    --LOG('Mass Storage Ratio :'..econ.MassStorageRatio..' Energy Storage Ratio :'..econ.EnergyStorageRatio)
    if aiBrain.HasParagon and econ.MassStorageRatio >= 0.01 and econ.EnergyStorageRatio >= 0.01 then
        return true
    elseif econ.MassStorageRatio >= mStorageRatio and econ.EnergyStorageRatio >= eStorageRatio then
        return true
    end
    return false
end

function GreaterThanEconTrendRNG(aiBrain, MassTrend, EnergyTrend)
    local econ = {}
    econ.MassTrend = GetEconomyTrend(aiBrain, 'MASS')
    econ.EnergyTrend = GetEconomyTrend(aiBrain, 'ENERGY')
    -- If a paragon is present and we have at least a neutral m+e trend, return true
    --LOG('Current Econ Trends M E: ', econ.MassTrend, econ.EnergyTrend)
    if aiBrain.HasParagon and econ.MassTrend >= 0 and econ.EnergyTrend >= 0 then
        return true
    elseif econ.MassTrend >= MassTrend and econ.EnergyTrend >= EnergyTrend then
        return true
    end
    return false
end

function LessThanMassTrendRNG(aiBrain, mTrend)
    local econ = {}
    econ.MassTrend = GetEconomyTrend(aiBrain, 'MASS')
    if econ.MassTrend < mTrend then
        return true
    else
        return false
    end
end

--            { EBC, 'LessThanEnergyTrendRNG', { 50.0 } },
function LessThanEnergyTrendRNG(aiBrain, eTrend)
    local econ = {}
    econ.EnergyTrend = GetEconomyTrend(aiBrain, 'ENERGY')
    if econ.EnergyTrend < eTrend then
        return true
    else
        return false
    end
end

function GreaterThanEconEfficiencyOverTime(aiBrain, MassEfficiency, EnergyEfficiency)
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    --LOG('Mass Wanted :'..MassEfficiency..'Actual :'..econ.MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..econ.EnergyEfficiencyOverTime)
    if (econ.MassEfficiencyOverTime >= MassEfficiency and econ.EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --LOG('GreaterThanEconEfficiencyOverTime Returned True')
        return true
    end
    --LOG('GreaterThanEconEfficiencyOverTime Returned False')
    return false
end

function GreaterThanMassIncomeToFactory(aiBrain, t1Drain, t2Drain, t3Drain)
    local econTime = aiBrain:GetEconomyOverTime()
    
    -- T1 Test
    local testCat = categories.TECH1 * categories.FACTORY
    local unitCount = aiBrain:GetCurrentUnits( testCat )
    -- Find units of this type being built or about to be built
    unitCount = unitCount + aiBrain:GetEngineerManagerUnitsBeingBuilt(testCat)
    
    local massTotal = unitCount * t1Drain

    -- T2 Test
    testCat = categories.TECH2 * categories.FACTORY
    unitCount = aiBrain:GetCurrentUnits( testCat )
    
    massTotal = massTotal + ( unitCount * t2Drain )
    
    -- T3 Test
    testCat = categories.TECH3 * categories.FACTORY
    unitCount = aiBrain:GetCurrentUnits( testCat )

    massTotal = massTotal + ( unitCount * t3Drain )    
    
    if not CompareBody( (econTime.MassIncome * 10), massTotal, '>' ) then
        --LOG('Mass income to factory is false')
        return false
    end
    --LOG('Mass income to factory is true')
    return true
end
