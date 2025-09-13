fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Azure(TheStoicBear)'
description 'Az-DMV'
version '1.0'

client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
} 

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
} 

-- ensure these resources are present before starting this resource
dependencies {
    'ox_lib',
    'oxmysql',
    'Az-Framework'
}


