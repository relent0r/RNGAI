--[[
    File    :   /lua/AI/AIBuilders/RNGAI T1PD Template.lua
    Author  :   relentless
    Summary :
        Defence template for T1PD surounded by walls.
]]
DefenseTemplate =
{
-- UEF BaseTemplates Building List
    {
        {
            {
            'T2ShieldDefense',
            'T3ShieldDefense',
            },
            { 0, 0, 0 },
        },
        {
            {
            'T1AADefense',
            'T1GroundDefense',
            'T2Artillery',
            'T2AADefense',
            'T2MissileDefense',
            'T2GroundDefense', 
            'T3GroundDefense', 
            'T3AADefense', 
            },
            { 0, -2, 0 },
            { 0, 2, 0 },
            { 2, 0, 0 },
            { -2, 0, 0 },
            { 2, -2, 0 },
            { -2, 2, 0 },
            { 0, -4, 0 },
            { 0, 4, 0 },
            { 4, 0, 0 },
            { 4, -2, 0 },
            { -2, 4, 0 },
            { 4, -4, 0 },
            { 2, -4, 0 },
            { 0, -6, 0 },
            { 0, 6, 0 },
            { -2, 6, 0 },
            { 2, -6, 0 },
            { 2, -8, 0 },
            { -2, 8, 0 },
            { 4, -6, 0 },
            { 4, -8, 0 },
            { -4, 0, 0 },
            { -4, 2, 0 },
            { -4, 4, 0 },
            { -4, 6, 0 },
            { 0, 8, 0 },
            { 0, -10, 0 },
            { 0, -8, 0 },
            { 0, 10, 0 },
            { -2, 10, 0 },
            { -4, 8, 0 },
            { -4, 10, 0 },
            { 6, 0, 0 },
            { 6, -2, 0 },
            { 6, -4, 0 },
            { 6, -6, 0 },
            { -6, 0, 0 },
            { -6, 2, 0 },
            { -6, 4, 0 },
            { -6, 6, 0 },
            { 6, -8, 0 },
            { 6, -10, 0 },
            { -6, 8, 0 },
            { -6, 10, 0 },
            { 8, 0, 0 },
            { 8, -2, 0 },
            { 8, -4, 0 },
            { 8, -6, 0 },
            { 8, -8, 0 },
            { 8, -10, 0 },
            { 4, -10, 0 },
            { 2, -10, 0 },
            { -8, 0, 0 },
            { -8, 2, 0 },
            { -8, 4, 0 },
            { -8, 6, 0 },
            { -8, 8, 0 },
            { -8, 10, 0 },
            { 10, 0, 0 },
            { 10, -2, 0 },
            { 10, -4, 0 },
            { 10, -6, 0 },
            { 10, -8, 0 },
            { 10, -10, 0 },
            { -10, 0, 0 },
            { -10, 2, 0 },
            { -10, 4, 0 },
            { -10, 6, 0 },
            { -10, 8, 0 },
            { -10, 10, 0 },
        },
    },
-- Cybran BaseTemplates Building List
    {
        {
            {
            'T2ShieldDefense',
            'T3ShieldDefense',
            },
            { 0, 0, 0 },
        },
        {
            {
            'T1AADefense',
            'T1GroundDefense',
            'T2Artillery',
            'T2AADefense',
            'T2MissileDefense',
            'T2GroundDefense', 
            'T3GroundDefense', 
            'T3AADefense', 
            },
            { 0, -2, 0 },
            { 0, 2, 0 },
            { 2, 0, 0 },
            { -2, 0, 0 },
            { 2, -2, 0 },
            { -2, 2, 0 },
            { 0, -4, 0 },
            { 0, 4, 0 },
            { 4, 0, 0 },
            { 4, -2, 0 },
            { -2, 4, 0 },
            { 4, -4, 0 },
            { 2, -4, 0 },
            { 0, -6, 0 },
            { 0, 6, 0 },
            { -2, 6, 0 },
            { 2, -6, 0 },
            { 2, -8, 0 },
            { -2, 8, 0 },
            { 4, -6, 0 },
            { 4, -8, 0 },
            { -4, 0, 0 },
            { -4, 2, 0 },
            { -4, 4, 0 },
            { -4, 6, 0 },
            { 0, 8, 0 },
            { 0, -10, 0 },
            { 0, -8, 0 },
            { 0, 10, 0 },
            { -2, 10, 0 },
            { -4, 8, 0 },
            { -4, 10, 0 },
            { 6, 0, 0 },
            { 6, -2, 0 },
            { 6, -4, 0 },
            { 6, -6, 0 },
            { -6, 0, 0 },
            { -6, 2, 0 },
            { -6, 4, 0 },
            { -6, 6, 0 },
            { 6, -8, 0 },
            { 6, -10, 0 },
            { -6, 8, 0 },
            { -6, 10, 0 },
            { 8, 0, 0 },
            { 8, -2, 0 },
            { 8, -4, 0 },
            { 8, -6, 0 },
            { 8, -8, 0 },
            { 8, -10, 0 },
            { 4, -10, 0 },
            { 2, -10, 0 },
            { -8, 0, 0 },
            { -8, 2, 0 },
            { -8, 4, 0 },
            { -8, 6, 0 },
            { -8, 8, 0 },
            { -8, 10, 0 },
            { 10, 0, 0 },
            { 10, -2, 0 },
            { 10, -4, 0 },
            { 10, -6, 0 },
            { 10, -8, 0 },
            { 10, -10, 0 },
            { -10, 0, 0 },
            { -10, 2, 0 },
            { -10, 4, 0 },
            { -10, 6, 0 },
            { -10, 8, 0 },
            { -10, 10, 0 },
        },
    },
-- Seraphim BaseTemplates Building List
    {
        {
            {
            'T2ShieldDefense',
            'T3ShieldDefense',
            },
            { 0, 0, 0 },
        },
        {
            {
            'T1AADefense',
            'T1GroundDefense',
            'T2Artillery',
            'T2AADefense',
            'T2MissileDefense',
            'T2GroundDefense', 
            'T3GroundDefense', 
            'T3AADefense', 
            },
            { 0, -2, 0 },
            { 0, 2, 0 },
            { 2, 0, 0 },
            { -2, 0, 0 },
            { 2, -2, 0 },
            { -2, 2, 0 },
            { 0, -4, 0 },
            { 0, 4, 0 },
            { 4, 0, 0 },
            { 4, -2, 0 },
            { -2, 4, 0 },
            { 4, -4, 0 },
            { 2, -4, 0 },
            { 0, -6, 0 },
            { 0, 6, 0 },
            { -2, 6, 0 },
            { 2, -6, 0 },
            { 2, -8, 0 },
            { -2, 8, 0 },
            { 4, -6, 0 },
            { 4, -8, 0 },
            { -4, 0, 0 },
            { -4, 2, 0 },
            { -4, 4, 0 },
            { -4, 6, 0 },
            { 0, 8, 0 },
            { 0, -10, 0 },
            { 0, -8, 0 },
            { 0, 10, 0 },
            { -2, 10, 0 },
            { -4, 8, 0 },
            { -4, 10, 0 },
            { 6, 0, 0 },
            { 6, -2, 0 },
            { 6, -4, 0 },
            { 6, -6, 0 },
            { -6, 0, 0 },
            { -6, 2, 0 },
            { -6, 4, 0 },
            { -6, 6, 0 },
            { 6, -8, 0 },
            { 6, -10, 0 },
            { -6, 8, 0 },
            { -6, 10, 0 },
            { 8, 0, 0 },
            { 8, -2, 0 },
            { 8, -4, 0 },
            { 8, -6, 0 },
            { 8, -8, 0 },
            { 8, -10, 0 },
            { 4, -10, 0 },
            { 2, -10, 0 },
            { -8, 0, 0 },
            { -8, 2, 0 },
            { -8, 4, 0 },
            { -8, 6, 0 },
            { -8, 8, 0 },
            { -8, 10, 0 },
            { 10, 0, 0 },
            { 10, -2, 0 },
            { 10, -4, 0 },
            { 10, -6, 0 },
            { 10, -8, 0 },
            { 10, -10, 0 },
            { -10, 0, 0 },
            { -10, 2, 0 },
            { -10, 4, 0 },
            { -10, 6, 0 },
            { -10, 8, 0 },
            { -10, 10, 0 },
        },
    },
-- UEF BaseTemplates Building List
    {
        {
            {
            'T2ShieldDefense',
            'T3ShieldDefense',
            },
            { 0, 0, 0 },
        },
        {
            {
            'T1AADefense',
            'T1GroundDefense',
            'T2Artillery',
            'T2AADefense',
            'T2MissileDefense',
            'T2GroundDefense', 
            'T3GroundDefense', 
            'T3AADefense', 
            },
            { 0, -2, 0 },
            { 0, 2, 0 },
            { 2, 0, 0 },
            { -2, 0, 0 },
            { 2, -2, 0 },
            { -2, 2, 0 },
            { 0, -4, 0 },
            { 0, 4, 0 },
            { 4, 0, 0 },
            { 4, -2, 0 },
            { -2, 4, 0 },
            { 4, -4, 0 },
            { 2, -4, 0 },
            { 0, -6, 0 },
            { 0, 6, 0 },
            { -2, 6, 0 },
            { 2, -6, 0 },
            { 2, -8, 0 },
            { -2, 8, 0 },
            { 4, -6, 0 },
            { 4, -8, 0 },
            { -4, 0, 0 },
            { -4, 2, 0 },
            { -4, 4, 0 },
            { -4, 6, 0 },
            { 0, 8, 0 },
            { 0, -10, 0 },
            { 0, -8, 0 },
            { 0, 10, 0 },
            { -2, 10, 0 },
            { -4, 8, 0 },
            { -4, 10, 0 },
            { 6, 0, 0 },
            { 6, -2, 0 },
            { 6, -4, 0 },
            { 6, -6, 0 },
            { -6, 0, 0 },
            { -6, 2, 0 },
            { -6, 4, 0 },
            { -6, 6, 0 },
            { 6, -8, 0 },
            { 6, -10, 0 },
            { -6, 8, 0 },
            { -6, 10, 0 },
            { 8, 0, 0 },
            { 8, -2, 0 },
            { 8, -4, 0 },
            { 8, -6, 0 },
            { 8, -8, 0 },
            { 8, -10, 0 },
            { 4, -10, 0 },
            { 2, -10, 0 },
            { -8, 0, 0 },
            { -8, 2, 0 },
            { -8, 4, 0 },
            { -8, 6, 0 },
            { -8, 8, 0 },
            { -8, 10, 0 },
            { 10, 0, 0 },
            { 10, -2, 0 },
            { 10, -4, 0 },
            { 10, -6, 0 },
            { 10, -8, 0 },
            { 10, -10, 0 },
            { -10, 0, 0 },
            { -10, 2, 0 },
            { -10, 4, 0 },
            { -10, 6, 0 },
            { -10, 8, 0 },
            { -10, 10, 0 },
        },
    },
}