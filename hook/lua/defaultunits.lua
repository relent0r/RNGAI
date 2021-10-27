
local RNGAIMobileUnit = MobileUnit
MobileUnit = Class(RNGAIMobileUnit) {

    OnCreate = function(self)
        local aiBrain = self:GetAIBrain()
        if not aiBrain.RNG then
            return RNGAIMobileUnit.OnCreate(self)
        end
        Unit.OnCreate(self)
        self:updateBuildRestrictions()
        self:SetFireState(FireState.RETURN_FIRE)
    end,

    OnKilled = function(self, instigator, type, overkillRatio)
        
        local aiBrain = self:GetAIBrain()
        if not aiBrain.RNG then
            return RNGAIMobileUnit.OnKilled(self, instigator, type, overkillRatio)
        end
        -- Add unit's threat to our influence map
        --[[local threat = 5
        local decay = 0.1
        local currentLayer = self.Layer
        if instigator then
            local unit = false
            if IsUnit(instigator) then
                unit = instigator
            elseif IsProjectile(instigator) or IsCollisionBeam(instigator) then
                unit = instigator.unit
            end

            if unit then
                local unitPos = unit:GetCachePosition()
                if EntityCategoryContains(categories.STRUCTURE, unit) then
                    decay = 0.01
                end

                if unitPos then
                    if currentLayer == 'Sub' then
                        threat = self:GetAIBrain():GetThreatAtPosition(unitPos, 0, true, 'AntiSub')
                    elseif currentLayer == 'Air' then
                        threat = self:GetAIBrain():GetThreatAtPosition(unitPos, 0, true, 'AntiAir')
                    else
                        threat = self:GetAIBrain():GetThreatAtPosition(unitPos, 0, true, 'AntiSurface')
                    end
                    threat = threat / 2
                end
            end
        end

        if currentLayer == 'Sub' then
            self:GetAIBrain():AssignThreatAtPosition(self:GetPosition(), threat, decay * 10, 'AntiSub')
        elseif currentLayer == 'Air' then
            self:GetAIBrain():AssignThreatAtPosition(self:GetPosition(), threat, decay, 'AntiAir')
        elseif currentLayer == 'Water' then
            self:GetAIBrain():AssignThreatAtPosition(self:GetPosition(), threat, decay * 10, 'AntiSurface')
        else
            self:GetAIBrain():AssignThreatAtPosition(self:GetPosition(), threat, decay, 'AntiSurface')
        end]]

        -- This unit was in a transport
        if self.killedInTransport then
            self.killedInTransport = false
        else
            Unit.OnKilled(self, instigator, type, overkillRatio)
        end
    end,

}