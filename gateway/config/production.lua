return {
    master_process = 'on',
    lua_code_cache = 'on',
    configuration_loader = 'boot',
    configuration_cache = os.getenv('APICAST_CONFIGURATION_CACHE') or 5*60,
    timer_resolution = '100ms',
}
