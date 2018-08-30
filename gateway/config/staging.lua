return {
    master_process = 'on',
    lua_code_cache = 'on',
    configuration_loader = 'lazy',
    configuration_cache = os.getenv('APICAST_CONFIGURATION_CACHE'),
    port = { metrics = 9421 }, -- see https://github.com/prometheus/prometheus/wiki/Default-port-allocations,
}
