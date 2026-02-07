fx_version 'cerulean'
game 'gta5'

author 'Vehicle Data Scanner'
description 'Comprehensive vehicle metadata extraction and export system for ESX'
version '1.0.0'

dependencies {
    'es_extended'
}

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

client_scripts {
    'client/scanner.lua'
}

server_scripts {
    'server/main.lua'
}
