local defaultPath = arg[1] or "Locales/MultiBotAceLocale-enUS.lua"
local localePath = arg[2] or "Locales/MultiBotAceLocale-ruRU.lua"

local function readLocale(path)
  local file, openError = io.open(path, "r")
  if not file then
    error("cannot open " .. path .. ": " .. tostring(openError))
  end

  local values = {}
  local duplicates = {}

  for line in file:lines() do
    local key, value = string.match(line, '^%s*%["([^"]+)"%]%s*=%s*"(.*)",%s*$')
    if key then
      if values[key] ~= nil then
        duplicates[#duplicates + 1] = key
      end
      values[key] = value
    end
  end

  file:close()
  return values, duplicates
end

local function sortedKeys(values)
  local keys = {}
  for key in pairs(values) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function formatArguments(value)
  local arguments = {}
  for placeholder in string.gmatch(value, "%%[-+#0%d%.]*[cdeEfgGiouXxqs]") do
    arguments[#arguments + 1] = placeholder
  end
  return table.concat(arguments, ",")
end

local defaults, defaultDuplicates = readLocale(defaultPath)
local locale, localeDuplicates = readLocale(localePath)
local errors = {}

for _, key in ipairs(defaultDuplicates) do
  errors[#errors + 1] = defaultPath .. ": duplicate key " .. key
end

for _, key in ipairs(localeDuplicates) do
  errors[#errors + 1] = localePath .. ": duplicate key " .. key
end

for _, key in ipairs(sortedKeys(defaults)) do
  if locale[key] == nil then
    errors[#errors + 1] = localePath .. ": missing key " .. key
  elseif formatArguments(defaults[key]) ~= formatArguments(locale[key]) then
    errors[#errors + 1] = localePath
      .. ": format arguments differ for "
      .. key
      .. " (expected "
      .. formatArguments(defaults[key])
      .. ", got "
      .. formatArguments(locale[key])
      .. ")"
  end
end

for _, key in ipairs(sortedKeys(locale)) do
  if defaults[key] == nil then
    errors[#errors + 1] = localePath .. ": unexpected key " .. key
  end
end

if #errors > 0 then
  for _, message in ipairs(errors) do
    io.stderr:write(message .. "\n")
  end
  os.exit(1)
end

io.stdout:write(
  string.format(
    "Locale check passed: %s matches %s (%d keys).\n",
    localePath,
    defaultPath,
    #sortedKeys(defaults)
  )
)
