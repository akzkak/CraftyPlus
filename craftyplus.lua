-- CraftyPlus.lua
-- Enhanced profession window for vanilla WoW (1.12)

--[[
  CraftyPlus: Vanilla (1.12) crafting addon originally by shirsig (https://github.com/shirsig/crafty).
  This version includes:
    1) Right-click "favorite" fix.
    2) Preservation of scroll offset after favoriting an item so we don't jump back to top.
    3) Split chat messaging:
       - First message: the item link.
       - Subsequent messages: the reagents (with "(cont.) " prefix when needed).
    4) Modern pfUI-like styling with dark backgrounds and gold text
--]]

local craftyplus = CreateFrame'Frame'

-- Set up update handler
craftyplus:SetScript('OnUpdate', function()
	this:UPDATE()
end)

-- Set up event handler
craftyplus:SetScript('OnEvent', function()
	this[event](this)
end)
craftyplus:RegisterEvent'ADDON_LOADED'

-- Saved favorites table
craftyplus_favorites = {}

local TRADE, CRAFT = 1, 2
local ALT = false

-- Frame definitions for trade/craft
craftyplus.frames = {
	trade = {
		elements = {
			Main       = 'TradeSkillFrame',
			Title      = 'TradeSkillFrameTitleText',
			Scroll     = 'TradeSkillListScrollFrame',
			ScrollBar  = 'TradeSkillListScrollFrameScrollBar',
			Highlight  = 'TradeSkillHighlightFrame',
			CollapseAll= 'TradeSkillCollapseAllButton',
		},
		anchor = {'TOPLEFT', 'TradeSkillCreateAllButton', 'BOTTOMLEFT', -7, 77},
	},
	craft = {
		elements = {
			Main      = 'CraftFrame',
			Title     = 'CraftFrameTitleText',
			Scroll    = 'CraftListScrollFrame',
			ScrollBar = 'CraftListScrollFrameScrollBar',
			Highlight = 'CraftHighlightFrame',
		},
		anchor = {'TOPRIGHT', 'CraftCancelButton', 'BOTTOMRIGHT', -4, 77}
	},
}

-----------------------------------------------------------------------
-- Popup for selecting where/how to link the mats
-----------------------------------------------------------------------
do
	local function action()
	    local input = strlower(getglobal(this:GetParent():GetName()..'EditBox'):GetText())
	    if tonumber(input) then
	    	craftyplus:SendReagentMessage('CHANNEL', input)
		elseif input == 'guild' or input == 'g' then
			craftyplus:SendReagentMessage'GUILD'
		elseif input == 'o' then
			craftyplus:SendReagentMessage'OFFICER'
		elseif input == 'raid' or input == 'ra' then
			craftyplus:SendReagentMessage'RAID'
		elseif input == 'rw' then
			craftyplus:SendReagentMessage'RAID_WARNING'
		elseif input == 'bg' then
			craftyplus:SendReagentMessage'BATTLEGROUND'
		elseif input == 'party' or input == 'p' then
			craftyplus:SendReagentMessage'PARTY'
		elseif input == 'say' or input == 's' then
			craftyplus:SendReagentMessage'SAY'
		elseif input == 'yell' or input == 'y' then
			craftyplus:SendReagentMessage'YELL'
		elseif input == 'emote' or input == 'em' then
			craftyplus:SendReagentMessage'EMOTE'
		elseif input == 'reply' or input == 'r' then
			if ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' then
				craftyplus:SendReagentMessage('WHISPER', ChatEdit_GetLastTellTarget(ChatFrameEditBox))
			end
		elseif strlen(input) > 1 then
			craftyplus:SendReagentMessage('WHISPER', gsub(input, '^@', ''))
		end
	end

	StaticPopupDialogs['CRAFTYPLUS_LINK'] = {
	    text = 'Enter a character name or channel.',
	    button1 = 'Link',
	    button2 = 'Cancel',
	    hasEditBox = 1,
	    OnShow = function()
	    	local editBox = getglobal(this:GetName()..'EditBox')
			editBox:SetText('')
			editBox:SetFocus()
		end,
	    OnAccept = action,
	    EditBoxOnEnterPressed = function()
	    	action()
			this:GetParent():Hide()
		end,
		EditBoxOnEscapePressed = function()
			this:GetParent():Hide()
		end,
	    timeout = 0,
	    hideOnEscape = 1,
	}
