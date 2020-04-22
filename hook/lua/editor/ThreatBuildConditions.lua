--[[
    File    :   /lua/AI/AIBaseTemplates/ThreatBuildConditions.lua
    Author  :   relentless
    Summary :
        Threat Build Conditions
]]
local MAPBASEPOSTITIONSRNG = {}

function EnemyThreatGreaterThanValueAtBaseRNG(aiBrain, locationType, threatValue, threatType, rings, builder)
    local testRings = rings or 10
    local AIName = ArmyBrains[aiBrain:GetArmyIndex()].Nickname
    local baseposition, radius
    if MAPBASEPOSTITIONSRNG[AIName][locationType] then
        baseposition = MAPBASEPOSTITIONSRNG[AIName][locationType].Pos
        radius = MAPBASEPOSTITIONSRNG[AIName][locationType].Rad
    elseif aiBrain.BuilderManagers[locationType] then
        baseposition = aiBrain.BuilderManagers[locationType].FactoryManager.Location
        radius = aiBrain.BuilderManagers[locationType].FactoryManager:GetLocationRadius()
        MAPBASEPOSTITIONSRNG[AIName] = MAPBASEPOSTITIONSRNG[AIName] or {} 
        MAPBASEPOSTITIONSRNG[AIName][locationType] = {Pos=baseposition, Rad=radius}
    elseif aiBrain:PBMHasPlatoonList() then
        for k,v in aiBrain.PBM.Locations do
            if v.LocationType == locationType then
                baseposition = v.Location
                radius = v.Radius
                MAPBASEPOSTITIONSRNG[AIName] = MAPBASEPOSTITIONSRNG[AIName] or {} 
                MAPBASEPOSTITIONSRNG[AIName][locationType] = {baseposition, radius}
                break
            end
        end
    end
    if not baseposition then
        return false
    end
    currentThreat = aiBrain:GetThreatAtPosition( baseposition, testRings, true, threatType or 'Overall' )
    --LOG('Threat Value Detected :'..currentThreat..'Threat Value Desired'..threatValue)
    if currentThreat > threatValue then
        --LOG('EnemyThreatGreaterThanValueAtBase returning true for : ', builder)
        return true
    end
    --LOG('EnemyThreatGreaterThanValueAtBase returning false for : ', builder)
    return false
end

-- not in use
function EnemyThreatGreaterThanAI(aiBrain, threatType)
    local enemyThreat
    local aiThreat
    if threatType == 'Air' then
        enemyThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Air
        aiThreat = aiBrain.BrainIntel.SelfThreat.Air
    elseif threatType == 'Land' then
        enemyThreat = aiBrain.EnemyIntel.EnemyThreatCurrent.Land
        aiThreat = aiBrain.BrainIntel.SelfThreat.Land
    end
    if enemyThreat > aiThreat then
        return true
    else
        return false
    end
    return false
end