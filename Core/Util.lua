-------------------------------------------------------------------------------
-- Project: AscensionKeybindSync
-- Author: Aka-DoctorCode
-- File: Util.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local addonName, addonTable = ...
addonTable.Util = {}
local Util = addonTable.Util

local base64Characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local base64DecoderTable = {}
for i = 1, #base64Characters do
    base64DecoderTable[string.sub(base64Characters, i, i)] = i - 1
end

local actionBarBindings = {
    { startSlot = 1, bindingPrefix = "ACTIONBUTTON" },
    { startSlot = 13, bindingPrefix = "ACTIONBUTTON" },
    { startSlot = 61, bindingPrefix = "MULTIACTIONBAR1BUTTON" },
    { startSlot = 49, bindingPrefix = "MULTIACTIONBAR2BUTTON" },
    { startSlot = 25, bindingPrefix = "MULTIACTIONBAR3BUTTON" },
    { startSlot = 37, bindingPrefix = "MULTIACTIONBAR4BUTTON" },
    { startSlot = 145, bindingPrefix = "MULTIACTIONBAR5BUTTON" },
    { startSlot = 157, bindingPrefix = "MULTIACTIONBAR6BUTTON" },
    { startSlot = 169, bindingPrefix = "MULTIACTIONBAR7BUTTON" },
    { startSlot = 73, bindingPrefix = "ACTIONBUTTON" },
    { startSlot = 85, bindingPrefix = "ACTIONBUTTON" },
    { startSlot = 97, bindingPrefix = "ACTIONBUTTON" },
    { startSlot = 109, bindingPrefix = "ACTIONBUTTON" },
    { startSlot = 121, bindingPrefix = "ACTIONBUTTON" },
    { startSlot = 133, bindingPrefix = "ACTIONBUTTON" },
}

function Util.getBindingPrefixForSlot(slot)
    for _, barInfo in ipairs(actionBarBindings) do
        if slot >= barInfo.startSlot and slot < barInfo.startSlot + 12 then
            if barInfo.bindingPrefix == "ACTIONBUTTON" then
                return barInfo.bindingPrefix, slot
            else
                return barInfo.bindingPrefix, ((slot - barInfo.startSlot) % 12) + 1
            end
        end
    end
    return "ACTIONBUTTON", slot
end

function Util.encodeBase64(data)
    local bytes = {}
    local result = ""
    for i = 1, #data do
        bytes[i] = string.byte(data, i)
    end
    for i = 1, #bytes - 2, 3 do
        local byte1, byte2, byte3 = bytes[i], bytes[i + 1], bytes[i + 2]
        local character1 = math.floor(byte1 / 4)
        local character2 = ((byte1 % 4) * 16) + math.floor(byte2 / 16)
        local character3 = ((byte2 % 16) * 4) + math.floor(byte3 / 64)
        local character4 = byte3 % 64
        result = result .. string.sub(base64Characters, character1 + 1, character1 + 1) ..
            string.sub(base64Characters, character2 + 1, character2 + 1) ..
            string.sub(base64Characters, character3 + 1, character3 + 1) ..
            string.sub(base64Characters, character4 + 1, character4 + 1)
    end
    local remainder = #bytes % 3
    if remainder == 2 then
        local byte1, byte2 = bytes[#bytes - 1], bytes[#bytes]
        local character1 = math.floor(byte1 / 4)
        local character2 = ((byte1 % 4) * 16) + math.floor(byte2 / 16)
        local character3 = (byte2 % 16) * 4
        result = result .. string.sub(base64Characters, character1 + 1, character1 + 1) ..
            string.sub(base64Characters, character2 + 1, character2 + 1) ..
            string.sub(base64Characters, character3 + 1, character3 + 1) .. "="
    elseif remainder == 1 then
        local byte1 = bytes[#bytes]
        local character1 = math.floor(byte1 / 4)
        local character2 = (byte1 % 4) * 16
        result = result .. string.sub(base64Characters, character1 + 1, character1 + 1) ..
            string.sub(base64Characters, character2 + 1, character2 + 1) .. "=="
    end
    return result
end

function Util.decodeBase64(data)
    data = string.gsub(data, "%s+", "")
    if string.match(data, "[^" .. base64Characters .. "=]") then
        return nil
    end
    local result = ""
    local padding = 0
    if string.sub(data, -1) == "=" then
        padding = padding + 1
        if string.sub(data, -2, -2) == "=" then
            padding = padding + 1
        end
        data = string.sub(data, 1, -padding - 1)
    end
    for i = 1, #data - 3, 4 do
        local character1 = base64DecoderTable[string.sub(data, i, i)]
        local character2 = base64DecoderTable[string.sub(data, i + 1, i + 1)]
        local character3 = base64DecoderTable[string.sub(data, i + 2, i + 2)]
        local character4 = base64DecoderTable[string.sub(data, i + 3, i + 3)]
        if not (character1 and character2 and character3 and character4) then return nil end
        local byte1 = (character1 * 4) + math.floor(character2 / 16)
        local byte2 = ((character2 % 16) * 16) + math.floor(character3 / 4)
        local byte3 = ((character3 % 4) * 64) + character4
        result = result .. string.char(byte1, byte2, byte3)
    end
    if padding == 1 then
        local character1 = base64DecoderTable[string.sub(data, -3, -3)]
        local character2 = base64DecoderTable[string.sub(data, -2, -2)]
        local character3 = base64DecoderTable[string.sub(data, -1, -1)]
        if not (character1 and character2 and character3) then return nil end
        local byte1 = (character1 * 4) + math.floor(character2 / 16)
        local byte2 = ((character2 % 16) * 16) + math.floor(character3 / 4)
        result = result .. string.char(byte1, byte2)
    elseif padding == 2 then
        local character1 = base64DecoderTable[string.sub(data, -2, -2)]
        local character2 = base64DecoderTable[string.sub(data, -1, -1)]
        if not (character1 and character2) then return nil end
        local byte1 = (character1 * 4) + math.floor(character2 / 16)
        result = result .. string.char(byte1)
    end
    return result
end

function Util.serializeBindings(bindings)
    local parts = {}
    for i = 1, 180 do
        local b = bindings[i]
        if b and b.actionType then
            local actionType = b.actionType
            local id = tostring(b.id or "")
            local subType = tostring(b.subType or "")
            local key1 = tostring(b.key1 or "")
            local key2 = tostring(b.key2 or "")
            local macroName = tostring(b.macroName or "")
            local macroBody = tostring(b.macroBody or "")
            
            table.insert(parts, string.format("%d|%s|%s|%s|%s|%s|%s|%s", i, actionType, id, subType, key1, key2, macroName, macroBody))
        end
    end
    return table.concat(parts, ";")
end

function Util.deserializeBindings(str)
    local bindings = {}
    for part in string.gmatch(str, "[^;]+") do
        local partsList = { string.split("|", part) }
        local slot = tonumber(partsList[1])
        if slot then
            local actionType = partsList[2]
            local id = partsList[3]
            local subType = partsList[4]
            local key1 = partsList[5]
            local key2 = partsList[6]
            local macroName = partsList[7]
            local macroBody = partsList[8]
            
            if id == "" then id = nil end
            if subType == "" then subType = nil end
            if key1 == "" then key1 = nil end
            if key2 == "" then key2 = nil end
            if macroName == "" then macroName = nil end
            if macroBody == "" then macroBody = nil end
            
            bindings[slot] = {
                actionType = actionType,
                id = tonumber(id) or id,
                subType = subType,
                key1 = key1,
                key2 = key2,
                macroName = macroName,
                macroBody = macroBody
            }
        end
    end
    return bindings
end
