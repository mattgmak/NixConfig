''
  hl.on("config.reloaded", function()
    if hl.plugin.csgo_vulkan_fix then
      hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "cs2", w = 2560, h = 1440 })
      hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "SDL Application", w = 2560, h = 1440 })
    end
  end)
''
