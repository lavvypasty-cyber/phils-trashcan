fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'phil'
description 'bin'

escrow_ignore {
    'config.lua'
}

shared_scripts {
    'config.lua',
	'@ox_lib/init.lua'
}

client_scripts {
    'client/*.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
}
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

lua54 'yes'