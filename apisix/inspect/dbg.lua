--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local _M = {}

local hooks = {}

function _M.getname(n)
    if n.what == "C" then
        return n.name
    end
    local lc = string.format("%s:%d", n.short_src, n.currentline)
    if n.what ~= "main" and n.namewhat ~= "" then
        return string.format("%s (%s)", lc, n.name)
    else
        return lc
    end
end

local function hook(evt, arg)
    local level = 2
    local finfo = debug.getinfo(level, "nSlf")
    local key = finfo.source .. "#" .. arg

    local hooks2 = {}
    for _, hook in ipairs(hooks) do
        if key:sub(-#hook.key) == hook.key then
            local filter_func = hook.filter_func
            local info = {finfo = finfo, uv = {}, vals = {}}

            -- upvalues
            local i = 1
            while true do
                local name, value = debug.getupvalue(finfo.func, i)
                if name == nil then break end
                if string.sub(name, 1, 1) ~= "(" then
                    info.uv[name] = value
                end
                i = i + 1
            end

            -- local values
            local i = 1
            while true do
                local name, value = debug.getlocal(level, i)
                if not name then break end
                if string.sub(name, 1, 1) ~= "(" then
                    info.vals[name] = value
                end
                i = i + 1
            end

            local r1, r2_or_err = pcall(filter_func, info)
            if not r1 then
                ngx.log(ngx.ERR, r2_or_err)
            end

            -- if filter_func returns false, keep the hook
            if r1 and r2_or_err == false then
                table.insert(hooks2, hook)
            end
        else
            -- key not match, keep the hook
            table.insert(hooks2, hook)
        end
    end

    -- disable debug mode if all hooks done
    if #hooks2 ~= #hooks then
        hooks = hooks2
        if #hooks == 0 then
            debug.sethook()
        end
    end
end

function _M.set_hook(file, line, func, filter_func)
    if file == nil then
        file = "=stdin"
    end

    local key = file .. "#" .. line
    table.insert(hooks, {key = key, filter_func = filter_func})

    if jit then
        jit.flush(func)
    end

    debug.sethook(hook, "l")
end

function _M.unset_hook(file, line)
    if file == nil then
        file = "=stdin"
    end

    local hooks2 = {}

    local key = file .. "#" .. line
    for i, hook in ipairs(hooks) do
        if hook.key ~= key then
            table.insert(hooks2, hook)
        end
    end

    if #hooks2 ~= #hooks then
        hooks = hooks2
        if #hooks == 0 then
            debug.sethook()
        end
    end
end

function _M.unset_all()
    if #hooks > 0 then
        hooks = {}
        debug.sethook()
    end
end

function _M.hooks()
    return hooks
end

return _M
