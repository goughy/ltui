---A cross-platform terminal ui library based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-2020, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        choicebox.lua
--

-- load modules
local log       = require("ltui/base/log")
local view      = require("ltui/view")
local rect      = require("ltui/rect")
local panel     = require("ltui/panel")
local event     = require("ltui/event")
local action    = require("ltui/action")
local curses    = require("ltui/curses")
local button    = require("ltui/button")
local object    = require("ltui/object")
local theme     = require("ltui/theme")

-- define module
local choicebox = choicebox or panel()

-- init choicebox
function choicebox:init(name, bounds)

    -- init panel
    panel.init(self, name, bounds)

    -- init items
    self._ITEMS = {}

    -- init start index
    self._STARTINDEX = 1

    self:option_set("selected_mark", theme.current.choicebox and theme.current.choicebox.selected_mark or "(X) ")
    self:option_set("deselected_mark", theme.current.choicebox and theme.current.choicebox.deselected_mark or "( ) ")
end

-- load values
function choicebox:load(values, selected)

    -- clear the views first
    self:clear()

    -- reset start index
    self._STARTINDEX = 1

    -- load items
    local items = {}
    for idx, value in ipairs(values) do
        table.insert(items, self:_load_item(value, idx, idx == selected))
    end
    self._ITEMS = items

    -- insert top-n items
    local startindex = self._STARTINDEX
    for idx = startindex, startindex + self:height() - 1 do
        local item = items[idx]
        if item then
            self:insert(item)
        else
            break
        end
    end

    -- select the first item
    self:select(self:first())
    self:_autoselect()

    -- on loaded
    self:action_on(action.ac_on_load)

    -- invalidate
    self:invalidate()
end

-- is scrollable?
function choicebox:scrollable()
    return #self:_items() > self:height()
end

-- scroll
function choicebox:scroll(count, force)
    if self:scrollable() or force then
        local items = self:_items()
        local totalcount = #items
        local startindex = self._STARTINDEX + count
        if startindex > totalcount then
            return
        elseif startindex < 1 then
            startindex = 1
            count = 1
        end
        self._STARTINDEX = startindex
        self:clear()
        for idx = startindex, startindex + self:height() - 1 do
            local item = items[idx]
            if item then
                item:bounds():move2(0, idx - startindex)
                self:insert(item)
            else
                break
            end
        end
        if count > 0 then
            self:select(self:first())
        else
            self:select(self:last())
        end
        self:_autoselect()
        self:invalidate()
    end
end

-- on resize
function choicebox:on_resize()
    local items = self:_items()
    local totalcount = #items
    local startindex = self._STARTINDEX
    for idx = 1, totalcount do
        local item = items[idx]
        if item then
            if idx >= startindex and idx < startindex + self:height() then
                if not self:view(item:name()) then
                    item:bounds():move2(0, idx - startindex)
                    self:insert(item)
                end
            else
                if self:view(item:name()) then
                    self:remove(item)
                end
            end
        end
    end
    panel.on_resize(self)
end

-- on event
function choicebox:on_event(e)
    if e.type == event.ev_keyboard then
        if e.key_name == "Down" then
            if self:current() == self:last() then
                self:scroll(self:height())
            else
                self:select_next()
            end
            self:_notify_scrolled()
            self:_autoselect()
            return true
        elseif e.key_name == "Up" then
            if self:current() == self:first() then
                self:scroll(-self:height())
            else
                self:select_prev()
            end
            self:_notify_scrolled()
            self:_autoselect()
            return true
        elseif e.key_name == "PageDown" or e.key_name == "PageUp" then
            local direction = e.key_name == "PageDown" and 1 or -1
            self:scroll(self:height() * direction)
            self:_notify_scrolled()
            self:_autoselect()
            return true
        elseif e.key_name == "Enter" or e.key_name == " " then
            self:_do_select()
            return true
        end
    elseif e.type == event.ev_command and e.command == "cm_enter" then
        self:_do_select()
        return true
    elseif e.type == event.ev_command and e.command == "cb_scroll" then
        self:scroll(e.extra)
        return true
    end
end

-- load a item with value
function choicebox:_load_item(value, index, selected)

    -- init text
    --log:printf("EVENT:CB:value is %s\n", tostring(value))
    local text = (selected and self:option("selected_mark") or self:option("deselected_mark")) .. tostring(value)
    if self:option("fullwidth") and string.len(text) < self:width() then
        text = text .. string.rep(" ", self:width() - string.len(text))
    end

    -- init a value item view
    local item = button:new("choicebox.value." .. index,
                    rect:new(0, index - 1, self:width(), 1),
                    text,
                    function (v, e)
                        self:_do_select()
                    end)

    item:textattr_set(theme.current.fg)

    -- attach index and value
    item:extra_set("index", index)
    item:extra_set("value", value)
    return item
end

-- notify scrolled
function choicebox:_notify_scrolled()
    local totalcount = #self:_items()
    local startindex = self:current() and self:current():extra("index") or 0
    self:action_on(action.ac_on_scrolled, startindex / totalcount)
end

function choicebox:_autoselect()
  if self:option("autoselect") then
    self:_do_select()
  end
end

-- get all items
function choicebox:_items()
    return self._ITEMS
end

-- do select the current config
function choicebox:_do_select()

    -- clear selected text
	if not self:option("multiselect") then
		for v in self:views() do
			local text = v:text()
			if text and text:startswith(self:option("selected_mark")) then
				local t = v:extra("value")
				v:text_set(self:option("deselected_mark") .. tostring(t))
			end
		end
	end

    -- get the current item
  local item = self:current()
  if not item then
      return
  end
  local is_selected = item:text() and item:text():startswith(self:option("selected_mark")) or false

  -- do action: on selected
  local index = item:extra("index")
  local value = item:extra("value")
  self:action_on(action.ac_on_selected, index, value)

  value = (is_selected and self:option("deselected_mark") or self:option("selected_mark")) .. tostring(value)
  if self:option("fullwidth") and string.len(value) < self:width() then
      value = value .. string.rep(" ", self:width() - string.len(value))
  end
  -- update text
  item:text_set(value)
end

-- return module
return choicebox
