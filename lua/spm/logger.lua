---@enum LogLevel
local LOG_LEVELS = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

---@class LoggerConfig
---@field enabled boolean Whether to enable logging
---@field level LogLevel The minimum log level to show
---@field prefix string The prefix to add to all log messages
---@field show_notifications boolean Whether to show vim.notify messages

---@type LoggerConfig
local config = {
  enabled = true,
  level = LOG_LEVELS.INFO,
  prefix = '[SimplePM]',
  show_notifications = true, -- Show vim.notify messages
}

---@type string[]
local log_history = {}

---Maps log levels to vim.log.levels
local VIM_LOG_LEVELS = {
  [LOG_LEVELS.DEBUG] = vim.log.levels.DEBUG,
  [LOG_LEVELS.INFO] = vim.log.levels.INFO,
  [LOG_LEVELS.WARN] = vim.log.levels.WARN,
  [LOG_LEVELS.ERROR] = vim.log.levels.ERROR,
}

---@class Logger
---@field private config LoggerConfig
local Logger = {}
Logger.__index = Logger

---Formats a log message with prefix and context
---@param level LogLevel The log level
---@param message string The message to log
---@param context string? Optional context information
---@return string formatted_message The formatted message
local function format_message(level, message, context)
  local level_names = {
    [LOG_LEVELS.DEBUG] = 'DEBUG',
    [LOG_LEVELS.INFO] = 'INFO',
    [LOG_LEVELS.WARN] = 'WARN',
    [LOG_LEVELS.ERROR] = 'ERROR',
  }

  local parts = { config.prefix }

  if context then table.insert(parts, string.format('[%s]', context)) end

  table.insert(parts, string.format('[%s]', level_names[level]))
  table.insert(parts, message)

  return table.concat(parts, ' ')
end

---Logs a message at the specified level
---@param level LogLevel The log level
---@param message string The message to log
---@param context string? Optional context information
local function log(level, message, context)
  if not config.enabled or level < config.level then return end

  local formatted = format_message(level, message, context)
  table.insert(log_history, formatted)

  if not config.show_notifications then return end

  local vim_level = VIM_LOG_LEVELS[level]
  vim.notify(formatted, vim_level)
end

---Configures the logger
---@param user_config table? Logger configuration
function Logger.configure(user_config)
  if user_config then config = vim.tbl_deep_extend('force', config, user_config) end
end

---Enables debug logging
function Logger.enable_debug()
  config.level = LOG_LEVELS.DEBUG
  config.enabled = true
end

---Disables all logging
function Logger.disable() config.enabled = false end

---Logs a debug message
---@param message string The message to log
---@param context string? Optional context information
function Logger.debug(message, context) log(LOG_LEVELS.DEBUG, message, context) end

---Logs an info message
---@param message string The message to log
---@param context string? Optional context information
function Logger.info(message, context) log(LOG_LEVELS.INFO, message, context) end

---Logs a warning message
---@param message string The message to log
---@param context string? Optional context information
function Logger.warn(message, context) log(LOG_LEVELS.WARN, message, context) end

---Logs an error message
---@param message string The message to log
---@param context string? Optional context information
function Logger.error(message, context) log(LOG_LEVELS.ERROR, message, context) end

---Gets the log history
---@return string[]
function Logger.get_history() return log_history end

---Clears the log history
function Logger.clear_history() log_history = {} end

---Creates a contextual logger that automatically includes context
---@param context string The context for all log messages
---@return table contextual_logger Logger with automatic context
function Logger.create_context(context)
  return {
    debug = function(message) Logger.debug(message, context) end,
    info = function(message) Logger.info(message, context) end,
    warn = function(message) Logger.warn(message, context) end,
    error = function(message) Logger.error(message, context) end,
  }
end

---Exposes log levels for external use
Logger.levels = LOG_LEVELS

return Logger
