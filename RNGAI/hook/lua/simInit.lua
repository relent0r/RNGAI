local RNGAIBeginSessionFunction = BeginSession

function BeginSession()
    RNGAIBeginSessionFunction()
    if ScenarioInfo.Options.AIThreatDisplay ~= 'threatOff' then
        ForkThread(DrawIMAPThreatsRNG)
    end
end

function DrawIMAPThreatsRNG()
    coroutine.yield(100)
    --LOG('Starting IMAP Threat Thread')
    local MCountX = 48
    local MCountY = 48
    local PosX
    local PosY
    local enemyThreat
    -- Playable area
    local playablearea
    if  ScenarioInfo.MapData.PlayableRect then
        playablearea = ScenarioInfo.MapData.PlayableRect
    else
        playablearea = {0, 0, ScenarioInfo.size[1], ScenarioInfo.size[2]}
    end
    while true do
        local FocussedArmy = GetFocusArmy()
        for ArmyIndex, aiBrain in ArmyBrains do
            -- only draw the pathcache from the focussed army
            if FocussedArmy ~= ArmyIndex then
                continue
            end
            local DistanceBetweenMarkers = ScenarioInfo.size[1] / ( MCountX )
            for Y = 0, MCountY - 1 do
                for X = 0, MCountX - 1 do
                    PosX = X * DistanceBetweenMarkers + DistanceBetweenMarkers / 2
                    PosY = Y * DistanceBetweenMarkers + DistanceBetweenMarkers / 2

                    enemyThreat = aiBrain:GetThreatAtPosition({PosX, 0, PosY}, 0, true, 'AntiSurface')
                    DrawCircle({PosX, 0, PosY}, (enemyThreat / 120) + 0.1, 'ffff0000' ) -- red

                    enemyThreat = aiBrain:GetThreatAtPosition({PosX, 0, PosY}, 0, true, 'Air')
                    DrawCircle({PosX, 0, PosY}, (enemyThreat / 120) + 0.1, 'ffffff00' ) -- yellow

                    enemyThreat = aiBrain:GetThreatAtPosition({PosX, 0, PosY}, 0, true, 'Land')
                    DrawCircle({PosX, 0, PosY}, (enemyThreat / 120) + 0.1, 'ffff9600' ) -- orange

                    enemyThreat = aiBrain:GetThreatAtPosition({PosX, 0, PosY}, 0, true, 'Naval')
                    DrawCircle({PosX, 0, PosY}, (enemyThreat / 120) + 0.1, 'ff00ffff' ) -- cyan
                end
            end        
        end
        coroutine.yield(2)
    end
end