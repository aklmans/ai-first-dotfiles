#!/usr/bin/env bash

is_jetbrains_app() {
    local app_id="${1:-}"
    local app_name="${2:-}"

    case "$app_id" in
        com.jetbrains.*|com.google.android.studio)
            return 0
            ;;
    esac

    case "$app_name" in
        "GoLand"|"IntelliJ IDEA"|"IntelliJ IDEA-EAP"|"WebStorm"|"PhpStorm"|"RustRover"|"PyCharm"|"CLion"|"DataGrip"|"Rider"|"Android Studio")
            return 0
            ;;
    esac

    return 1
}

is_jetbrains_dialog_title() {
    local title="${1:-}"

    case "$title" in
        "Welcome to"*|"Settings"|"Preferences"|"Project Structure"*|"Run/Debug Configurations"*|"Edit Configuration"*|"Plugins"|"Tip of the Day"*|"New Project"*|"Open File or Project"*|"Attach Directory"*|"About"*|"Licenses"*|"Choose"*|"Select"*|"Import"*|"Export"*|"Find"*|"Replace"*|"Search Everywhere"*|"Local History"*|"Commit"*|"Push"*|"Pull"*|"Merge"*|"Rebase"*|"Checkout"*|"Branch"*|"Clone Repository"*|"Delete"*|"Rename"*|"Remove"*|"Move"*|"Copy"*|"Add File to Git"*|"Edit Commit Message"*|"Confirm"*|"Discard"*|"Overwrite"*|"File Already Exists"*|"Resolve Conflicts"*)
            return 0
            ;;
    esac

    return 1
}

is_context_dialog_title() {
    local title="${1:-}"

    case "$title" in
        "Settings"*|\
        "Preferences"*|\
        "Options"*|\
        "Licenses"*|\
        "Choose"*|\
        "Select"*|\
        "Open"*|\
        "Save"*|\
        "Save As"*|\
        "Export"*|\
        "Import"*|\
        "Find"*|\
        "Replace"*|\
        "Print"*|\
        "Search"*|\
        "Keyboard Shortcuts"*|\
        "Extensions"*|\
        "Plugins"*|\
        "Account"*|\
        "Profile"*|\
        "Sign in"*|\
        "Login"*|\
        "设置"*|\
        "偏好设置"*|\
        "选项"*|\
        "关于"*|\
        "打开"*|\
        "保存"*|\
        "导出"*|\
        "导入"*|\
        "查找"*|\
        "替换"*|\
        "打印"*|\
        "账户"*|\
        "登录"*)
            return 0
            ;;
    esac

    return 1
}

