local dataFilesystem = require('filesystem').GetData()

local function contains(obj, value)
    for i = 1, #obj do
        if obj[i] == value then
            return true
        end
    end

    return false
end

return {
    ["contains"] = contains
}
