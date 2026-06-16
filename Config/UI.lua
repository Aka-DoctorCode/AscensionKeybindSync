-------------------------------------------------------------------------------
-- Project: AscensionKeybindSync
-- Author: Aka-DoctorCode
-- File: UI.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local addonName, addonTable = ...

local UI = {}
UI.__index = UI

local activeToasts = {}

local function rearrangeToasts()
    for index, toast in ipairs(activeToasts) do
        toast:ClearAllPoints()
        toast:SetPoint("TOP", _G.UIParent, "TOP", 0, -200 - (index - 1) * 45)
    end
end

function UI:new(addonInstance)
    local instance = setmetatable({
        addon = addonInstance,
        customDialog = nil,
        inputDialog = nil,
        configFrame = nil,
        profileListFrame = nil,
        previewButtonsPool = {},
        activePreviewButtonsCount = 0,
        hoveredProfileBindings = nil,
    }, self)
    return instance
end

function UI:showToast(text, toastType)
    local addon = self.addon
    local styles = addon.uiContext.styles
    
    local toast = CreateFrame("Frame", nil, _G.UIParent, "BackdropTemplate")
    toast:SetSize(280, 36)
    
    local color = styles.colors.gold
    if toastType == "success" then
        color = { 0.1, 0.8, 0.2, 1 }
    elseif toastType == "error" then
        color = { 0.85, 0.15, 0.15, 1 }
    end
    
    toast:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    toast:SetBackdropColor(0.03, 0.03, 0.04, 0.9)
    toast:SetBackdropBorderColor(unpack(color))
    
    local fontString = toast:CreateFontString(nil, "OVERLAY")
    fontString:SetFontObject(styles and styles.fonts and styles.fonts.label or "GameFontNormal")
    fontString:SetPoint("CENTER", 0, 0)
    fontString:SetText(text)
    fontString:SetTextColor(unpack(color))
    
    table.insert(activeToasts, toast)
    rearrangeToasts()
    
    toast:SetAlpha(0)
    local fadeStepsIn = 15
    local currentStep = 0
    local timerIn
    timerIn = C_Timer.NewTicker(0.01, function()
        currentStep = currentStep + 1
        toast:SetAlpha(currentStep / fadeStepsIn)
        if currentStep >= fadeStepsIn then
            timerIn:Cancel()
            C_Timer.After(3, function()
                local fadeStepsOut = 20
                local currentStepOut = fadeStepsOut
                local timerOut
                timerOut = C_Timer.NewTicker(0.01, function()
                    currentStepOut = currentStepOut - 1
                    toast:SetAlpha(currentStepOut / fadeStepsOut)
                    if currentStepOut <= 0 then
                        timerOut:Cancel()
                        toast:Hide()
                        for idx, activeToast in ipairs(activeToasts) do
                            if activeToast == toast then
                                table.remove(activeToasts, idx)
                                break
                            end
                        end
                        rearrangeToasts()
                    end
                end)
            end)
        end
    end)
end