should_float_window() {
    local app_id="${1:-}"
    local app_name="${2:-}"
    local title="${3:-}"

    if is_context_dialog_title "$title"; then
        return 0
    fi

    if is_jetbrains_app "$app_id" "$app_name" && is_jetbrains_dialog_title "$title"; then
        return 0
    fi

    case "$app_id" in
        com.apple.finder|com.apple.systempreferences|com.apple.ActivityMonitor|com.apple.mail|com.apple.Photos|com.apple.Preview|com.apple.Music|com.apple.podcasts|com.apple.archiveutility|com.apple.AppStore)
            return 0
            ;;
        com.tencent.xinWeChat|com.tencent.WeWorkMac|com.tencent.qq|com.alibaba.DingTalkMac|us.zoom.xos|com.hnc.Discord|com.facebook.archon)
            return 0
            ;;
        com.lbyczf.clashwin|com.logi.optionsplus|com.docker.docker|com.1password.1password|com.runningwithcrayons.Alfred-Preferences|org.pqrs.Karabiner-Elements.Settings|com.macpaw.CleanMyMac-setapp|com.tencent.Lemon|com.fiplab.appcleaner|com.culturedcode.ThingsMac|com.pieces.osx|com.rogueamoeba.Loopback|com.charliemonroe.Downie-4)
            return 0
            ;;
        com.microsoft.Powerpoint|com.apple.iWork.Keynote|com.spotify.client)
            return 0
            ;;
    esac

    case "$app_name" in
        "Finder"|"访达"|"System Settings"|"System Preferences"|"系统设置"|"Activity Monitor"|"监视器"|"Stats"|"Mail"|"邮件"|"Photos"|"照片"|"Preview"|"预览"|"Microsoft PowerPoint"|"Keynote"*)
            return 0
            ;;
        "微信"|"WeChat"|"企业微信"|"WeCom"|"QQ"|"钉钉"|"DingTalk"|"飞书"|"Feishu"|"Lark"|"Lark Meetings"|"zoom.us"|"Mattermost"|"Messenger"|"Discord"|"BaiduIM")
            return 0
            ;;
        "Dash"|"Navicat Premium"|"1Password"|"Alfred Preferences"|"Karabiner-Elements"|"Karabiner-EventViewer"|"Things"|"Pieces"|"Loopback"|"Downie 4"|"CleanMyMac X"|"Tencent Lemon"|"AppCleaner"|"Clash for Windows"|"Logi Options+"|"Logi Options Plus"|"Docker"|"Docker Desktop")
            return 0
            ;;
        "NeteaseMusic"|"Music"|"音乐"|"Spotify"|"哔哩哔哩"|"mpv"|"Podcasts"|"播客")
            return 0
            ;;
    esac

    return 1
}

should_tile_window() {
    local app_id="${1:-}"
    local app_name="${2:-}"
    local title="${3:-}"

    if should_float_window "$app_id" "$app_name" "$title"; then
        return 1
    fi

    if is_jetbrains_app "$app_id" "$app_name"; then
        return 0
    fi

    case "$app_id" in
        dev.warp.Warp-Stable|fun.tw93.kaku|com.microsoft.VSCode|com.microsoft.VSCodeInsiders|com.sublimetext.4|com.todesktop.230313mzl4w4u92)
            return 0
            ;;
        company.thebrowser.Browser|company.thebrowser.dia|com.apple.Safari|com.microsoft.edgemac|com.google.Chrome|org.mozilla.firefox|app.zen-browser.zen)
            return 0
            ;;
        md.obsidian|com.tw93.miaoyan|com.openai.chat|com.openai.atlas|com.anthropic.claudefordesktop|com.google.GeminiMacOS)
            return 0
            ;;
    esac

    case "$app_name" in
        "Warp"|"Kaku"|"Cursor"|"Visual Studio Code"|"Code"|"Code - Insiders"|"Sublime Text"|"GoLand"|"IntelliJ IDEA"|"IntelliJ IDEA-EAP"|"WebStorm"|"PhpStorm"|"RustRover"|"PyCharm"|"CLion"|"DataGrip"|"Rider"|"Android Studio")
            return 0
            ;;
        "Arc"|"Dia"|"Safari"|"Microsoft Edge"|"Google Chrome"|"Firefox"|"Zen")
            return 0
            ;;
        "Obsidian"|"MiaoYan"|"Claude"|"ChatGPT"|"ChatGPT Atlas"|"Gemini")
            return 0
            ;;
    esac

    return 1
}

