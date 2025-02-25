
local theme = {}

theme.LTUI = {
    ["bg"] = "blue",
    ["fg"] = "white",
    choicebox = {
        ["selected_mark"] = "(X) ",
        ["deselected_mark"] = "( ) ",
    },
    scrollbar = {
        ["char"] = " ",
        ["charattr"] = "white onblue"
    }
}

theme.BASIC = {
    ["bg"] = "black",
    ["fg"] = "white",
    choicebox = {
        ["selected_mark"] = " > ",
        ["deselected_mark"] = "   ",
    },
    scrollbar = {
        ["char"] = "=",
        ["charattr"] = "white onblue"
    }
}

--theme.current = theme.LTUI
theme.current = theme.BASIC
return theme