end

-----------------------------------------------------------------------
-- Tracking "state" per profession: search text, materials toggle, favorites
-----------------------------------------------------------------------
do
	local state = {}
	function craftyplus:State()
		local profession
		if self.mode == TRADE then
			profession = GetTradeSkillLine()
		elseif self.mode == CRAFT then
			profession = GetCraftSkillLine(1)
		end
		profession = profession or '' -- fallback

		craftyplus_favorites[profession] = craftyplus_favorites[profession] or {}
		state[profession] = state[profession] or {
			searchText = '',
			materials  = false,
			favorites  = craftyplus_favorites[profession],
		}
		return state[profession]
	end
end

-----------------------------------------------------------------------
-- Throttle the update event
-----------------------------------------------------------------------
function craftyplus:UPDATE()
	-- ALT toggling
	if not not IsAltKeyDown() ~= ALT and self.frame and self.frame:IsShown() then
		ALT = not ALT
		self.update_required = true
	end

	if self.update_required then
		self.update_required = nil
		self.currentFrame.orig_update()
		self:UpdateListing()
	end
end

-----------------------------------------------------------------------
-- ADDON_LOADED: Setup the main frame and hooks
-----------------------------------------------------------------------
function craftyplus:ADDON_LOADED()
    if arg1 ~= 'CraftyPlus' then
        return
    end

    self.found = {}

    self:RegisterEvent'TRADE_SKILL_SHOW'
    self:RegisterEvent'CRAFT_SHOW'
    
    -- Hook SetItemRef to allow SHIFT-clicking a name into the link popup
    local origSetItemRef = SetItemRef
    SetItemRef = function(...)
        local popup = StaticPopup_FindVisible'CRAFTYPLUS_LINK'
        local _, _, playerName = strfind(unpack(arg), 'player:(.+)')
        if popup and IsShiftKeyDown() and playerName then
            getglobal(popup:GetName()..'EditBox'):SetText(playerName)
            return
        end
        return origSetItemRef(unpack(arg))
    end

    -- Get references to our XML-defined frames
    self.frame = CraftyPlusFrame
    self.frame.SearchBox = CraftyPlusSearchBox
    self.frame.MaterialsButton = CraftyPlusMaterialsButton
    self.frame.LinkButton = CraftyPlusLinkButton
    self.frame.SearchBox.ClearButton = CraftyPlusSearchBoxClearButton  -- Store reference to clear button

    -- Add search icon texture programmatically
    local searchIcon = self.frame.SearchBox:CreateTexture("CraftyPlusSearchBoxSearchIcon", "OVERLAY")
    searchIcon:SetTexture("Interface\\AddOns\\CraftyPlus\\icons\\UI-Searchbox-Icon")
    searchIcon:SetPoint("LEFT", self.frame.SearchBox, "LEFT", 5, -2)
    searchIcon:SetWidth(16)
    searchIcon:SetHeight(16)
    searchIcon:SetVertexColor(0.6, 0.6, 0.6)

    -- Add clear button texture programmatically
    local clearButtonTex = CraftyPlusSearchBoxClearButton:CreateTexture("CraftyPlusSearchBoxClearButtonTexture", "ARTWORK")
    clearButtonTex:SetTexture("Interface\\AddOns\\CraftyPlus\\icons\\ClearBroadcastIcon")
    clearButtonTex:SetPoint("TOPLEFT", 0, 0)
    clearButtonTex:SetWidth(17)
    clearButtonTex:SetHeight(17)
    clearButtonTex:SetAlpha(0.5)
    CraftyPlusSearchBoxClearButton.tex = clearButtonTex

    -- Set up instructions text
    CraftyPlusSearchBoxInstructions:SetText("Search")

    -- Setup event handlers for search box
    self.frame.SearchBox:SetScript('OnEnterPressed', function()
        this:ClearFocus()
    end)

    self.frame.SearchBox:SetScript('OnEditFocusGained', function()
        this.focused = true
        CraftyPlusSearchBoxSearchIcon:SetVertexColor(1, 1, 1)
        CraftyPlusSearchBoxClearButton:Show()
    end)

    self.frame.SearchBox:SetScript('OnEditFocusLost', function()
        this.focused = false
        if this:GetText() == '' then
            CraftyPlusSearchBoxSearchIcon:SetVertexColor(.6, .6, .6)
            CraftyPlusSearchBoxClearButton:Hide()
        end
    end)

    self.frame.SearchBox:SetScript('OnTextChanged', function()
        if this:GetText() == '' then
            CraftyPlusSearchBoxInstructions:Show()
        else
            CraftyPlusSearchBoxInstructions:Hide()
        end
        if this:GetText() == '' and not this.focused then
            CraftyPlusSearchBoxSearchIcon:SetVertexColor(.6, .6, .6)
            CraftyPlusSearchBoxClearButton:Hide()
        else
            CraftyPlusSearchBoxSearchIcon:SetVertexColor(1, 1, 1)
            CraftyPlusSearchBoxClearButton:Show()
        end
        craftyplus:Search()
    end)

    -- Clear button
    CraftyPlusSearchBoxClearButton:SetScript('OnEnter', function()
        CraftyPlusSearchBoxClearButtonTexture:SetAlpha(1)
    end)
    CraftyPlusSearchBoxClearButton:SetScript('OnLeave', function()
        CraftyPlusSearchBoxClearButtonTexture:SetAlpha(.5)
    end)
    CraftyPlusSearchBoxClearButton:SetScript('OnMouseUp', function()
        CraftyPlusSearchBoxClearButtonTexture:SetPoint('TOPLEFT', 0, 0)
    end)
    CraftyPlusSearchBoxClearButton:SetScript('OnMouseDown', function()
        CraftyPlusSearchBoxClearButtonTexture:SetPoint('TOPLEFT', 1, -1)
    end)
    CraftyPlusSearchBoxClearButton:SetScript('OnClick', function()
        PlaySound'igMainMenuOptionCheckBoxOn'
        CraftyPlusSearchBox:SetText''
        CraftyPlusSearchBox:ClearFocus()
    end)

    -- Materials button
    self.frame.MaterialsButton:SetScript('OnClick', function()
        self:State().materials = not self:State().materials
        if self:State().materials then
            this:LockHighlight()
        else
            this:UnlockHighlight()
        end
        self:Search()
    end)

    -- Link button
    self.frame.LinkButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    self.frame.LinkButton:SetScript('OnClick', function()
        if StaticPopup_Visible'CRAFTYPLUS_LINK' then
            StaticPopup_Hide'CRAFTYPLUS_LINK'
        elseif arg1 == 'RightButton' then
            StaticPopup_Show'CRAFTYPLUS_LINK'
        end

        if arg1 == 'LeftButton' then
            local channel = GetNumPartyMembers() == 0 and 'WHISPER' or 'PARTY'
            if channel == 'PARTY' or ChatEdit_GetLastTellTarget(ChatFrameEditBox) ~= '' then
                craftyplus:SendReagentMessage(channel, ChatEdit_GetLastTellTarget(ChatFrameEditBox))
            end
        end
    end)
