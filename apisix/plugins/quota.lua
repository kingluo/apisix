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
local limit_local_new = require("resty.limit.count").new
local core = require("apisix.core")
local apisix_plugin = require("apisix.plugin")


local plugin_name = "quota"


local lrucache = core.lrucache.new({
    type = 'plugin', serial_creating = true,
})


local schema = {
    type = "object",
    properties = {
        minute = {type = "integer", exclusiveMinimum = 0},
        group = {type = "string"},
        rejected_code = {
            type = "integer", minimum = 200, maximum = 599, default = 503
        },
    },
    required = {"minute", "group"},
}


local _M = {
    version = 0.1,
    priority = 1002,
    name = plugin_name,
    schema = schema,
}


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end


local function create_limit_obj(conf)
    core.log.info("create new quota plugin instance")
    return limit_local_new("plugin-" .. plugin_name, conf.minute, 60)
end


function _M.access(conf, ctx)
    local ver = apisix_plugin.conf_version(conf)

    core.log.info("conf: ", tostring(conf), ", ver: ", ver)

    local group = conf.group:match("%$?(.*)")

    local lim, err = lrucache(group, ver, create_limit_obj, conf)

    if not lim then
        core.log.error("failed to fetch limit.count object: ", err)
        return 500
    end

    local key = ctx.var[group]
    if key == nil then
        return 500, {error_msg = "group var not found"}
    end

    key = key .. ":" .. ver

    core.log.info("quota key: ", key)

    local delay, remaining = lim:incoming(key, true)
    if not delay then
        local err = remaining
        if err == "rejected" then
            return conf.rejected_code
        end

        core.log.error("failed to limit count: ", err)
        return 500, {error_msg = "failed to quota"}
    end

    core.response.set_header("X-RateLimit-Limit", conf.minute,
        "X-RateLimit-Remaining", remaining)
end


return _M