function UI:showCustomDialog(title, text, buttons)
    local addon = self.addon
    if not addon.uiContext then return end

    if not self.customDialog then
        local frame = CreateFrame("Frame", "AscensionProfilesCustomDialog", _G.UIParent, "BackdropTemplate")
        frame:SetSize(400, 180)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        
        local styles = addon.uiContext.styles
        frame:SetBackdrop({
            bgFile = styles.files.bgFile,
            edgeFile = styles.files.edgeFile,
            edgeSize = 3,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(unpack(styles.colors.backgroundDark or styles.colors.mainBackground or {0.02, 0.02, 0.03, 0.95}))
        frame:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
        
        local titleStr = frame:CreateFontString(nil, "OVERLAY", styles and styles.fonts and styles.fonts.header or "GameFontNormalLarge")
        titleStr:SetPoint("TOP", 0, -16)
        titleStr:SetTextColor(unpack(styles.colors.gold))
        frame.titleStr = titleStr
        
        local textStr = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        textStr:SetPoint("TOP", titleStr, "BOTTOM", 0, -15)
        textStr:SetWidth(360)
        textStr:SetJustifyH("CENTER")
        frame.textStr = textStr
        
        frame.buttons = {}
        tinsert(UISpecialFrames, "AscensionProfilesCustomDialog")
        frame:SetScript("OnHide", function()
            addon.isInitialized = true
        end)
        self.customDialog = frame
    end
    
    local frame = self.customDialog
    frame.titleStr:SetText(title)
    frame.textStr:SetText(text)
    
    for _, btn in ipairs(frame.buttons) do
        btn:Hide()
    end
    
    local numButtons = #buttons
    local btnWidth = 110
    local spacing = 10
    local totalWidth = (numButtons * btnWidth) + ((numButtons - 1) * spacing)
    local startX = -(totalWidth / 2) + (btnWidth / 2)
    
    for i, btnInfo in ipairs(buttons) do
        local btn = frame.buttons[i]
        if not btn then
            btn = addon.uiContext:createButton({
                parent = frame,
                text = "",
                onClick = function() end,
                width = btnWidth,
                height = 22
            })
            table.insert(frame.buttons, btn)
        end
        btn.text:SetText(btnInfo.text)
        btn:SetScript("OnClick", function()
            frame:Hide()
            if btnInfo.onClick then btnInfo.onClick() end
        end)
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOM", frame, "BOTTOM", startX + ((i - 1) * (btnWidth + spacing)), 20)
        btn:Show()
    end
    
    frame:Show()
end

function UI:showInputDialog(title, text, defaultValue, onConfirm, onCancel)
    local addon = self.addon
    if not addon.uiContext then return end

    if not self.inputDialog then
        local frame = CreateFrame("Frame", "AscensionProfilesInputDialog", _G.UIParent, "BackdropTemplate")
        frame:SetSize(350, 160)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        
        local styles = addon.uiContext.styles
        frame:SetBackdrop({
            bgFile = styles.files.bgFile,
            edgeFile = styles.files.edgeFile,
            edgeSize = 3,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(unpack(styles.colors.backgroundDark or styles.colors.mainBackground or {0.02, 0.02, 0.03, 0.95}))
        frame:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
        
        local titleStr = frame:CreateFontString(nil, "OVERLAY", styles and styles.fonts and styles.fonts.header or "GameFontNormalLarge")
        titleStr:SetPoint("TOP", 0, -16)
        titleStr:SetTextColor(unpack(styles.colors.gold))
        frame.titleStr = titleStr
        
        local textStr = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        textStr:SetPoint("TOP", titleStr, "BOTTOM", 0, -10)
        textStr:SetWidth(310)
        textStr:SetJustifyH("CENTER")
        frame.textStr = textStr
        
        local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        editBox:SetSize(260, 24)
        editBox:SetPoint("TOP", textStr, "BOTTOM", 0, -15)
        editBox:SetAutoFocus(true)
        editBox:SetFontObject("ChatFontNormal")
        frame.editBox = editBox
        
        frame.confirmBtn = addon.uiContext:createButton({
            parent = frame,
            text = "Confirm",
            onClick = function() end,
            width = 110,
            height = 22
        })
        frame.confirmBtn:ClearAllPoints()
        frame.confirmBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 45, 15)
        
        local cancelBtn = addon.uiContext:createButton({
            parent = frame,
            text = "Cancel",
            onClick = function() end,
            width = 110,
            height = 22
        })
        cancelBtn:ClearAllPoints()
        cancelBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -45, 15)
        frame.cancelBtn = cancelBtn
        
        tinsert(UISpecialFrames, "AscensionProfilesInputDialog")
        self.inputDialog = frame
    end
    
    local frame = self.inputDialog
    frame.titleStr:SetText(title)
    frame.textStr:SetText(text)
    frame.editBox:SetText(defaultValue or "")
    frame.editBox:HighlightText()
    
    frame.confirmBtn:SetScript("OnClick", function()
        local inputVal = frame.editBox:GetText()
        if inputVal and inputVal ~= "" then
            frame:Hide()
            onConfirm(inputVal)
        else
            addon:printMessage("Input cannot be empty.")
        end
    end)
    
    frame.cancelBtn:SetScript("OnClick", function()
        frame:Hide()
        if onCancel then onCancel() end
    end)
    
    frame:Show()
end

function UI:scanActiveLayout()
    local scanResults = {}
    local minLeft, maxLeft, minBottom, maxBottom = 99999, -99999, 99999, -99999
    local processedButtons = {}
    
    local function processButton(btn)
        if not btn or processedButtons[btn] then return end
        processedButtons[btn] = true
        
        if btn:IsShown() then
            local left, bottom, width, height = btn:GetRect()
            local action = btn:GetAttribute("action")
            if left and bottom and action and type(action) == "number" and action >= 1 and action <= 180 then
                table.insert(scanResults, {
                    left = left, bottom = bottom, width = width, height = height, slot = action
                })
                if left < minLeft then minLeft = left end
                if left + width > maxLeft then maxLeft = left + width end
                if bottom < minBottom then minBottom = bottom end
                if bottom + height > maxBottom then maxBottom = bottom + height end
            end
        end
    end
    
    local names = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", 
        "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", 
        "MultiBar6Button", "MultiBar7Button"
    }
    for _, prefix in ipairs(names) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then
                processButton(btn)
            end
        end
    end
    
    local lib = LibStub("LibActionButton-1.0", true)
    if lib and lib.buttonRegistry then
        for btn in pairs(lib.buttonRegistry) do
            processButton(btn)
        end
    end
    
    for i = 1, 120 do
        local btn = _G["BT4Button" .. i]
        if btn then
            processButton(btn)
        end
    end
    
    for bar = 1, 10 do
        for i = 1, 12 do
            local btn = _G["ElvUI_Bar" .. bar .. "Button" .. i]
            if btn then
                processButton(btn)
            end
        end
    end
    
    for i = 1, 120 do
        local btn = _G["DominosActionButton" .. i]
        if btn then
            processButton(btn)
        end
    end
    
    if #scanResults == 0 then
        for i = 1, 12 do
            local left = 100 + (i - 1) * 32
            local bottom = 200
            table.insert(scanResults, {
                left = left, bottom = bottom, width = 28, height = 28, slot = i
            })
        end
        minLeft, maxLeft, minBottom, maxBottom = 100, 100 + 12 * 32, 200, 228
    end
    
    return scanResults, minLeft, maxLeft, minBottom, maxBottom
end

function UI:createPreviewGrid(parentFrame)
    local addon = self.addon
    local styles = addon.uiContext.styles
    
    local container = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    container:SetSize(330, 95)
    container:SetPoint("BOTTOM", parentFrame, "BOTTOM", 0, 15)
    container:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    container:SetBackdropColor(0.01, 0.01, 0.02, 0.6)
    container:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 0.5}))
    
    local label = container:CreateFontString(nil, "OVERLAY")
    label:SetFontObject("GameFontNormalSmall")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -4)
    label:SetText("Profile Layout Preview")
    label:SetTextColor(unpack(styles.colors.gold))
    
    parentFrame.previewContainer = container
end

local function getActionIcon(action)
    if not action or not action.actionType then return nil end
    if action.icon then return action.icon end
    
    local actionType = action.actionType
    local id = action.id
    
    if actionType == "spell" then
        return C_Spell.GetSpellTexture(id)
    elseif actionType == "item" then
        if type(id) == "string" and string.find(id, ":") then
            local itemID = tonumber(string.split(":", id)) or 0
            return C_Item.GetItemIconByID(itemID)
        else
            return C_Item.GetItemIconByID(id)
        end
    elseif actionType == "macro" then
        if action.name then
            return select(2, GetMacroInfo(action.name))
        end
    elseif actionType == "summonmount" then
        return select(3, C_MountJournal.GetMountInfoByID(id))
    elseif actionType == "summonpet" then
        return select(9, C_PetJournal.GetPetInfoByPetID(id))
    elseif actionType == "flyout" then
        return select(2, GetFlyoutInfo(id))
    end
    return nil
end