end

-----------------------------------------------------------------------
-- Relevel function (so the search box is on top)
-----------------------------------------------------------------------
function craftyplus:Relevel(frame)
	for _, child in ipairs({frame:GetChildren()}) do
		child:SetFrameLevel(frame:GetFrameLevel() + 1)
		self:Relevel(child)
	end
end

-----------------------------------------------------------------------
-- CRAFT_SHOW: hook craft window
-----------------------------------------------------------------------
function craftyplus:CRAFT_SHOW()
    if not GetCraftDisplaySkillLine() then
        return
    end

    self.mode = CRAFT
    self.currentFrame = self.frames.craft

    -- first time window has been opened
    if not self.currentFrame.orig_update then
        self:RegisterEvent'CRAFT_CLOSE'
        self.currentFrame.orig_update = CraftFrame_Update
        CraftFrame_Update = function() self.update_required = true end

        -- Hook however many lines Turtle WoW or your server might show (common is 23).
        local displayed = CRAFTS_DISPLAYED or 23

        for i = 1, displayed do
            local button = getglobal('Craft'..i)
            if button then
                -- Double-click => filter by item name
                button:SetScript('OnDoubleClick', function()
                    self.frame.SearchBox:SetText(GetCraftInfo(this:GetID()))
                end)

                -- Save original OnClick for normal left-click selection
                local oldOnClick = button:GetScript('OnClick')
                button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

                button:SetScript('OnClick', function()
                    if arg1 == 'RightButton' then
                        -- Preserve current scroll offset so we don't jump back to top
                        local offset      = FauxScrollFrame_GetOffset(getglobal(self.currentFrame.elements.Scroll))
                        local scrollValue = getglobal(self.currentFrame.elements.ScrollBar):GetValue()

                        local favorites, name = self:State().favorites, GetCraftInfo(this:GetID())
                        if name then
                            favorites[name] = not favorites[name] or nil
                            self:Search()
                        end

                        -- Restore scroll offset
                        FauxScrollFrame_SetOffset(getglobal(self.currentFrame.elements.Scroll), offset)
                        getglobal(self.currentFrame.elements.ScrollBar):SetValue(scrollValue)
                    else
                        -- Left-click -> original logic
                        if oldOnClick then
                            oldOnClick()
                        end
                    end
                end)
            end
        end
    end

    -- Hide trade window if open
    if getglobal(self.frames.trade.elements.Main)
       and getglobal(self.frames.trade.elements.Main):IsShown() then
        getglobal(self.frames.trade.elements.Main):Hide()
    end

    self:Show()
