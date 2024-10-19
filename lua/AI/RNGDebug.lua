RNGLOG = function(data)
    LOG(data)
end

DrawReclaimGrid = function()

    coroutine.yield(50)
    --LOG('RNG Mapping Class Playable Area is '..repr(import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua'.GetPlayableArea()))
    -- by default, 16x16 iMAP
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local n = 16 
    local mx = ScenarioInfo.size[1]
    local mz = ScenarioInfo.size[2]


    -- smaller maps have a 8x8 iMAP
    if mx == mz and mx == 5 then 
        n = 8
    end

    local color = "ffffff"
    local a = Vector(0, 0, 0)
    local b = Vector(0, 0, 0)
    local GetTerrainHeight = GetTerrainHeight
    local DrawLine = DrawLine 

    local function Line(x1, z1, x2, z2, color)
        a[1] = x1
        a[3] = z1
        a[2] = GetTerrainHeight(x1, z1)

        b[1] = x2 
        b[3] = z2
        b[2] = GetTerrainHeight(x2, z2)
        DrawLine(a, b, color)
    end
    while true do 

        -- distance per cell
        local fx = 1 / n * mx 
        local fz = 1 / n * mz 
        -- draw iMAP information
        for z = 1, n do 
            for x = 1, n do 
                -- draw cell
                Line(fx * (x - 1), fz * (z - 1), fx * (x - 0), fz * (z - 1), color)
                Line(fx * (x - 1), fz * (z - 1), fx * (x - 1), fz * (z - 0), color)
                Line(fx * (x - 0), fz * (z - 0), fx * (x - 0), fz * (z - 1), color)
                Line(fx * (x - 0), fz * (z - 0), fx * (x - 1), fz * (z - 0), color)
                local cx = fx * (x - 0.5)
                local cz = fz * (z - 0.5)
                if cx < playableArea[1] or cz < playableArea[2] or cx > playableArea[3] or cz > playableArea[4] then
                    continue
                end
                DrawCircle({cx, GetTerrainHeight(cx, cz), cz}, 10, '0000FF')
                a[1] = cx 
                a[2] = GetTerrainHeight(cx, cz)
                a[3] = cz
            end
        end
        WaitTicks(2)
    end
end

DrawIntelGrid = function()

    coroutine.yield(100)
    --LOG('RNG Mapping Class Playable Area is '..repr(import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua'.GetPlayableArea()))
    -- by default, 16x16 iMAP
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local n = 16 
    local mx = ScenarioInfo.size[1]
    local mz = ScenarioInfo.size[2]


    -- smaller maps have a 8x8 iMAP
    if mx == mz and mx == 256 then 
        n = 8
    end

    local color = "ffffff"
    local a = Vector(0, 0, 0)
    local b = Vector(0, 0, 0)
    local GetTerrainHeight = GetTerrainHeight
    local DrawLine = DrawLine 

    local function Line(x1, z1, x2, z2, color)
        a[1] = x1
        a[3] = z1
        a[2] = GetTerrainHeight(x1, z1)

        b[1] = x2 
        b[3] = z2
        b[2] = GetTerrainHeight(x2, z2)
        DrawLine(a, b, color)
    end
    local im = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua').GetIntelManager()
    while true do 
        -- draw iMAP information
        for _, v in im.MapIntelGrid do 
            for _, c in v do 
                if c.Enabled then
                    --RNGLOG('MapIntelGrid '..repr(c))
                    DrawLine({c.Position[1]-c.Size.sx/2, c.Position[2], c.Position[3]-c.Size.sz/2}, {c.Position[1]+c.Size.sx/2, c.Position[2], c.Position[3]-c.Size.sz/2}, 'FFA500')
                    DrawLine({c.Position[1]-c.Size.sx/2, c.Position[2], c.Position[3]-c.Size.sz/2}, {c.Position[1]-c.Size.sx/2, c.Position[2], c.Position[3]+c.Size.sz/2}, 'FFA500')
                    --DrawCircle(c.Position, 10, '0000FF')
                    --Line(c.Position[1] - (c.Size.sx / 2), c.Position[3] - (c.Size.sz / 2), c.Position[1] + (c.Size.sx / 2), c.Position[3] + (c.Size.sz / 2), "ffffff")
                    --local rect = Rect(c.Position[1] - (c.Size.sx / 2), c.Position[3] - (c.Size.sz / 2), c.Position[1] + (c.Size.sx / 2), c.Position[3] + (c.Size.sz / 2))
                    --RNGLOG('rect '..repr(rect))
                end
            end

            --DrawCircle({cx, GetTerrainHeight(cx, cz), cz}, 10, '0000FF')
        end
        WaitTicks(2)
    end
end