default_workspace_for_window() {
    local app_id="${1:-}"
    local app_name="${2:-}"
    local title="${3:-}"

    if is_context_dialog_title "$title"; then
        return 1
    fi

    if is_jetbrains_app "$app_id" "$app_name" && is_jetbrains_dialog_title "$title"; then
        return 1
    fi

    if is_jetbrains_app "$app_id" "$app_name"; then
        printf '8'
        return 0
    fi

    case "$app_id" in
        company.thebrowser.dia)
            printf '1'
            return 0
            ;;
        com.microsoft.edgemac)
            printf '2'
            return 0
            ;;
        com.openai.codex)
            printf '3'
            return 0
            ;;
        com.openai.chat)
            printf '4'
            return 0
            ;;
        com.tencent.xinWeChat|com.tencent.WeWorkMac|com.tencent.qq|com.alibaba.DingTalkMac|com.electron.lark|us.zoom.xos|com.hnc.Discord|com.facebook.archon)
            printf '5'
            return 0
            ;;
        com.apple.finder|com.apple.systempreferences|com.apple.SystemSettings|com.apple.ActivityMonitor|com.apple.Preview|com.apple.Photos|com.apple.archiveutility|com.apple.AppStore|com.apple.mail)
            printf '6'
            return 0
            ;;
        dev.warp.Warp-Stable)
            printf '7'
            return 0
            ;;
        com.openai.atlas)
            printf '9'
            return 0
            ;;
        abnerworks.Typora|com.tw93.miaoyan)
            printf '10'
            return 0
            ;;
        com.google.Chrome|com.apple.Safari|org.mozilla.firefox|app.zen-browser.zen|com.microsoft.VSCode|com.microsoft.VSCodeInsiders|com.sublimetext.4|com.todesktop.230313mzl4w4u92|fun.tw93.kaku|com.techsmith.camtasia|com.TechSmith.Snagit)
            printf '11'
            return 0
            ;;
        com.lbyczf.clashwin|com.logi.optionsplus|com.docker.docker|com.rogueamoeba.Loopback)
            printf '12'
            return 0
            ;;
    esac

    case "$app_name" in
        "Dia"|"Dia Browser")
            printf '1'
            ;;
        "Microsoft Edge")
            printf '2'
            ;;
        "Codex"|"OpenAI Codex")
            printf '3'
            ;;
        "ChatGPT")
            printf '4'
            ;;
        "微信"|"WeChat"|"企业微信"|"WeCom"|"QQ"|"钉钉"|"DingTalk"|"飞书"|"Feishu"|"Lark"|"Lark Meetings"|"zoom.us"|"Mattermost"|"Messenger"|"Discord"|"BaiduIM")
            printf '5'
            ;;
        "Finder"|"访达"|"System Settings"|"System Preferences"|"系统设置"|"Activity Monitor"|"监视器"|"Stats"|"Mail"|"邮件"|"Photos"|"照片"|"Preview"|"预览"|"Archive Utility"|"归档实用工具"|"App Store")
            printf '6'
            ;;
        "Warp")
            printf '7'
            ;;
        "GoLand"|"IntelliJ IDEA"|"IntelliJ IDEA-EAP"|"WebStorm"|"PhpStorm"|"RustRover"|"PyCharm"|"CLion"|"DataGrip"|"Rider"|"Android Studio")
            printf '8'
            ;;
        "ChatGPT Atlas"|"Atlas")
            printf '9'
            ;;
        "Typora"|"MiaoYan"|"Miaoyan"|"妙言")
            printf '10'
            ;;
        "Google Chrome"|"Safari"|"Firefox"|"Zen"|"Cursor"|"Visual Studio Code"|"Code"|"Code - Insiders"|"Sublime Text"|"Kaku"|"Camtasia"|"Snagit")
            printf '11'
            ;;
        "Clash for Windows"|"Logi Options+"|"Logi Options Plus"|"Docker"|"Docker Desktop"|"Loopback")
            printf '12'
            ;;
        *)
            return 1
            ;;
    esac
}

