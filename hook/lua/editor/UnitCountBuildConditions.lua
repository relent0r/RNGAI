
-- hook for additional build conditions used from AIBuilders

--{ UCBC, 'ReturnTrue', {} },
function ReturnTrue(aiBrain)
    LOG('** true')
    return true
end

--{ UCBC, 'ReturnFalse', {} },
function ReturnFalse(aiBrain)
    LOG('** false')
    return false
end

function LessThanGameTimeSeconds(aiBrain, num)
    if num > GetGameTimeSeconds() then
        return true
    end
    return false
end