end

-----------------------------------------------------------------------
-- TRADE_SKILL_SHOW: hook trade skill window
-----------------------------------------------------------------------
function craftyplus:TRADE_SKILL_SHOW()
    self.mode = TRADE
    self.currentFrame = self.frames.trade

    -- first time window has been opened
    if not self.currentFrame.orig_update then
        self:RegisterEvent'TRADE_SKILL_CLOSE'
        self.currentFrame.orig_update = TradeSkillFrame_Update
        TradeSkillFrame_Update = function() self.update_required = true end

        -- Same logic for trade. If your server shows 23 lines, set 23 here.
        local displayed = TRADE_SKILLS_DISPLAYED or 23

        for i = 1, displayed do
            local button = getglobal('TradeSkillSkill'..i)
            if button then
                button:SetScript('OnDoubleClick', function()
                    self.frame.SearchBox:SetText(GetTradeSkillInfo(this:GetID()))
                end)

                local oldOnClick = button:GetScript('OnClick')
                button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

                button:SetScript('OnClick', function()
                    if arg1 == 'RightButton' then
                        -- Preserve current scroll offset
                        local offset      = FauxScrollFrame_GetOffset(getglobal(self.currentFrame.elements.Scroll))
                        local scrollValue = getglobal(self.currentFrame.elements.ScrollBar):GetValue()

                        local favorites, name = self:State().favorites, GetTradeSkillInfo(this:GetID())
                        if name then
                            favorites[name] = not favorites[name] or nil
                            self:Search()
                        end

                        -- Restore scroll offset
                        FauxScrollFrame_SetOffset(getglobal(self.currentFrame.elements.Scroll), offset)
                        getglobal(self.currentFrame.elements.ScrollBar):SetValue(scrollValue)
                    else
                        -- Left-click -> original logic
                        if oldOnClick then
                            oldOnClick()
                        end
                    end
                end)
            end
        end
    end

    -- Hide craft window if open
    if getglobal(self.frames.craft.elements.Main)
       and getglobal(self.frames.craft.elements.Main):IsShown() then
        getglobal(self.frames.craft.elements.Main):Hide()
    end

    self:Show()
end

-----------------------------------------------------------------------
-- Show the overlay
-----------------------------------------------------------------------
function craftyplus:Show()
	self.currentFrame.orig_update()

	self.frame:SetParent(self.currentFrame.elements.Main)
	self:Relevel(self.frame)
	self.frame:ClearAllPoints()
	self.frame:SetPoint(unpack(self.currentFrame.anchor))

	self.frame:Show()

	-- Materials highlight if toggled
	if self:State().materials then
		self.frame.MaterialsButton:LockHighlight()
	else
		self.frame.MaterialsButton:UnlockHighlight()
	end

	self.frame.SearchBox:SetText(self:State().searchText)
	self:Search()
end

-----------------------------------------------------------------------
-- Close events
-----------------------------------------------------------------------
function craftyplus:CRAFT_CLOSE()
	craftyplus:Close()
end
function craftyplus:TRADE_SKILL_CLOSE()
	craftyplus:Close()
end

function craftyplus:Close()
	self.frame:Hide()
	StaticPopup_Hide'CRAFTYPLUS_LINK'