emit_on_window_detected_rules() {
    cat <<'TOML'
# Application placement and floating rules.
# Keep this block aligned with ~/.config/aerospace/app-defaults.sh.

# Common secondary/dialog windows should stay with the workspace that opened them.
[[on-window-detected]]
    if.window-title-regex-substring = '^(Settings|Preferences|Options|Licenses|Choose|Select|Open|Save|Save As|Export|Import|Find|Replace|Print|Search|Keyboard Shortcuts|Extensions|Plugins|Account|Profile|Sign in|Login|设置|偏好设置|选项|关于|打开|保存|导出|导入|查找|替换|打印|账户|登录)( |$|:|-)'
    run = 'layout floating'

# JetBrains: keep main IDE windows tiled, but float obvious dialogs/tool windows.
[[on-window-detected]]
    if.app-name-regex-substring = '^(GoLand|IntelliJ IDEA|IntelliJ IDEA-EAP|WebStorm|PhpStorm|RustRover|PyCharm|CLion|DataGrip|Rider|Android Studio)$'
    if.window-title-regex-substring = '^(Welcome to|Settings|Preferences|Project Structure|Run/Debug Configurations|Edit Configuration|Plugins|Tip of the Day|New Project|Open File or Project|Attach Directory|About|Licenses|Choose|Select|Import|Export|Find|Replace|Search Everywhere|Local History|Commit|Push|Pull|Merge|Rebase|Checkout|Branch|Clone Repository|Delete|Rename|Remove|Move|Copy|Add File to Git|Edit Commit Message|Confirm|Discard|Overwrite|File Already Exists|Resolve Conflicts)'
    run = 'layout floating'

# Float apps that should behave like utility/dialog surfaces, then continue to placement rules.
[[on-window-detected]]
    if.app-name-regex-substring = '^(Finder|访达|System Settings|System Preferences|系统设置|Activity Monitor|监视器|Stats|Mail|邮件|Photos|照片|Preview|预览|Microsoft PowerPoint|Keynote.*)$'
    check-further-callbacks = true
    run = 'layout floating'

[[on-window-detected]]
    if.app-name-regex-substring = '^(微信|WeChat|企业微信|WeCom|QQ|钉钉|DingTalk|飞书|Feishu|Lark|Lark Meetings|zoom\.us|Mattermost|Messenger|Discord|BaiduIM)$'
    check-further-callbacks = true
    run = 'layout floating'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Dash|Navicat Premium|1Password|Alfred Preferences|Karabiner-Elements|Karabiner-EventViewer|Things|Pieces|Loopback|Downie 4|CleanMyMac X|Tencent Lemon|AppCleaner|Clash for Windows|Logi Options\+|Logi Options Plus|Docker|Docker Desktop)$'
    check-further-callbacks = true
    run = 'layout floating'

[[on-window-detected]]
    if.app-name-regex-substring = '^(NeteaseMusic|Music|音乐|Spotify|哔哩哔哩|mpv|Podcasts|播客)$'
    check-further-callbacks = true
    run = 'layout floating'

# Primary work/browser/AI windows should stay tiled, even if the app restored a floating state.
[[on-window-detected]]
    if.app-name-regex-substring = '^(Warp|Kaku|Cursor|Visual Studio Code|Code|Code - Insiders|Sublime Text|GoLand|IntelliJ IDEA|IntelliJ IDEA-EAP|WebStorm|PhpStorm|RustRover|PyCharm|CLion|DataGrip|Rider|Android Studio|Arc|Dia|Safari|Microsoft Edge|Google Chrome|Firefox|Zen|Obsidian|MiaoYan|Claude|ChatGPT|ChatGPT Atlas|Gemini)$'
    check-further-callbacks = true
    run = 'layout tiling'

# Exact app-id placement for stable apps.
[[on-window-detected]]
    if.app-id = 'company.thebrowser.dia'
    run = 'move-node-to-workspace 1'

[[on-window-detected]]
    if.app-id = 'com.microsoft.edgemac'
    run = 'move-node-to-workspace 2'

[[on-window-detected]]
    if.app-id = 'com.openai.codex'
    run = 'move-node-to-workspace 3'

[[on-window-detected]]
    if.app-id = 'com.openai.chat'
    run = 'move-node-to-workspace 4'

[[on-window-detected]]
    if.app-id = 'dev.warp.Warp-Stable'
    run = 'move-node-to-workspace 7'

