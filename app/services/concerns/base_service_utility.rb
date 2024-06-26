# frozen_string_literal: true

module BaseServiceUtility
  extend ActiveSupport::Concern
  include Gitlab::Allowable

  ### Convenience service methods

  def notification_service
    NotificationService.new
  end

  def event_service
    EventCreateService.new
  end

  def todo_service
    TodoService.new
  end

  def system_hook_service
    SystemHooksService.new
  end

  # Logging

  def log_info(message)
    Gitlab::AppLogger.info message
  end

  def log_error(message)
    Gitlab::AppLogger.error message
  end

  # Add an error to the specified model for restricted visibility levels
  def deny_visibility_level(model, denied_visibility_level = nil)
    denied_visibility_level ||= model.visibility_level

    level_name = Gitlab::VisibilityLevel.level_name(denied_visibility_level).downcase

    model.errors.add(:visibility_level, "#{level_name} has been restricted by your GitLab administrator")
  end

  def visibility_level
    params[:visibility].is_a?(String) ? Gitlab::VisibilityLevel.level_value(params[:visibility]) : params[:visibility_level]
  end

  private

  # Return a Hash with an `error` status
  #
  # message     - Error message to include in the Hash
  # http_status - Optional HTTP status code override (default: nil)
  # pass_back   - Additional attributes to be included in the resulting Hash
  def error(message, http_status = nil, status: :error, pass_back: {})
    result = {
      message: message,
      status: status
    }.reverse_merge(pass_back)

    result[:http_status] = http_status if http_status
    result
  end

  # Return a Hash with a `success` status
  #
  # pass_back - Additional attributes to be included in the resulting Hash
  def success(pass_back = {})
    pass_back[:status] = :success
    pass_back
  end
end
