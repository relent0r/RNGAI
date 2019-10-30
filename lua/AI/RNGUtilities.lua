local AIUtils = import('/lua/ai/AIUtilities.lua')

function ReclaimRNGAIThread(platoon,self,aiBrain)
    -- Caution this is extremely barebones and probably will break stuff or reclaim stuff it shouldn't
    LOG('Start Reclaim Function')
    IssueClearCommands({self})
    local locationType = self.PlatoonData.LocationType
    local initialRange = 40
    local furtherestReclaim = 0
    local closestReclaim = 10000
    local closestDistance = 0
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
                if not IsProp(v) or self.BadReclaimables[v] then continue end
                if not needEnergy or v.MaxEnergyReclaim then
                    if not self.BadReclaimables[v.entity] then
                        local rpos = v:GetCachePosition()
                        local distance = VDist2(engPos[1], engPos[3], rpos[1], rpos[3])
                        if distance > furtherestReclaim then
                            furtherestReclaim = rpos
                        end
                        if distance < closestReclaim then
                            closestReclaim = rpos
                            closestDistance = distance
                        end
                    end
                end
            end
        end
        if self.Dead then 
            return
        end
        -- Clear Commands first
        IssueClearCommands({self})
        LOG('Attempting move to closest reclaim')
        StartMoveDestination(self, closestReclaim)
        LOG('Closest reclaim is '..closestReclaim[1]..' '..closestReclaim[3])
        local brokenDistance = closestDistance / 6
        LOG('One 6th of distance is '..brokenDistance)
        while VDist2(engPos[1], engPos[3], closestReclaim[1], closestReclaim[3]) > brokenDistance do
            LOG('Waiting for engineer to get close, current distance : '..VDist2(engPos[1], engPos[3], closestReclaim[1], closestReclaim[3])..'closestDistance'..closestDistance)
            WaitSeconds(2)
            engPos = self:GetPosition()
        end
        LOG('Attempting agressive move to furtherest reclaim')
        -- Clear Commands first
        IssueClearCommands({self})
        IssueAggressiveMove({self}, furtherestReclaim)
        local reclaiming = not self:IsIdleState()
        local max_time = platoon.PlatoonData.ReclaimTime
        while reclaiming do
            LOG('Engineer is reclaiming')
            WaitSeconds(5)
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