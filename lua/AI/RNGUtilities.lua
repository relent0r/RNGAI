local AIUtils = import('/lua/ai/AIUtilities.lua')

function ReclaimRNGAIThread(platoon,self,aiBrain)
    -- Caution this is extremely barebones and probably will break stuff or reclaim stuff it shouldn't
    LOG('Start Reclaim Function')
    IssueClearCommands({self})
    local locationType = self.PlatoonData.LocationType
    local initialRange = 40
    local furtherestReclaim = nil
    local closestReclaim = nil
    local closestDistance = 10000
    local furtherestDistance = 0
    local createTick = GetGameTick()

    self.BadReclaimables = self.BadReclaimables or {}

    while aiBrain:PlatoonExists(platoon) and self and not self.Dead do
        local engPos = self:GetPosition()
        local x1 = engPos[1] - initialRange
        local x2 = engPos[1] + initialRange
        local z1 = engPos[3] - initialRange
        local z2 = engPos[3] + initialRange
        local rect = Rect(x1, z1, x2, z2)
        local reclaimRect = GetReclaimablesInRect(rect)

        if not engPos then
            WaitTicks(1)
            return
        end

        local reclaim = {}
        local needEnergy = aiBrain:GetEconomyStoredRatio('ENERGY') < 0.5
        LOG('Going through reclaim table')
        if reclaimRect and table.getn( reclaimRect ) > 0 then
            for k,v in reclaimRect do
                --LOG(repr(v))
                if not IsProp(v) or self.BadReclaimables[v] then continue end
                if not needEnergy or v.MaxEnergyReclaim then
                    if not self.BadReclaimables[v] then
                        local rpos = v:GetCachePosition()
                        local distance = VDist2(engPos[1], engPos[3], rpos[1], rpos[3])
                        if distance < closestDistance then
                            closestReclaim = rpos
                            closestDistance = distance
                        end
                        if distance > furtherestDistance then -- and distance < closestDistance + 20
                            furtherestReclaim = rpos
                            furtherestDistance = distance
                        end
                    end
                end
            end
        end
        if self.Dead then 
            return
        end
        LOG('Closest Distance is : '..closestDistance..'Furtherest Distance is :'..furtherestDistance)
        -- Clear Commands first
        IssueClearCommands({self})
        LOG('Attempting move to closest reclaim')
        StartMoveDestination(self, closestReclaim)
        LOG('Closest reclaim is '..closestReclaim[1]..' '..closestReclaim[3])
        local brokenDistance = closestDistance / 6
        LOG('One 6th of distance is '..brokenDistance)
        local moveWait = 0
        while VDist2(engPos[1], engPos[3], closestReclaim[1], closestReclaim[3]) > brokenDistance do
            LOG('Waiting for engineer to get close, current distance : '..VDist2(engPos[1], engPos[3], closestReclaim[1], closestReclaim[3])..'closestDistance'..closestDistance)
            WaitSeconds(2)
            moveWait = moveWait + 1
            engPos = self:GetPosition()
            if moveWait == 10 then
                break
            end
        end
        LOG('Attempting agressive move to furtherest reclaim')
        -- Clear Commands first
        IssueClearCommands({self})
        IssueAggressiveMove({self}, furtherestReclaim)
        local reclaiming = not self:IsIdleState()
        local max_time = platoon.PlatoonData.ReclaimTime
        while reclaiming do
            LOG('Engineer is reclaiming')
            WaitSeconds(max_time)
           if self:IsIdleState() or (max_time and (GetGameTick() - createTick)*10 > max_time) then
                LOG('Engineer no longer reclaiming')
                reclaiming = false
            end
        end
        local basePosition = aiBrain.BuilderManagers['MAIN'].Position
        LOG('Base Location is : '..basePosition[1]..' '..basePosition[3])
        local location = AIUtils.RandomLocation(basePosition[1],basePosition[3])
        LOG('Random Location is :'..location[1]..' '..location[3])
        IssueClearCommands({self})
        StartMoveDestination(self, location)
        WaitSeconds(5)
    end
end

function StartMoveDestination(self,destination)
    local NowPosition = self:GetPosition()
    local x, z, y = unpack(self:GetPosition())
    local count = 0
    IssueClearCommands({self})
    while x == NowPosition[1] and y == NowPosition[3] and count < 20 do
        count = count + 1
        IssueClearCommands({self})
        IssueMove( {self}, destination )
        WaitTicks(10)
    end
end
-- Get the military operational areas of the map
function GetMOARadii(bool)
    -- Military area is slightly less than half the map size (10x10map) or maximal 200.
    local BaseMilitaryArea = math.max( ScenarioInfo.size[1]-50, ScenarioInfo.size[2]-50 ) / 2.2
    BaseMilitaryArea = math.max( 180, BaseMilitaryArea )
    local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
    -- Restricted Area is half the BaseMilitaryArea. That's a little less than 1/4 of a 10x10 map
    local BaseRestrictedArea = BaseMilitaryArea / 2
    -- Make sure the Panic Area is not smaller than 50 or greater than 100
    BaseRestrictedArea = math.max( 50, BaseRestrictedArea )
    BaseRestrictedArea = math.min( 100, BaseRestrictedArea )
    -- The rest of the map is enemy area
    local BaseEnemyArea = math.max( ScenarioInfo.size[1], ScenarioInfo.size[2] ) * 1.5
    -- "bool" is only true if called from "AIBuilders/Mobile Land.lua", so we only print this once.
    if bool then
        LOG('* RNGAI: BaseRestrictedArea= '..math.floor( BaseRestrictedArea * 0.01953125 ) ..' Km - ('..BaseRestrictedArea..' units)' )
        LOG('* RNGAI: BaseMilitaryArea= '..math.floor( BaseMilitaryArea * 0.01953125 )..' Km - ('..BaseMilitaryArea..' units)' )
        LOG('* RNGAI: BaseDMZArea= '..math.floor( BaseDMZArea * 0.01953125 )..' Km - ('..BaseDMZArea..' units)' )
        LOG('* RNGAI: BaseEnemyArea= '..math.floor( BaseEnemyArea * 0.01953125 )..' Km - ('..BaseEnemyArea..' units)' )
    end
    return BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea
end