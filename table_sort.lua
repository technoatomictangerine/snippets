local function _helper(t, a, b, fn)
    if b < a then return end
    local p = a
    for i = a + 1, b do
        if fn(t[i], t[p]) then
            if i == p + 1 then t[p], t[p + 1] = t[p + 1], t[p]
            else t[p], t[p + 1], t[i] = t[i], t[p], t[p + 1] end
            p = p + 1
        end
    end
    _helper(t, a, p - 1, fn)
    _helper(t, p + 1, b, fn)
end

function table.Sort(t, fn)
    _helper(t, 1, #t, fn)
end