end

-----------------------------------------------------------------------
-- UpdateListing: called after building the list to refresh the UI
-----------------------------------------------------------------------
function craftyplus:UpdateListing()
	-- Re-enable the first skill button if disabled by a "No results" message
	getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..1):Enable()

	if (self:State().searchText ~= '' or self:State().materials or next(self:State().favorites) and not ALT)
	   and getglobal(self.currentFrame.elements.Main):IsShown() then

		local skillOffset = FauxScrollFrame_GetOffset(getglobal(self.currentFrame.elements.Scroll))
		local skillButton

		self:BuildList()

		if self.mode == TRADE then
			getglobal(self.frames.trade.elements.CollapseAll):Disable()
			for i = 1, TRADE_SKILLS_DISPLAYED do
				getglobal('TradeSkillSkill'..i..'Text'):SetPoint('TOPLEFT', 'TradeSkillSkill'..i, 'TOPLEFT', 3, 0)
			end
		end

		FauxScrollFrame_Update(
			getglobal(self.currentFrame.elements.Scroll),
			getn(self.found),
			(self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED),
			(self.mode == CRAFT and CRAFT_SKILL_HEIGHT or TRADE_SKILL_HEIGHT),
			nil, nil, nil,
			getglobal(self.currentFrame.elements.Highlight),
			293, 316
		)
		getglobal(self.currentFrame.elements.Highlight):Hide()

		if getn(self.found) > 0 then
			for i = 1, (self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED) do
				local skillIndex = i + skillOffset
				skillButton = getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i)

				if self.found[skillIndex] then
					if getglobal(self.currentFrame.elements.Scroll):IsVisible() then
						skillButton:SetWidth(293)
					else
						skillButton:SetWidth(323)
					end

					local color = (self.mode == CRAFT and CraftTypeColor[self.found[skillIndex].type]
					               or TradeSkillTypeColor[self.found[skillIndex].type])
					if color then
						skillButton:SetTextColor(color.r, color.g, color.b)
					end

					skillButton:SetID(self.found[skillIndex].index)
					skillButton:Show()

					if self.found[skillIndex].name == '' then
						return
					end

					skillButton:SetNormalTexture('')
					getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i..'Highlight'):SetTexture('')

					if self.found[skillIndex].available == 0 then
						skillButton:SetText(' '..self.found[skillIndex].name)
					else
						skillButton:SetText(' '..self.found[skillIndex].name..' ['..self.found[skillIndex].available..']')
					end

					local currentSel = (self.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex())
					if currentSel == self.found[skillIndex].index then
						getglobal(self.currentFrame.elements.Highlight):SetPoint('TOPLEFT', skillButton, 'TOPLEFT', 0, 0)
						getglobal(self.currentFrame.elements.Highlight):Show()
						skillButton:LockHighlight()

						-- So "Create All" button works for trade
						if self.mode == TRADE and getglobal(self.frames.trade.elements.Main) then
							getglobal(self.frames.trade.elements.Main).numAvailable = self.found[skillIndex].available
						end
					else
						if not self:SelectionInList(skillOffset) then
							getglobal(self.currentFrame.elements.Highlight):Hide()
						end
						skillButton:UnlockHighlight()
					end
				else
					skillButton:Hide()
				end
			end
		else
			getglobal(self.currentFrame.elements.Scroll):Hide()
			for i = 1, (self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED) do
				skillButton = getglobal((self.mode == CRAFT and 'Craft' or 'TradeSkillSkill')..i)
				if i == 1 then
					skillButton:Disable()
					skillButton:SetWidth(323)
					skillButton:SetDisabledTextColor(1, 1, 1)
					skillButton:SetDisabledTexture('')
					skillButton:SetText'No results matched your search.'
					skillButton:UnlockHighlight()
					skillButton:Show()
				else
					skillButton:Hide()
				end
			end
		end

	else
		-- If no filtering, show the original updates
		if self.mode == CRAFT then
			self.frames.craft.orig_update()
		elseif self.mode == TRADE then
			for i = 1, TRADE_SKILLS_DISPLAYED do
				getglobal('TradeSkillSkill'..i..'Text'):SetPoint('TOPLEFT', 'TradeSkillSkill'..i, 'TOPLEFT', 21, 0)
			end
			self.frames.trade.orig_update()
		end
	end
