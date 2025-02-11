local RNGAIGLOBALS = import("/mods/RNGAI/lua/AI/RNGAIGlobals.lua")
local SimSyncUtils = import('/lua/simsyncutils.lua')
local SUtils = import("/lua/ai/sorianutilities.lua")

local tauntTable = {
    -- Note these are in order of faction index
    {
        GameStart = {
            {
                Bank = 'X06_VO',
                Cue = 'X06_Fletcher_M02_04482',
                Text = LOC('<LOC X06_M02_011_010>[{i Fletcher}]: I spent a lot of time thinking about this. There\'s only one possible outcome. One way for this to end.')
            },
            {
                Bank = 'X06_VO',
                Cue = 'X06_Fletcher_T01_03027',
                Text = LOC('<LOC X06_T01_660_010>[{i Fletcher}]: You are no better than the rest of them!')
            },
            {
                Bank = 'X01_VO',
                Cue = 'X01_Fletcher_T01_04531',
                Text = LOC('<LOC X01_T01_200_010>[{i Fletcher}]: It\'s time for this to get serious.')
            },
            {
                Bank = 'X06_VO',
                Cue = 'X06_Fletcher_T01_03043',
                Text = LOC('<LOC X06_T01_820_010>[{i Fletcher}]: You and your kind are responsible for this war.')
            }
            
        },
        LaunchNuke = {
            {
                Bank = 'X06_VO',
                Cue = 'X06_Fletcher_T01_03044',
                Text = LOC('<LOC X06_T01_830_010>[{i Fletcher}]: This war is your fault! And now you will pay.')
            },
            {
                Bank = 'X06_VO',
                Cue = 'X06_Fletcher_T01_03029',
                Text = LOC('<LOC X06_T01_680_010>[{i Fletcher}]: I thought I could trust you! You\'re a traitor.')
            },
            {
                Bank = 'X06_VO',
                Cue = 'X06_Fletcher_T01_03027',
                Text = LOC('<LOC X06_T01_660_010>[{i Fletcher}]: You are no better than the rest of them!')
            }
        }
    },
    {
        GameStart = {
            {
                Bank = 'X01_VO',
                Cue = 'X01_Gari_M02_02896',
                Text = LOC('<LOC X01_M02_013_010>[{i Gari}]: I shall cleanse everyone on this planet! You are fools to stand against our might!')
            },
            {
                Bank = 'X02_VO',
                Cue = 'X02_Celene_M01_03130',
                Text = LOC('<LOC X02_M01_050_010>[{i Celene}]: You do not comprehend the power that is arrayed against you.')
            },
            {
                Bank = 'X02_VO',
                Cue = 'X02_Celene_M01_03131',
                Text = LOC('<LOC X02_M01_060_010>[{i Celene}]: Your mere presence here desecrates this planet. You are an abomination.')
            },
            {
                Bank = 'X06_VO',
                Cue = 'X06_Vedetta_T01_03016',
                Text = LOC('<LOC X06_T01_540_010>[{i Vendetta}]: You will die by my hand, traitor.')
            },
        },
        GameEndAI = {
            {
                Bank = 'X02_VO',
                Cue = 'X02_Celene_M03_03579',
                Text = LOC('<LOC X02_M03_200_010>[{i Celene}]: Where are your boasts now, machine?')
            },
        },
        LaunchNuke = {
            {
                Bank = 'X01_VO',
                Cue = 'X01_Gari_T01_04516',
                Text = LOC('<LOC X01_T01_060_010>[{i Gari}]: Now you will taste the fury of the Order of the Illuminate.')
            },
            {
                Bank = 'X01_VO',
                Cue = 'X01_Gari_M02_04245',
                Text = LOC('<LOC X01_M02_161_010>[{i Gari}]: Ha-ha-ha!')
            },
            {
                Bank = 'X02_VO',
                Cue = 'X02_Celene_T01_04544',
                Text = LOC('<LOC X02_T01_090_010>[{i Celene}]: Nothing can save you now!')
            },
        }
    },
    {   
        GameStart = {
             {
                Bank = 'X05_VO',
                Cue = 'X05_QAI_T01_04424',
                Text = LOC('<LOC X05_T01_100_010>[{i QAI}]: On this day, I will teach you the true power of the Quantum Realm.')
            },
            {
                Bank = 'X02_VO',
                Cue = 'X02_QAI_T01_04559',
                Text = LOC('<LOC X02_T01_230_010>[{i QAI}]: The attack on Fort Clarke was only the beginning. You will be erased from existence.')
            },
            {
                Bank = 'X05_VO',
                Cue = 'X05_Hex5_T01_04429',
                Text = LOC('<LOC X05_T01_150_010>[{i Hex5}]: You are weak and soft, frightened by what you don\'t understand.')
            },
        },
        LaunchNuke = {
            {
                Bank = 'X02_VO',
                Cue = 'X02_QAI_T01_04558',
                Text = LOC('<LOC X02_T01_220_010>[{i QAI}]: All calculations indicate that your demise is near.')
            },
            {
                Bank = 'XGG',
                Cue = 'XGG_Hex5_MP1_04629',
                Text = LOC('<LOC XGG_MP1_640_010>[{i Hex5}]: Don\'t worry, it\'ll be over soon.')
            },
            {
                Bank = 'XGG',
                Cue = 'XGG_Hex5_MP1_04625',
                Text = LOC('<LOC XGG_MP1_600_010>[{i Hex5}]: A smoking crater is going to be all that\'s left of you.')
            },
        }
    },
    {
        GameStart = {
            {
                Bank = 'X03_VO',
                Cue = 'X03_Zan-Aishahesh_T01_04339',
                Text = '[Language Not Recognized]'
            },
            {
                Bank = 'X06_VO',
                Cue = 'X06_Thel-Uuthow_T01_02971',
                Text = LOC('<LOC X06_T01_190_010>[{i ThelUuthow}]: Your kind began this war. We are merely finishing it.')
            },
            {
                Bank = 'X06_VO',
                Cue = 'X06_Thel-Uuthow_T01_02978',
                Text = LOC('<LOC X06_T01_260_010>[{i ThelUuthow}]: You will perish at my hand.')
            },
            {
                Bank = 'X04_VO',
                Cue = 'X04_Oum-Eoshi_T01_04385',
                Text = LOC('<LOC X04_T01_030_010>[{i OumEoshi}]: Do not fret. Dying by my hand is the supreme honor.')
            },
            {
                Bank = 'X03_VO',
                Cue = 'X03_Thel-Uuthow_T01_04340',
                Text = '[Language Not Recognized]'
            },
       },
       LaunchNuke = {
            {
                Bank = 'X06_VO',
                Cue = 'X06_Thel-Uuthow_T01_02978',
                Text = LOC('<LOC X06_T01_260_010>[{i ThelUuthow}]: You will perish at my hand.')
            },
            {
                Bank = 'X03_VO',
                Cue = 'X03_Zan-Aishahesh_T01_04343',
                Text = '[Language Not Recognized]'
            },
       }
    }
}