function UI:updatePreviewGrid(bindings)
    local addon = self.addon
    local styles = addon.uiContext.styles
    local container = self.configFrame and self.configFrame.previewContainer
    if not container or not bindings then return end
    
    for i = 1, self.activePreviewButtonsCount do
        if self.previewButtonsPool[i] then
            self.previewButtonsPool[i]:Hide()
        end
    end
    
    local scanResults, minLeft, maxLeft, minBottom, maxBottom = self:scanActiveLayout()
    local totalWidth = math.max(1, maxLeft - minLeft)
    local totalHeight = math.max(1, maxBottom - minBottom)
    
    local scaleX = 320 / totalWidth
    local scaleY = 65 / totalHeight
    local scale = math.min(scaleX, scaleY)
    scale = math.min(scale, 0.35)
    
    local adjustedWidth = totalWidth * scale
    local adjustedHeight = totalHeight * scale
    
    local offsetGridX = (330 - adjustedWidth) / 2
    local offsetGridY = (95 - adjustedHeight) / 2 + 5
    
    for idx, layoutInfo in ipairs(scanResults) do
        local btn = self.previewButtonsPool[idx]
        if not btn then
            btn = CreateFrame("Button", nil, container, "BackdropTemplate")
            btn:SetBackdrop({
                bgFile = styles.files.bgFile,
                edgeFile = styles.files.edgeFile,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            local iconTex = btn:CreateTexture(nil, "BACKGROUND")
            iconTex:SetAllPoints(btn)
            btn.iconTexture = iconTex
            self.previewButtonsPool[idx] = btn
        end
        
        btn:SetSize(layoutInfo.width * scale, layoutInfo.height * scale)
        btn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", offsetGridX + (layoutInfo.left - minLeft) * scale, offsetGridY + (layoutInfo.bottom - minBottom) * scale)
        
        local action = bindings[layoutInfo.slot]
        local icon = getActionIcon(action)
        
        if icon then
            btn.iconTexture:SetTexture(icon)
            btn.iconTexture:SetAlpha(1)
            btn:SetBackdropColor(0, 0, 0, 0)
            btn:SetBackdropBorderColor(unpack(styles.colors.gold))
        else
            btn.iconTexture:SetTexture(nil)
            btn:SetBackdropColor(0.08, 0.08, 0.1, 0.9)
            btn:SetBackdropBorderColor(0.2, 0.2, 0.22, 0.7)
        end
        
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            if action and action.actionType then
                local typeLabel = string.upper(string.sub(action.actionType, 1, 1)) .. string.sub(action.actionType, 2)
                local nameText = action.name or "Unknown"
                if action.actionType == "macro" and action.macroName then
                    nameText = Util.decodeBase64(action.macroName)
                end
                
                GameTooltip:AddLine(string.format("Slot %d: %s", layoutInfo.slot, nameText), 1, 1, 1)
                GameTooltip:AddLine("Type: " .. typeLabel, 1, 0.82, 0)
                
                local keyText = "Unbound"
                if action.key1 or action.key2 then
                    keyText = (action.key1 or "")
                    if action.key2 then
                        keyText = keyText .. " / " .. action.key2
                    end
                end
                GameTooltip:AddLine("Keybinds: " .. keyText, 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine(string.format("Slot %d: Empty", layoutInfo.slot), 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        btn:Show()
    end
    
    self.activePreviewButtonsCount = #scanResults
end

function UI:createProfileListPanel(parentFrame)
    local addon = self.addon
    local styles = addon.uiContext.styles
    
    local listFrame = CreateFrame("Frame", "AscensionProfilesListPanel", _G.UIParent, "BackdropTemplate")
    listFrame:SetSize(400, 350)
    listFrame:SetPoint("TOPLEFT", parentFrame, "TOPRIGHT", 5, 0)
    listFrame:SetFrameStrata("DIALOG")
    listFrame:SetClampedToScreen(true)
    listFrame:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 3,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    listFrame:SetBackdropColor(unpack(styles.colors.backgroundDark or styles.colors.mainBackground or {0.02, 0.02, 0.03, 0.95}))
    listFrame:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
    
    if LibStub:GetLibrary("AscensionSuit-UI", true).UX then
        LibStub:GetLibrary("AscensionSuit-UI", true).UX:makeMovable(listFrame)
        LibStub:GetLibrary("AscensionSuit-UI", true).UX:makeClosableWithEscape(listFrame)
    end
    
    local closeBtn = addon.uiContext:createCloseButton(listFrame, function() listFrame:Hide() end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    
    local title = listFrame:CreateFontString(nil, "OVERLAY", styles and styles.fonts and styles.fonts.header or "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Saved Profiles")
    title:SetTextColor(unpack(styles.colors.gold))
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(350, 240)
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 15, -45)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(350, 240)
    scrollFrame:SetScrollChild(scrollChild)
    listFrame.scrollChild = scrollChild
    
    local createBtn = addon.uiContext:createButton({
        parent = listFrame,
        text = "Create Profile",
        onClick = function()
            self:showCreateProfileDialog()
        end,
        width = 110,
        height = 30
    })
    createBtn:ClearAllPoints()
    createBtn:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", 20, 15)
    
    local importBtn = addon.uiContext:createButton({
        parent = listFrame,
        text = "Import Profile",
        onClick = function()
            self:showExportImportDialog("import", function(bindings)
                self:showInputDialog("Import Profile", "Enter name for imported profile:", "Imported Profile", function(profileName)
                    local classToken, specID = addon:getCurrentClassAndSpec()
                    local profileID = string.format("profile-%d", GetTime() * 1000)
                    addon.db.global.profiles[profileID] = {
                        name = profileName,
                        classToken = classToken,
                        specID = specID,
                        bindings = bindings
                    }
                    if not addon.db.global.activeProfiles[classToken] then
                        addon.db.global.activeProfiles[classToken] = {}
                    end
                    addon.db.global.activeProfiles[classToken][specID] = profileID
                    
                    self:updateProfileList()
                    local activeProfile = addon.db.global.profiles[profileID]
                    self:updatePreviewGrid(activeProfile.bindings)
                    self:showToast("Profile Imported", "success")
                    self:updateSaveButtonState()
                end)
            end)
        end,
        width = 110,
        height = 30
    })
    importBtn:ClearAllPoints()
    importBtn:SetPoint("BOTTOMLEFT", createBtn, "BOTTOMRIGHT", 10, 0)
    
    local closePanelBtn = addon.uiContext:createButton({
        parent = listFrame,
        text = "Close Panel",
        onClick = function() listFrame:Hide() end,
        width = 110,
        height = 30
    })
    closePanelBtn:ClearAllPoints()
    closePanelBtn:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -20, 15)
    
    tinsert(UISpecialFrames, "AscensionProfilesListPanel")
    self.profileListFrame = listFrame
end

function UI:updateProfileList()
    local listFrame = self.profileListFrame
    if not listFrame or not listFrame:IsShown() then return end
    
    local scrollChild = listFrame.scrollChild
    local addon = self.addon
    local styles = addon.uiContext.styles
    
    if not scrollChild.rows then
        scrollChild.rows = {}
    end
    
    for _, row in ipairs(scrollChild.rows) do
        row:Hide()
    end
    
    local profilesList = {}
    for profileID, profile in pairs(addon.db.global.profiles) do
        table.insert(profilesList, { id = profileID, data = profile })
    end
    
    table.sort(profilesList, function(a, b)
        return (a.data.name or "") < (b.data.name or "")
    end)
    
    local classToken, specID = addon:getCurrentClassAndSpec()
    local activeProfileID = addon.db.global.activeProfiles[classToken] and addon.db.global.activeProfiles[classToken][specID]
    
    local rowHeight = 40
    for idx, item in ipairs(profilesList) do
        local row = scrollChild.rows[idx]
        if not row then
            row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetSize(340, 36)
            row:SetBackdrop({
                bgFile = styles.files.bgFile,
                edgeFile = styles.files.edgeFile,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            row:SetBackdropColor(0.05, 0.05, 0.07, 0.8)
            row:SetBackdropBorderColor(0.15, 0.15, 0.18, 0.6)
            
            local classIcon = row:CreateTexture(nil, "ARTWORK")
            classIcon:SetSize(16, 16)
            classIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.classIcon = classIcon
            
            local nameText = row:CreateFontString(nil, "OVERLAY")
            nameText:SetFontObject(styles and styles.fonts and styles.fonts.label or "GameFontNormal")
            nameText:SetPoint("LEFT", classIcon, "RIGHT", 8, 0)
            nameText:SetWidth(150)
            nameText:SetJustifyH("LEFT")
            row.nameText = nameText
            
            local loadBtn = addon.uiContext:createButton({
                parent = row,
                text = "Load",
                onClick = function() end,
                width = 50,
                height = 24
            })
            loadBtn:ClearAllPoints()
            loadBtn:SetPoint("RIGHT", row, "RIGHT", -60, 0)
            row.loadBtn = loadBtn
            
            local menuBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            menuBtn:SetSize(20, 20)
            menuBtn:ClearAllPoints()
            menuBtn:SetPoint("RIGHT", row, "RIGHT", -35, 0)
            menuBtn:SetText("⚙")
            row.menuBtn = menuBtn
            
            local deleteBtn = addon.uiContext:createButton({
                parent = row,
                text = "X",
                onClick = function() end,
                width = 24,
                height = 24
            })
            deleteBtn:ClearAllPoints()
            deleteBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.deleteBtn = deleteBtn
            
            scrollChild.rows[idx] = row
        end
        
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(idx - 1) * rowHeight)
        
        local classColor = _G.RAID_CLASS_COLORS[string.upper(item.data.classToken or "")]
        if classColor then
            row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            row.classIcon:SetTexture("Interface\\Icons\\ClassIcon_" .. (item.data.classToken or "Warrior"))
            row.classIcon:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
        else
            row.nameText:SetTextColor(1, 1, 1, 1)
            row.classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            row.classIcon:SetVertexColor(1, 1, 1, 1)
        end
        
        local count = 0
        if item.data.bindings then
            for _ in pairs(item.data.bindings) do count = count + 1 end
        end
        
        row.nameText:SetText(string.format("%s (%d)", item.data.name or "Unnamed", count))
        
        if item.id == activeProfileID then
            row:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
        else
            row:SetBackdropBorderColor(0.15, 0.15, 0.18, 0.6)
        end
        
        row:SetScript("OnEnter", function()
            row:SetBackdropColor(0.12, 0.12, 0.15, 0.9)
            self.hoveredProfileBindings = item.data.bindings
            self:updatePreviewGrid(item.data.bindings)
        end)
        
        row:SetScript("OnLeave", function()
            row:SetBackdropColor(0.05, 0.05, 0.07, 0.8)
            self.hoveredProfileBindings = nil
            local activeProfile = activeProfileID and addon.db.global.profiles[activeProfileID]
            if activeProfile then
                self:updatePreviewGrid(activeProfile.bindings)
            else
                self:updatePreviewGrid(addon.profileManager:getCurrentBindings())
            end
        end)
        
        row.loadBtn:SetScript("OnClick", function()
            self:showCustomDialog("Load Profile", string.format("Apply profile '%s' to current action bars?", item.data.name), {
                {
                    text = "Confirm",
                    onClick = function()
                        addon:applyProfile(item.data.bindings, item.id)
                        self:updateProfileList()
                    end
                },
                {
                    text = "Cancel",
                    onClick = function() end
                }
            })
        end)
        
        row.deleteBtn:SetScript("OnClick", function()
            self:showCustomDialog("Delete Profile", string.format("Are you sure you want to delete '%s'?", item.data.name), {
                {
                    text = "Delete",
                    onClick = function()
                        addon.db.global.profiles[item.id] = nil
                        if activeProfileID == item.id then
                            addon.db.global.activeProfiles[classToken][specID] = nil
                        end
                        self:updateProfileList()
                        self:showToast("Profile Deleted", "success")
                    end
                },
                {
                    text = "Cancel",
                    onClick = function() end
                }
            })
        end)
        
        row.menuBtn:SetScript("OnClick", function()
            local menu = {
                { text = "Rename", func = function() self:showRenameDialog(item.id) end },
                { text = "Duplicate", func = function()
                    local newID = string.format("profile-%d", GetTime() * 1000)
                    local copy = {}
                    for k, v in pairs(item.data.bindings) do copy[k] = v end
                    addon.db.global.profiles[newID] = {
                        name = "Copy of " .. item.data.name,
                        classToken = item.data.classToken,
                        specID = item.data.specID,
                        bindings = copy
                    }
                    self:updateProfileList()
                    self:showToast("Profile Duplicated", "success")
                end }
            }
            -- Simple menu display inside dialog since standard WoW dropdowns can be complex
            self:showCustomDialog("Options: " .. item.data.name, "Choose action:", {
                { text = "Rename", onClick = menu[1].func },
                { text = "Duplicate", onClick = menu[2].func },
                { text = "Export", onClick = function() self:showExportImportDialog("export", item.data.bindings) end },
                { text = "Close", onClick = function() end }
            })
        end)
        
        row:Show()
    end
    
    scrollChild:SetHeight(#profilesList * rowHeight)
end

function UI:showRenameDialog(profileID)
    local addon = self.addon
    local profile = addon.db.global.profiles[profileID]
    if not profile then return end
    
    self:showInputDialog("Rename Profile", "Enter new name:", profile.name, function(newName)
        profile.name = newName
        self:updateProfileList()
        self:showToast("Profile Renamed", "success")
    end)
end

function UI:showCreateProfileDialog(onCancel)
    local addon = self.addon
    local classToken, specID = addon:getCurrentClassAndSpec()
    local _, specName = GetSpecializationInfoByID(specID)
    specName = specName or "Unknown"
    
    local defaultName = string.format("Default %s", specName)
    self:showInputDialog("Create Profile", "Enter name for new profile:", defaultName, function(profileName)
        local profileID = string.format("profile-%d", GetTime() * 1000)
        local currentBindings = addon.profileManager:getCurrentBindings()
        
        addon.db.global.profiles[profileID] = {
            name = profileName,
            classToken = classToken,
            specID = specID,
            bindings = currentBindings
        }
        
        if not addon.db.global.activeProfiles[classToken] then
            addon.db.global.activeProfiles[classToken] = {}
        end
        addon.db.global.activeProfiles[classToken][specID] = profileID
        
        addon.isInitialized = true
        
        self:updateProfileList()
        local activeProfile = addon.db.global.profiles[profileID]
        self:updatePreviewGrid(activeProfile.bindings)
        self:showToast("Profile Created", "success")
        self:updateSaveButtonState()
    end, function()
        if onCancel then onCancel() end
    end)
end

function UI:openConfigMenu()
    local addon = self.addon
    local uiContext = addon.uiContext
    local suitUI = LibStub:GetLibrary("AscensionSuit-UI", true)
    if not suitUI then
        error("AscensionSuit-UI not found! This addon requires AscensionSuit to run.")
    end

    if self.configFrame then
        self.configFrame:Show()
        self:updateSaveButtonState()
        if self.profileListFrame then
            self:updateProfileList()
        end
        return
    end

    local frame = CreateFrame("Frame", "AscensionProfilesConfigFrame", _G.UIParent, "BackdropTemplate")
    frame:SetSize(350, 300)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    
    local styles = uiContext.styles
    frame:SetBackdrop({
        bgFile = styles.files.bgFile,
        edgeFile = styles.files.edgeFile,
        edgeSize = 3,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(unpack(styles.colors.backgroundDark or styles.colors.mainBackground or {0.02, 0.02, 0.03, 0.95}))
    frame:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
    
    if suitUI.UX then
        suitUI.UX:makeMovable(frame)
        suitUI.UX:makeClosableWithEscape(frame)
    end
    
    local closeBtn = uiContext:createCloseButton(frame, function() frame:Hide() end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    
    local title = frame:CreateFontString(nil, "OVERLAY", styles and styles.fonts and styles.fonts.header or "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Keybind Profiles")
    title:SetTextColor(unpack(styles.colors.gold))
    
    local autoSyncCb = uiContext:createCheckbox({
        parent = frame,
        text = "Enable Auto-Sync",
        tooltip = "Automatically saves and loads profiles on changes and spec swaps.",
        getter = function() return addon.db.global.enableAutoSync end,
        setter = function(val) addon.db.global.enableAutoSync = val end
    })
    autoSyncCb:ClearAllPoints()
    autoSyncCb:SetPoint("TOP", title, "BOTTOM", -65, -8)
    
    local activeProfileLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    activeProfileLabel:SetPoint("TOP", frame, "TOP", 0, -82)
    
    local function updateLabel()
        local currentClass, currentClassToken = UnitClass("player")
        local currentSpecID = GetSpecialization() and GetSpecializationInfo(GetSpecialization()) or 0
        local _, currentSpecName = GetSpecializationInfoByID(currentSpecID)
        currentSpecName = currentSpecName or "No Spec"
        
        local activeProfileID = addon.db.global.activeProfiles[currentClassToken] and addon.db.global.activeProfiles[currentClassToken][currentSpecID]
        local activeProfile = activeProfileID and addon.db.global.profiles[activeProfileID]
        local profileName = activeProfile and activeProfile.name or "No Profile Active"
        
        activeProfileLabel:SetText(string.format("%s - %s\n(|cFFFFD100%s|r)", currentClass, currentSpecName, profileName))
        
        local newColorTable = RAID_CLASS_COLORS[currentClassToken]
        if newColorTable then
            activeProfileLabel:SetTextColor(newColorTable.r, newColorTable.g, newColorTable.b, 1)
        end
        
        if activeProfile then
            self:updatePreviewGrid(activeProfile.bindings)
        else
            self:updatePreviewGrid(addon.profileManager:getCurrentBindings())
        end
        self:updateSaveButtonState()
    end
    
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:SetScript("OnEvent", updateLabel)
    
    local saveBtn = uiContext:createButton({
        parent = frame,
        text = "Save Profile",
        onClick = function()
            addon:saveProfileManually()
            updateLabel()
        end,
        width = 100,
        height = 28
    })
    saveBtn:ClearAllPoints()
    saveBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -145)
    frame.saveBtn = saveBtn
    
    local loadBtn = uiContext:createButton({
        parent = frame,
        text = "Load Profile",
        onClick = function()
            addon:loadProfileManually()
            updateLabel()
        end,
        width = 100,
        height = 28
    })
    loadBtn:ClearAllPoints()
    loadBtn:SetPoint("TOP", saveBtn, "TOP", 0, 0)
    loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    
    local manageBtn = uiContext:createButton({
        parent = frame,
        text = "Profiles",
        onClick = function()
            if not self.profileListFrame then
                self:createProfileListPanel(frame)
            end
            if self.profileListFrame:IsShown() then
                self.profileListFrame:Hide()
            else
                self:updateProfileList()
                self.profileListFrame:Show()
            end
        end,
        width = 100,
        height = 28
    })
    manageBtn:ClearAllPoints()
    manageBtn:SetPoint("TOP", loadBtn, "TOP", 0, 0)
    manageBtn:SetPoint("LEFT", loadBtn, "RIGHT", 10, 0)
    
    self.configFrame = frame
    
    self:createPreviewGrid(frame)
    updateLabel()
    
    frame:Show()
end

function UI:updateSaveButtonState()
    if not self.configFrame or not self.configFrame.saveBtn then return end
    local addon = self.addon
    local classToken, specID = addon:getCurrentClassAndSpec()
    local activeProfileID = addon.db.global.activeProfiles[classToken] and addon.db.global.activeProfiles[classToken][specID]
    local activeProfile = activeProfileID and addon.db.global.profiles[activeProfileID]
    
    local hasChanges = false
    if activeProfile then
        local current = addon.profileManager:getCurrentBindings()
        hasChanges = addon.profileManager:areBindingsDifferent(current, activeProfile.bindings)
    end
    
    if hasChanges then
        self.configFrame.saveBtn.text:SetText("Save Profile*")
    else
        self.configFrame.saveBtn.text:SetText("Save Profile")
    end
end

function UI:showMacroConflictDialog(newMacros, conflicts, onApply, onCancel)
    local addon = self.addon
    local styles = addon.uiContext.styles
    
    if not self.conflictDialog then
        local frame = CreateFrame("Frame", "AscensionProfilesMacroConflictDialog", _G.UIParent, "BackdropTemplate")
        frame:SetSize(480, 380)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        
        frame:SetBackdrop({
            bgFile = styles.files.bgFile,
            edgeFile = styles.files.edgeFile,
            edgeSize = 3,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(unpack(styles.colors.backgroundDark or styles.colors.mainBackground or {0.02, 0.02, 0.03, 0.95}))
        frame:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
        
        local closeBtn = addon.uiContext:createCloseButton(frame, function()
            frame:Hide()
            if self.diffPanel then self.diffPanel:Hide() end
            onCancel()
        end)
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", -8, -8)
        
        local title = frame:CreateFontString(nil, "OVERLAY", styles and styles.fonts and styles.fonts.header or "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("Macro Conflicts")
        title:SetTextColor(unpack(styles.colors.gold))
        
        local scrollFrame = CreateFrame("ScrollFrame", "AscensionMacroConflictScrollFrame", frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(430, 240)
        scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -45)
        
        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetSize(430, 240)
        scrollFrame:SetScrollChild(scrollChild)
        frame.scrollChild = scrollChild
        
        local applyBtn = addon.uiContext:createButton({
            parent = frame,
            text = "Apply Selected",
            onClick = function() end,
            width = 130,
            height = 22
        })
        applyBtn:ClearAllPoints()
        applyBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
        frame.applyBtn = applyBtn
        
        local skipBtn = addon.uiContext:createButton({
            parent = frame,
            text = "Skip All",
            onClick = function() end,
            width = 130,
            height = 22
        })
        skipBtn:ClearAllPoints()
        skipBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
        frame.skipBtn = skipBtn
        
        local cancelBtn = addon.uiContext:createButton({
            parent = frame,
            text = "Cancel",
            onClick = function()
                frame:Hide()
                if self.diffPanel then self.diffPanel:Hide() end
                onCancel()
            end,
            width = 130,
            height = 22
        })
        cancelBtn:ClearAllPoints()
        cancelBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 15)
        
        tinsert(UISpecialFrames, "AscensionProfilesMacroConflictDialog")
        self.conflictDialog = frame
    end
    
    local frame = self.conflictDialog
    local scrollChild = frame.scrollChild
    
    if not scrollChild.rows then
        scrollChild.rows = {}
    end
    for _, row in ipairs(scrollChild.rows) do
        row:Hide()
    end
    
    if not self.diffPanel then
        local diff = CreateFrame("Frame", "AscensionProfilesMacroDiffPanel", _G.UIParent, "BackdropTemplate")
        diff:SetSize(350, 380)
        diff:SetPoint("LEFT", frame, "RIGHT", 5, 0)
        diff:SetFrameStrata("DIALOG")
        diff:SetClampedToScreen(true)
        
        diff:SetBackdrop({
            bgFile = styles.files.bgFile,
            edgeFile = styles.files.edgeFile,
            edgeSize = 3,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        diff:SetBackdropColor(unpack(styles.colors.backgroundDark or styles.colors.mainBackground or {0.02, 0.02, 0.03, 0.95}))
        diff:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
        
        local diffTitle = diff:CreateFontString(nil, "OVERLAY", styles and styles.fonts and styles.fonts.header or "GameFontNormalLarge")
        diffTitle:SetPoint("TOP", 0, -16)
        diffTitle:SetText("Body Comparison")
        diffTitle:SetTextColor(unpack(styles.colors.gold))
        
        local leftHeader = diff:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        leftHeader:SetPoint("TOPLEFT", diff, "TOPLEFT", 15, -45)
        leftHeader:SetText("Current Macro")
        leftHeader:SetTextColor(0.85, 0.4, 0.4, 1)
        
        local leftScroll = CreateFrame("ScrollFrame", "AscensionDiffLeftScroll", diff, "UIPanelScrollFrameTemplate")
        leftScroll:SetSize(150, 260)
        leftScroll:SetPoint("TOPLEFT", diff, "TOPLEFT", 15, -60)
        local leftEdit = CreateFrame("EditBox", nil, leftScroll)
        leftEdit:SetMultiLine(true)
        leftEdit:SetWidth(130)
        leftEdit:SetFontObject("ChatFontNormal")
        leftEdit:SetTextColor(0.85, 0.5, 0.5, 1)
        leftEdit:SetEnabled(false)
        leftScroll:SetScrollChild(leftEdit)
        diff.leftEdit = leftEdit
        
        local rightHeader = diff:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rightHeader:SetPoint("TOPRIGHT", diff, "TOPRIGHT", -15, -45)
        rightHeader:SetText("New Macro")
        rightHeader:SetTextColor(0.4, 0.85, 0.4, 1)
        
        local rightScroll = CreateFrame("ScrollFrame", "AscensionDiffRightScroll", diff, "UIPanelScrollFrameTemplate")
        rightScroll:SetSize(150, 260)
        rightScroll:SetPoint("TOPRIGHT", diff, "TOPRIGHT", -30, -60)
        local rightEdit = CreateFrame("EditBox", nil, rightScroll)
        rightEdit:SetMultiLine(true)
        rightEdit:SetWidth(130)
        rightEdit:SetFontObject("ChatFontNormal")
        rightEdit:SetTextColor(0.5, 0.85, 0.5, 1)
        rightEdit:SetEnabled(false)
        rightScroll:SetScrollChild(rightEdit)
        diff.rightEdit = rightEdit
        
        self.diffPanel = diff
    end
    
    local diffPanel = self.diffPanel
    diffPanel:Hide()
    
    local function getMacroPreview(body)
        if not body then return "" end
        for line in string.gmatch(body, "[^\r\n]+") do
            if string.find(line, "^/cast") or string.find(line, "^/use") then
                if #line > 30 then
                    return string.sub(line, 1, 30) .. "..."
                else
                    return line
                end
            end
        end
        local firstLine = string.match(body, "[^\r\n]+") or ""
        if #firstLine > 30 then
            return string.sub(firstLine, 1, 30) .. "..."
        else
            return firstLine
        end
    end
    
    local rowHeight = 62
    for idx, c in ipairs(conflicts) do
        local row = scrollChild.rows[idx]
        if not row then
            row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetSize(420, 58)
            row:SetBackdrop({
                bgFile = styles.files.bgFile,
                edgeFile = styles.files.edgeFile,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            row:SetBackdropColor(0.05, 0.05, 0.07, 0.8)
            row:SetBackdropBorderColor(0.15, 0.15, 0.18, 0.6)
            
            local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetPoint("LEFT", row, "LEFT", 10, 0)
            row.checkbox = cb
            
            local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameText:SetPoint("TOPLEFT", cb, "TOPRIGHT", 10, 2)
            row.nameText = nameText
            
            local currentText = row:CreateFontString(nil, "OVERLAY")
            currentText:SetFontObject("GameFontNormalSmall")
            currentText:SetTextColor(0.8, 0.4, 0.4, 1)
            currentText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
            row.currentText = currentText
            
            local newText = row:CreateFontString(nil, "OVERLAY")
            newText:SetFontObject("GameFontNormalSmall")
            newText:SetTextColor(0.4, 0.8, 0.4, 1)
            newText:SetPoint("TOPLEFT", currentText, "BOTTOMLEFT", 0, -2)
            row.newText = newText
            
            scrollChild.rows[idx] = row
        end
        
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(idx - 1) * rowHeight)
        row.checkbox:SetChecked(true)
        row.nameText:SetText(c.name)
        
        local _, _, existingBody = GetMacroInfo(c.existingIndex)
        row.currentText:SetText("Current: " .. getMacroPreview(existingBody))
        row.newText:SetText("New: " .. getMacroPreview(c.body))
        
        local function highlightRow(highlight)
            if highlight then
                row:SetBackdropColor(0.12, 0.12, 0.15, 0.9)
                row:SetBackdropBorderColor(unpack(styles.colors.gold))
            else
                row:SetBackdropColor(0.05, 0.05, 0.07, 0.8)
                row:SetBackdropBorderColor(0.15, 0.15, 0.18, 0.6)
            end
        end
        
        row:SetScript("OnEnter", function() highlightRow(true) end)
        row:SetScript("OnLeave", function() highlightRow(false) end)
        
        row:SetScript("OnClick", function()
            diffPanel.leftEdit:SetText(existingBody or "")
            diffPanel.rightEdit:SetText(c.body or "")
            diffPanel:Show()
        end)
        
        row:Show()
    end
    
    scrollChild:SetHeight(#conflicts * rowHeight)
    
    frame.applyBtn:SetScript("OnClick", function()
        frame:Hide()
        diffPanel:Hide()
        local selected = {}
        for idx, c in ipairs(conflicts) do
            local row = scrollChild.rows[idx]
            if row and row.checkbox:GetChecked() then
                table.insert(selected, c)
            end
        end
        onApply(selected)
    end)
    
    frame.skipBtn:SetScript("OnClick", function()
        frame:Hide()
        diffPanel:Hide()
        onApply({})
    end)
    
    frame:Show()
end

function UI:showExportImportDialog(mode, bindingsOrCallback)
    local addon = self.addon
    local styles = addon.uiContext.styles
    
    if not self.exportImportDialog then
        local frame = CreateFrame("Frame", "AscensionProfilesExportImportDialog", _G.UIParent, "BackdropTemplate")
        frame:SetSize(450, 320)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        
        frame:SetBackdrop({
            bgFile = styles.files.bgFile,
            edgeFile = styles.files.edgeFile,
            edgeSize = 3,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(unpack(styles.colors.backgroundDark or styles.colors.mainBackground or {0.02, 0.02, 0.03, 0.95}))
        frame:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
        
        local closeBtn = addon.uiContext:createCloseButton(frame, function() frame:Hide() end)
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", -8, -8)
        
        local title = frame:CreateFontString(nil, "OVERLAY", styles and styles.fonts and styles.fonts.header or "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetTextColor(unpack(styles.colors.gold))
        frame.titleStr = title
        
        local scrollFrame = CreateFrame("ScrollFrame", "AscensionExportImportScrollFrame", frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetSize(380, 180)
        scrollFrame:SetPoint("TOP", frame, "TOP", -10, -50)
        
        local editBox = CreateFrame("EditBox", "AscensionExportImportEditBox", scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetMaxLetters(99999)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(360)
        editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox
        
        local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("TOP", scrollFrame, "BOTTOM", 0, -10)
        frame.statusText = statusText
        
        local actionBtn = addon.uiContext:createButton({
            parent = frame,
            text = "",
            onClick = function() end,
            width = 140,
            height = 22
        })
        actionBtn:ClearAllPoints()
        actionBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 50, 15)
        frame.actionBtn = actionBtn
        
        local cancelBtn = addon.uiContext:createButton({
            parent = frame,
            text = "Close",
            onClick = function() frame:Hide() end,
            width = 140,
            height = 22
        })
        cancelBtn:ClearAllPoints()
        cancelBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -50, 15)
        frame.cancelBtn = cancelBtn
        
        tinsert(UISpecialFrames, "AscensionProfilesExportImportDialog")
        self.exportImportDialog = frame
    end
    
    local frame = self.exportImportDialog
    frame.statusText:SetText("")
    
    if mode == "export" then
        frame.titleStr:SetText("Export Profile")
        local serialized = Util.serializeBindings(bindingsOrCallback)
        local encoded = Util.encodeBase64(serialized)
        frame.editBox:SetText(encoded)
        frame.editBox:SetEnabled(true)
        frame.editBox:SetFocus()
        frame.editBox:HighlightText()
        
        frame.actionBtn.text:SetText("Select All")
        frame.actionBtn:SetScript("OnClick", function()
            frame.editBox:SetFocus()
            frame.editBox:HighlightText()
            self:showToast("Text Selected", "success")
        end)
        
        frame.cancelBtn.text:SetText("Close")
    else
        frame.titleStr:SetText("Import Profile")
        frame.editBox:SetText("")
        frame.editBox:SetEnabled(true)
        frame.editBox:SetFocus()
        
        frame.actionBtn.text:SetText("Import")
        frame.actionBtn:SetScript("OnClick", function()
            local text = frame.editBox:GetText()
            local decoded = Util.decodeBase64(text)
            if not decoded then
                frame.statusText:SetText("Invalid profile string")
                frame.statusText:SetTextColor(0.85, 0.15, 0.15)
                return
            end
            
            local bindings = Util.deserializeBindings(decoded)
            local count = 0
            for _ in pairs(bindings) do count = count + 1 end
            
            if count == 0 then
                frame.statusText:SetText("Invalid profile string")
                frame.statusText:SetTextColor(0.85, 0.15, 0.15)
                return
            end
            
            frame:Hide()
            bindingsOrCallback(bindings)
        end)
        
        frame.cancelBtn.text:SetText("Cancel")
    end
    
    frame:Show()
end

function UI:registerOptionsUI()
    local addon = self.addon
    local suitUI = LibStub:GetLibrary("AscensionSuit-UI", true)
    if not suitUI then
        error("AscensionSuit-UI not found! This addon requires AscensionSuit to run.")
    end

    suitUI.Integration:registerBlizzardPanel(
        "AscensionKeybindSync",
        "Keybind Profiles",
        function() self:openConfigMenu() end
    )

    SLASH_ASCENSIONKEYBINDSYNC1 = "/aks"
    SlashCmdList["ASCENSIONKEYBINDSYNC"] = function(msg)
        local command = string.lower(msg or ""):match("^%s*(.-)%s*$")
        if command == "save" then
            addon:saveProfileManually()
        elseif command == "load" then
            addon:loadProfileManually()
        elseif command == "delete" then
            local classToken, specID = addon:getCurrentClassAndSpec()
            local activeProfileID = addon.db.global.activeProfiles[classToken] and addon.db.global.activeProfiles[classToken][specID]
            if activeProfileID then
                self:showCustomDialog("Delete Profile", "Are you sure you want to delete current profile?", {
                    {
                        text = "Delete",
                        onClick = function()
                            addon.db.global.profiles[activeProfileID] = nil
                            addon.db.global.activeProfiles[classToken][specID] = nil
                            self:showToast("Profile Deleted", "success")
                            if self.configFrame then
                                self.configFrame:Hide()
                            end
                        end
                    },
                    {
                        text = "Cancel",
                        onClick = function() end
                    }
                })
            else
                addon:printMessage("No active profile to delete.")
            end
        elseif command == "status" then
            local classToken, specID = addon:getCurrentClassAndSpec()
            local activeProfileID = addon.db.global.activeProfiles[classToken] and addon.db.global.activeProfiles[classToken][specID]
            local activeProfile = activeProfileID and addon.db.global.profiles[activeProfileID]
            addon:printMessage("Auto-Sync: " .. (addon.db.global.enableAutoSync and "Enabled" or "Disabled"))
            if activeProfile then
                addon:printMessage("Active Profile: " .. activeProfile.name)
            else
                addon:printMessage("Active Profile: None")
            end
        elseif command == "help" then
            addon:printMessage("Commands:")
            addon:printMessage("  /aks - Open configuration window")
            addon:printMessage("  /aks save - Save current profile")
            addon:printMessage("  /aks load - Load current profile")
            addon:printMessage("  /aks delete - Delete current active profile")
            addon:printMessage("  /aks status - Check sync status")
        else
            self:openConfigMenu()
        end
    end
end

addonTable.UI = UI