end

-----------------------------------------------------------------------
-- Search logic
-----------------------------------------------------------------------
function craftyplus:Search()
	self:State().searchText = self.frame.SearchBox:GetText() or ''

	-- Reset the official scrollbar to top
	FauxScrollFrame_SetOffset(getglobal(self.currentFrame.elements.Main), 0)
	getglobal(self.currentFrame.elements.ScrollBar):SetValue(0)

	self:BuildList()
	if getn(self.found) > 0 and self:State().searchText ~= '' then
		self:SelectFirst()
	end
	self:UpdateListing()
end

function craftyplus:SelectFirst()
	if self.mode == CRAFT and GetCraftSelectionIndex() > 0 then
		CraftFrame_SetSelection(self.found[1].index)
	elseif self.mode == TRADE then
		TradeSkillFrame_SetSelection(self.found[1].index)
	end
end

function craftyplus:SelectionInList(skillOffset)
	for i = skillOffset + 1, skillOffset + (self.mode == CRAFT and CRAFTS_DISPLAYED or TRADE_SKILLS_DISPLAYED) do
		if self.found[i] and self.found[i].index ==
		   (self.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex()) then
			return true
		end
	end
	return false
end

-----------------------------------------------------------------------
-- BuildList: collects all recipes, sorts, and prepares for display
-----------------------------------------------------------------------
function craftyplus:BuildList()
	self.found = {}
	local skills = {}
	local matcher = self:FuzzyMatcher(self:State().searchText)

	-- Gather everything from either Craft or TradeSkill
	for i = 1, (self.mode == CRAFT and GetNumCrafts() or GetNumTradeSkills()) do
		local skillName, skillType, numAvailable, isExpanded, requires
		if self.mode == CRAFT then
			skillName, _, skillType, numAvailable, isExpanded = GetCraftInfo(i)
			requires = GetCraftSpellFocus(i)
		else
			skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)
			requires = GetTradeSkillTools(i)
		end

		local nameRating = skillName and matcher(skillName)

		-- Reagents
		local reagents = {}
		local reagentsRating
		for j = 1, (self.mode == CRAFT and GetCraftNumReagents(i) or GetTradeSkillNumReagents(i)) do
			local reagentName
			if self.mode == CRAFT then
				reagentName = GetCraftReagentInfo(i, j)
			else
				reagentName = GetTradeSkillReagentInfo(i, j)
			end

			table.insert(reagents, reagentName)

			local reagentRating = reagentName and matcher(reagentName)
			if reagentRating then
				reagentsRating = reagentsRating and math.max(reagentsRating, reagentRating) or reagentRating
			end
		end

		-- Tools/focus rating
		local requiresRating = requires and matcher(requires)

		-- Overall rating
		local rating = nameRating and (nameRating * 2)
		if reagentsRating then
			rating = rating and math.max(rating, reagentsRating) or reagentsRating
		end
		if requiresRating then
			rating = rating and math.max(rating, requiresRating) or requiresRating
		end

		-- Actual skill (exclude headers)
		if skillName and skillType ~= 'header' then
			skills[skillName] = {
				name        = skillName,
				type        = skillType,
				available   = numAvailable,
				index       = i,
				rating      = rating,
				reagents    = reagents,
				reagentRank = 0,
			}
		elseif skillType == 'header' and not isExpanded then
			-- Expand unexpanded headers
			ExpandTradeSkillSubClass(i)
		end
	end

	-- Decide which items are "found" based on search/favorites
	local found
	if self:State().searchText == '' and not self:State().materials then
		found = self:State().favorites
	else
		found = {}

		for _, skill in pairs(skills) do
			if skill.rating then
				found[skill.name] = true
			end
		end

		-- Propagate matches to any reagent items
		while true do
			local changed
			for _, skill in pairs(skills) do
				if found[skill.name] then
					for _, reagentName in ipairs(skill.reagents) do
						local reagent = skills[reagentName]
						if reagent then
							if not found[reagentName] then
								found[reagentName] = true
								changed = true
							end
							if (not reagent.rating) or (skill.rating > reagent.rating) then
								reagent.rating = skill.rating
								reagent.reagentRank = skill.reagentRank + 1
							end
						end
					end
				end
			end
			if not changed then
				break
			end
		end

		-- "Mats" filter -> remove items with 0 available
		if self:State().materials then
			for _, skill in pairs(skills) do
				if skill.available == 0 then
					found[skill.name] = nil
				end
			end
		end
	end

	-- Build self.found
	for skill, data in pairs(skills) do
		if found[skill] then
			table.insert(self.found, data)
		end
	end

	-- Sort final results
	table.sort(self.found, function(a, b)
		-- If no search text, keep original order by index
		if self:State().searchText == '' then
			return a.index < b.index
		else
			-- Compare rating
			if b.rating < a.rating then
				return true
			elseif a.rating == b.rating then
				-- Then compare reagentRank
				if a.reagentRank < b.reagentRank then
					return true
				elseif a.reagentRank == b.reagentRank then
					-- If top-level, shorter name first
					if a.reagentRank == 0 and strlen(a.name) < strlen(b.name) then
						return true
					elseif a.reagentRank > 0 or strlen(a.name) == strlen(b.name) then
						return a.index < b.index
					end
				end
			end
		end
	end)