function ConsiderRandomTaunt(aiBrain, type)
    local factionIndex = aiBrain:GetFactionIndex()
    if not factionIndex or not type then
        WARN('AI-RNG: Unable to consider random taunt due to missing factionIndex or type')
        return
    end
    if factionIndex > 4 then
        return
    end
    
    coroutine.yield(math.random(1, 20))
    local currentTime = GetGameTimeSeconds()
    local tauntData
    if RNGAIGLOBALS.LastTauntTime == 0 or RNGAIGLOBALS.LastTauntTime + 300 < currentTime then
        local chance = math.random(1,10)
        if chance == 2 then
            if tauntTable[factionIndex][type] then
                local tableLength = table.getn(tauntTable[factionIndex][type])
                local selection = math.random(1,tableLength)
                tauntData = tauntTable[factionIndex][type][selection]
            end
        end
    end
    if tauntData then
        SendTaunt(aiBrain, tauntData)
    end
end

function ConsiderAttackTaunt(aiBrain, type, targetUnit, optionalDelay)
    local factionIndex = aiBrain:GetFactionIndex()
    if not factionIndex or not type then
        WARN('AI-RNG: Unable to consider random taunt due to missing factionIndex or type')
        return
    end
    if factionIndex > 4 then
        return
    end
    local targetIndex
    if targetUnit and not targetUnit.Dead then
        targetIndex = targetUnit:GetAIBrain():GetArmyIndex()
    end
    if optionalDelay then
        coroutine.yield(optionalDelay * 10)
    end

    local currentTime = GetGameTimeSeconds()
    local tauntData

    if RNGAIGLOBALS.LastTauntTime == 0 or RNGAIGLOBALS.LastTauntTime + 300 < currentTime then
        local chance = math.random(1,10)
        if chance == 2 then
            if tauntTable[factionIndex][type] then
                local tableLength = table.getn(tauntTable[factionIndex][type])
                local selection = math.random(1,tableLength)
                tauntData = tauntTable[factionIndex][type][selection]
            end
        end
    end
    if tauntData then
        SendTaunt(aiBrain, tauntData, targetIndex)
    end
end

function SendTaunt(aiBrain, tauntData, optionalArmyIndex)
    RNGAIGLOBALS.LastTauntTime = GetGameTimeSeconds()
    if tauntData.Text then
        local optionalPlayerTarget
        if optionalArmyIndex then
            optionalPlayerTarget = ArmyBrains[optionalArmyIndex].Nickname
        end
        SUtils.AISendChat('enemies', aiBrain.Nickname, tauntData.Text, optionalPlayerTarget)
    end
    if tauntData.Bank and tauntData.Cue then
        AudioMessage(tauntData.Bank, tauntData.Cue, optionalArmyIndex)
    end

end

-- Usage CUtils.AudioMessage('X03_VO', 'X03_Zan-Aishahesh_T01_04339')

function AudioMessage(bank, cue, optionalArmyIndex)
    -- Thanks to Maudlin for help with this.
    local SyncVoice = SimSyncUtils.SyncVoice
    if not(optionalArmyIndex) or (GetFocusArmy() > 0 and not(IsEnemy(GetFocusArmy(), optionalArmyIndex))) then
        SyncVoice({Cue = cue, Bank = bank})
    end
end