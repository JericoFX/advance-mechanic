fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Advanced Mechanic System'
description 'Complete mechanic job with realistic damage, inspection, and management'
version '1.0.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua'
}

client_scripts {
    'client/modules/*.lua',
    'client/modules/tuning.lua',
    'client/modules/billing.lua',
    'client/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/modules/*.lua',
    'server/init.lua'
}

files {
    'locales/*.json'
}

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'ox_target'
}