end

-----------------------------------------------------------------------
-- SendReagentMessage:
-- Sends item + reagents in separate messages:
--   1) The item link alone
--   2) One or more lines for reagents (with "(cont.)" prefix if split)
-----------------------------------------------------------------------
function craftyplus:SendReagentMessage(channel, who)
    -- Get the correct index depending on the mode (CRAFT or TRADESKILL)
    local index = (self.mode == CRAFT and GetCraftSelectionIndex() or GetTradeSkillSelectionIndex())
    if index == 0 then
        return
    end

    -- Retrieve the item link based on the mode selected
    local itemLink = (self.mode == CRAFT and 
        GetCraftItemLink(index) or GetTradeSkillItemLink(index))
    if not itemLink then
        return
    end

    -- First message: send the item link with the " Required Reagents:" suffix.
    SendChatMessage(itemLink .. " Required Reagents:", channel,
        GetDefaultLanguage("player"), who)

    -- Build the reagent lines. Each reagent will be concatenated as "reagentLinkxneeded".
    local reagentsLine = ""
    local messages = {}
    local reagentCount = (self.mode == CRAFT and GetCraftNumReagents(index) or
        GetTradeSkillNumReagents(index))

    for i = 1, reagentCount do
        local reagentLink, _, needed
        if self.mode == CRAFT then
            reagentLink = GetCraftReagentItemLink(index, i)
            _, _, needed = GetCraftReagentInfo(index, i)
        else
            reagentLink = GetTradeSkillReagentItemLink(index, i)
            _, _, needed = GetTradeSkillReagentInfo(index, i)
        end

        if not reagentLink or not needed then
            return
        end

        local nextChunk = reagentLink .. "x" .. needed
        local testLine = (reagentsLine == "" and nextChunk) or 
            (reagentsLine .. " " .. nextChunk)

        -- Check if adding nextChunk exceeds the chat message limit.
        if strlen(testLine) > 255 then
            table.insert(messages, reagentsLine)
            reagentsLine = nextChunk
        else
            reagentsLine = testLine
        end
    end

    -- Flush any remaining reagents.
    if reagentsLine ~= "" then
        table.insert(messages, reagentsLine)
    end

    -- Send each reagent line as a separate chat message.
    for _, line in ipairs(messages) do
        SendChatMessage(line, channel, GetDefaultLanguage("player"), who)
    end
end

-----------------------------------------------------------------------
-- FuzzyMatcher: Returns a function rating how closely a string matches
-----------------------------------------------------------------------
function craftyplus:FuzzyMatcher(input)
	local uppercaseInput = strupper(input)
	local pattern = '(.*)'
	local captures = 0

	for i = 1, strlen(uppercaseInput) do
		local c = strsub(uppercaseInput, i, i)
		if strfind(c, '%w') or strfind(c, '%s') then
			pattern = pattern..c..(captures > 30 and '.-' or '(.-)')
			captures = captures + 1
		end
	end

	return function(candidate)
		local match = {strfind(strupper(candidate), pattern)}
		if match[1] then
			local rating = 0
			-- For each captured group that's empty, increase rating
			for i = 4, getn(match) - 1 do
				if strlen(match[i]) == 0 then
					rating = rating + 1
				end
			end
			return rating
		end
	end
end