[[on-window-detected]]
    if.app-id = 'com.openai.atlas'
    run = 'move-node-to-workspace 9'

[[on-window-detected]]
    if.app-id = 'abnerworks.Typora'
    run = 'move-node-to-workspace 10'

[[on-window-detected]]
    if.app-id = 'com.tw93.miaoyan'
    run = 'move-node-to-workspace 10'

[[on-window-detected]]
    if.app-id = 'com.google.Chrome'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'com.apple.Safari'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'org.mozilla.firefox'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'com.microsoft.VSCode'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'com.microsoft.VSCodeInsiders'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'com.sublimetext.4'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'com.todesktop.230313mzl4w4u92'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'fun.tw93.kaku'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'com.techsmith.camtasia'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'com.TechSmith.Snagit'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-id = 'com.lbyczf.clashwin'
    run = 'move-node-to-workspace 12'

[[on-window-detected]]
    if.app-id = 'com.logi.optionsplus'
    run = 'move-node-to-workspace 12'

[[on-window-detected]]
    if.app-id = 'com.docker.docker'
    run = 'move-node-to-workspace 12'

[[on-window-detected]]
    if.app-id = 'com.rogueamoeba.Loopback'
    run = 'move-node-to-workspace 12'

[[on-window-detected]]
    if.app-id = 'com.apple.finder'
    run = 'move-node-to-workspace 6'

[[on-window-detected]]
    if.app-id = 'com.apple.systempreferences'
    run = 'move-node-to-workspace 6'

[[on-window-detected]]
    if.app-id = 'com.apple.SystemSettings'
    run = 'move-node-to-workspace 6'

# Fallback app-name placement for apps that may have unstable or unknown bundle ids.
[[on-window-detected]]
    if.app-name-regex-substring = '^(Dia|Dia Browser)$'
    run = 'move-node-to-workspace 1'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Microsoft Edge)$'
    run = 'move-node-to-workspace 2'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Codex|OpenAI Codex)$'
    run = 'move-node-to-workspace 3'

[[on-window-detected]]
    if.app-name-regex-substring = '^(ChatGPT)$'
    run = 'move-node-to-workspace 4'

[[on-window-detected]]
    if.app-name-regex-substring = '^(微信|WeChat|企业微信|WeCom|QQ|钉钉|DingTalk|飞书|Feishu|Lark|Lark Meetings|zoom\.us|Mattermost|Messenger|Discord|BaiduIM)$'
    run = 'move-node-to-workspace 5'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Finder|访达|System Settings|System Preferences|系统设置|Activity Monitor|监视器|Stats|Mail|邮件|Photos|照片|Preview|预览|Archive Utility|归档实用工具|App Store)$'
    run = 'move-node-to-workspace 6'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Warp)$'
    run = 'move-node-to-workspace 7'

[[on-window-detected]]
    if.app-name-regex-substring = '^(GoLand|IntelliJ IDEA|IntelliJ IDEA-EAP|WebStorm|PhpStorm|RustRover|PyCharm|CLion|DataGrip|Rider|Android Studio)$'
    run = 'move-node-to-workspace 8'

[[on-window-detected]]
    if.app-name-regex-substring = '^(ChatGPT Atlas|Atlas)$'
    run = 'move-node-to-workspace 9'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Typora|MiaoYan|Miaoyan|妙言)$'
    run = 'move-node-to-workspace 10'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Google Chrome|Safari|Firefox|Zen|Cursor|Visual Studio Code|Code|Code - Insiders|Sublime Text|Kaku|Camtasia|Snagit)$'
    run = 'move-node-to-workspace 11'

[[on-window-detected]]
    if.app-name-regex-substring = '^(Clash for Windows|Logi Options\+|Logi Options Plus|Docker|Docker Desktop|Loopback)$'
    run = 'move-node-to-workspace 12'
TOML
}

if [ "${1:-}" = "--toml" ]; then
    emit_on_window_detected_rules
fi
